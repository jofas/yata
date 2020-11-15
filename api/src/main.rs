use actix_web::{get, post, put, delete, web, App, HttpResponse,
  HttpServer, Responder};
use actix_web::Error as ActixError;
use actix_web::dev::ServiceRequest;
use actix_web::dev::Service;

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
use futures::future::FutureExt;

use chrono::DateTime;
use chrono::offset::Utc;

#[macro_use]
extern crate partial_application;

use std::sync::Arc;

#[derive(Serialize, Deserialize, Debug)]
enum ElementStatus { Todo, Done, Deleted }

// TODO: timestamp for ordering
#[derive(Serialize, Deserialize, Debug)]
struct Element {
  id: String,
  content: String,
  status: ElementStatus,
  created: DateTime<Utc>,
}

#[derive(Serialize)]
struct SingleId {
  id: String
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
    let document = result.unwrap();
    let id = document.get_object_id("_id").unwrap().to_hex();
    let content = String::from(document.get_str("content").unwrap());
    let status: ElementStatus =
      from_bson(document.get("status").unwrap().clone()).unwrap();
    let created = document.get_datetime("created")
      .map(|d| *d)
      .or_else(|_| Ok(Utc::now()) as Result<DateTime<Utc>, bool>)
      .unwrap();

    res.push(Element{
      id: id, content: content, status: status, created: created
    });
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
    .inserted_id
    .as_object_id()
    .unwrap()
    .to_hex();

  HttpResponse::Ok().json(SingleId{id: id})
}

#[put("/{user}/{id}/status")]
async fn set_status(
  web::Path((user, id)): web::Path<(String, usize)>,
  new_status: web::Json<SingleStatus>) -> impl Responder
{
  HttpResponse::Ok().finish()
}

#[delete("/{user}/{id}")]
async fn delete_element(
  web::Path((user, id)): web::Path<(String, usize)>) -> impl Responder
{
  HttpResponse::Ok().finish()
}

#[post("/{user}/empty_bin")]
async fn empty_bin(
  web::Path((user,)): web::Path<(String,)>) -> impl Responder
{
  println!("deleting all completely");
  HttpResponse::Ok().finish()
}

async fn auth(
  req: ServiceRequest,
  bearer: BearerAuth,
  key_set:Arc<KeyStore>) -> Result<ServiceRequest, ActixError>
{
  println!("hello from auth");
  match key_set.verify(bearer.token()) {
    Ok(jwt) => {
      // TODO: make sure user can access path

      //println!("{:?}", jwt.payload());
      println!("{} {}", jwt.payload().get_str("preferred_username").unwrap(),
        req.path());
      Ok(req)
    }
    Err(JWTError { msg, typ: _ }) => {
      println!("Could not verify token. Reason: {}", msg);

      let config = req.app_data::<BearerConfig>()
        .map(|data| data.clone())
        .unwrap_or_else(Default::default);

      Err(AuthenticationError::from(config).into())
    }
  }
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

  /*
  // save the todos as {"value": "...", "state": "{todo|done|deleted}"}
  // and have a collection for each user

  let collection = db.collection("yata_collection");

  let elems = doc! {
    "user": "test",
    "todos": [{"value": "todo1", "index": 0}, {"value": "todo2", "index": 1}],
    "done": [],
    "deleted": [],
  };

  let find = doc!{"user": "test"};

  let rem_from_todo = doc!{"$pull": {"todos": {"index": 0}}};
  // find_one_and_delete, find_one_and_update

  if let None = collection.find_one_and_replace(find.clone(), elems.clone(), None).await.unwrap() {
    println!("Adding Elems for first time");
    collection.insert_one(elems.clone(), None).await.unwrap();
  } else {
    println!("Modified existing Elems");
  }

  let res = collection.find_one_and_update(find.clone(), rem_from_todo, None).await.unwrap();
  println!("{:?}", res);
  //let res = collection.find_one_and_update(find, rem_from_todo, None).await.unwrap();
  //println!("{:?}", res);
  //collection.find_one_and_update(find, , None).await.unwrap();

  panic!();
  */

  let url = "http://localhost:8080/auth/realms/yata/protocol/openid-connect/certs";
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
