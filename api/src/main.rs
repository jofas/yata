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

use serde_derive::{Serialize, Deserialize};

use mongodb::{Client, Collection};
use mongodb::options::ClientOptions;
use mongodb::error::Result as MDBResult;
use mongodb::bson::{doc, Document};
use mongodb::bson::{to_bson, from_bson};
use mongodb::bson::oid::ObjectId;

use futures::stream::StreamExt;

use chrono::DateTime;
use chrono::offset::Utc;

#[macro_use]
extern crate partial_application;

use std::sync::Arc;
use std::convert::TryFrom;

#[derive(Serialize, Deserialize, Debug)]
enum ElementStatus { Todo, Done, Deleted }

// TODO: created -> last modified?
#[derive(Serialize, Deserialize, Debug)]
struct Element {
  id: String,
  content: String,
  status: ElementStatus,
  created: DateTime<Utc>,
}

impl TryFrom<Document> for Element {
  // TODO: error enum type
  type Error = &'static str;

  fn try_from(doc: Document) -> Result<Self, Self::Error> {
    // TODO: timestamp in id -> no extra field created necessary
    let id = doc.get_object_id("_id").unwrap().to_hex();
    let content = String::from(doc.get_str("content").unwrap());
    let status: ElementStatus =
      from_bson(doc.get("status").unwrap().clone()).unwrap();
    let created = *doc.get_datetime("created").unwrap();

    Ok(Element{
      id: id, content: content, status: status, created: created
    })
  }
}

#[derive(Deserialize)]
struct SingleContent {
  content: String,
}

#[derive(Deserialize)]
struct SingleStatus {
  status: ElementStatus,
}

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
  let insert = doc! {
    "user": user,
    "content": todo.content.clone(),
    "status": to_bson(&ElementStatus::Todo).unwrap(),
    "created": Utc::now(),
  };

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

async fn init_database() -> MDBResult<Collection> {
  let client_options = ClientOptions::parse("mongodb://localhost:27017").await?;
  let client = Client::with_options(client_options)?;
  let database = client.database("yata_db");
  Ok(database.collection("yata_collection"))
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
  println!("STARTING YATA_API SERVER");

  let collection = init_database().await.unwrap();

  let url = "http://localhost:9998/certs";
  let key_set = Arc::new(KeyStore::new_from(url).await.unwrap());
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
  .bind("0.0.0.0:9999")?
  .run()
  .await
}
