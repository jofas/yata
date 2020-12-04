#![feature(try_trait)]

use actix_web::{get, post, put, delete, web, App, HttpResponse,
  HttpServer, Responder};
use actix_web::Error as ActixError;
use actix_web::dev::ServiceRequest;

use actix_web_httpauth::middleware::HttpAuthentication;
use actix_web_httpauth::extractors::AuthenticationError;
use actix_web_httpauth::extractors::bearer::BearerAuth;
use actix_web_httpauth::extractors::bearer::Config as BearerConfig;

use actix_cors::Cors;

use jwks_client::keyset::KeyStore;
use jwks_client::error::Error as JWTError;

use mongodb::{Client, Collection};
use mongodb::options::ClientOptions;
use mongodb::error::Result as MDBResult;
use mongodb::bson::{doc, to_bson};
use mongodb::bson::oid::ObjectId;

use futures::stream::StreamExt;

#[macro_use]
extern crate partial_application;

use std::sync::Arc;
use std::env;
use std::convert::TryFrom;

use yata_api::*;
use yata_api::inputs::{SingleContent, SingleStatus};
use yata_api::elements::{Element, ElementStatus};
// TODO: impl Responder -> Result with proper error
// TODO: created -> last modified?
// TODO: timestamp in id -> no extra field created necessary

#[get("/{user}")]
async fn get_elements(
  web::Path((user,)): web::Path<(String,)>,
  collection: web::Data<Collection>) -> impl Responder
{
  let filter = doc!{"user": user};
  let mut cursor = collection.find(filter, None).await.unwrap();

  let mut res: Vec<Element> = Vec::new();

  while let Some(result) = cursor.next().await {
    res.push(Element::try_from(result.unwrap()).unwrap());
  }

  HttpResponse::Ok().json(res)
}

#[post("/{user}/add_todo")]
async fn add_todo(
  web::Path((user,)): web::Path<(String,)>,
  collection: web::Data<Collection>,
  todo: web::Json<SingleContent>) -> impl Responder
{
  let insert = to_mongodb_entry(todo.into_inner(), user).unwrap();

  let id = collection.insert_one(insert, None)
    .await
    .unwrap()
    .inserted_id;

  let filter = doc!{"_id": id};

  let inserted_elem = collection.find_one(filter, None)
    .await
    .unwrap()
    .unwrap();

  HttpResponse::Ok().json(Element::try_from(inserted_elem).unwrap())
}

#[put("/{user}/{id}/status")]
async fn set_status(
  web::Path((user, id)): web::Path<(String, String)>,
  collection: web::Data<Collection>,
  new_status: web::Json<SingleStatus>) -> impl Responder
{
  let id = ObjectId::with_string(&id).unwrap();

  let filter = doc!{
    "_id": id,
    "user": user,
  };

  let update = doc!{
    "$set": {"status": to_bson(&new_status.status).unwrap()}
  };

  collection.update_one(filter, update, None).await.unwrap();

  HttpResponse::Ok().finish()
}

#[delete("/{user}/{id}")]
async fn delete_element(
  web::Path((user, id)): web::Path<(String, String)>,
  collection: web::Data<Collection>) -> impl Responder
{
  let id = ObjectId::with_string(&id).unwrap();

  let filter = doc!{
    "_id": id,
    "user": user,
  };

  collection.delete_one(filter, None).await.unwrap();

  HttpResponse::Ok().finish()
}

#[post("/{user}/empty_bin")]
async fn empty_bin(
  web::Path((user,)): web::Path<(String,)>,
  collection: web::Data<Collection>) -> impl Responder
{
  let filter = doc!{
    "user": user,
    "status": to_bson(&ElementStatus::Deleted).unwrap(),
  };

  collection.delete_many(filter, None).await.unwrap();

  HttpResponse::Ok().finish()
}

async fn auth(
  req: ServiceRequest,
  bearer: BearerAuth,
  key_set:Arc<KeyStore>) -> Result<ServiceRequest, ActixError>
{
  match key_set.verify(bearer.token()) {
    Ok(jwt) => {
      let username = jwt.payload().get_str("preferred_username").unwrap();
      let path_root = req.path().split("/").nth(1).unwrap();

      if username == path_root {
        return Ok(req);
      }
    },
    Err(JWTError { msg, typ: _ }) => {
      eprintln!("Could not verify token. Reason: {}", msg);
    }
  }

  let config = req.app_data::<BearerConfig>()
    .map(|data| data.clone())
    .unwrap_or_else(Default::default);

  Err(AuthenticationError::from(config).into())
}

async fn init_database(database_server: String)
  -> MDBResult<Collection>
{
  let client_options = ClientOptions::parse(
    &format!("mongodb://{}:27017", database_server)
  ).await?;
  let client = Client::with_options(client_options)?;
  let database = client.database("yata_db");
  Ok(database.collection("yata_collection"))
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
  println!("STARTING YATA_API SERVER");

  let addr = format!(
    "0.0.0.0:{}", env::var("YATA_API_PORT").unwrap()
  );

  let database_server = env::var("YATA_API_MONGODB_SERVER").unwrap();
  let collection = init_database(database_server).await.unwrap();

  let url = format!(
    "http://{}:{}/certs",
    env::var("YATA_API_KEYCLOAK_PROXY_SERVER").unwrap(),
    env::var("YATA_API_KEYCLOAK_PROXY_PORT").unwrap(),
  );
  println!("getting keystore from: {}", url);
  let key_set = Arc::new(KeyStore::new_from(&url).await.unwrap());
  let auth_fn = partial!(move auth => _, _, key_set.clone());

  HttpServer::new(move || {
    App::new()
      .data(collection.clone())
      .wrap(HttpAuthentication::bearer(auth_fn.clone()))
      .wrap(Cors::permissive()) // TODO: only yata_frontend
      /*
      .wrap_fn(|req, srv| {
        println!("OMG req!");
        srv.call(req).map(|res| {
          println!("{:?}", res);
          res
        })
      })
      */
      .service(get_elements)
      .service(add_todo)
      .service(set_status)
      .service(delete_element)
      .service(empty_bin)
  })
  .bind(&addr)?
  .run()
  .await
}

#[cfg(test)]
mod tests {
  use super::*;

  use chrono::offset::Utc;

  use yata_api::errors::ParseDocumentError;

  #[test]
  fn test_to_mongodb_entry() -> Result<(), ParseDocumentError> {
    let c = SingleContent{content: String::from("some content")};
    let user = String::from("some user");

    to_mongodb_entry(c, user)?;
    Ok(())
  }

  #[test]
  fn test_element_from_mongodb_document()
    -> Result<(), ParseDocumentError>
  {
    let doc = doc! {
      "_id": ObjectId::new(),
      "content": String::from("some content"),
      "status": to_bson(&ElementStatus::Todo).unwrap(),
      "created": Utc::now()
    };

    Element::try_from(doc)?;
    Ok(())
  }
}
