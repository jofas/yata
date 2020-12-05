#![feature(try_trait)]

use actix_web::{App, HttpServer};

use actix_web_httpauth::middleware::HttpAuthentication;

use actix_cors::Cors;

use jwks_client::keyset::KeyStore;

use mongodb::{Client, Collection};
use mongodb::options::ClientOptions;
use mongodb::error::Result as MDBResult;

#[macro_use]
extern crate partial_application;

use std::sync::Arc;
use std::env;

use yata_api::middlewares::auth;
use yata_api::routes::*;

//use yata_api::apps::App;

// TODO: impl Responder -> Result with proper error
// TODO: created -> last modified?
// TODO: timestamp in id -> no extra field created necessary

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
  HttpServer::new(move || {
    let key_set2 = key_set.clone();
    let auth_fn = partial!(move auth => _, _, key_set2.clone());

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
