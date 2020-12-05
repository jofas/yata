/*
use actix_web::App as ActixApp;
use actix_web::dev::{ServiceRequest, ServiceResponse, MessageBody};
use actix_web::Error as ActixError;
use actix_web::body::Body;

use actix_web_httpauth::middleware::HttpAuthentication;
use actix_web_httpauth::extractors::bearer::BearerAuth;

use actix_service::ServiceFactory;

use actix_cors::Cors;

use jwks_client::keyset::KeyStore;

use mongodb::{Client, Collection};
use mongodb::options::ClientOptions;
use mongodb::error::Result as MDBResult;

#[macro_use]
extern crate partial_application;

use std::sync::Arc;
use std::env;

use crate::middlewares::auth;
use crate::routes::*;

use futures::future::Future;

pub struct App {}

// TODO: try using partial_application here inside build
impl App {
  pub async fn build(
    collection: Collection,
    auth_fn: Box<Fn(ServiceRequest, BearerAuth)
      -> Future<Output=Result<ServiceRequest, ActixError>>>) ->
    Box<ActixApp<impl ServiceFactory, Body>>
  {
    Box::new(ActixApp::new()
      .data(collection)
      .wrap(HttpAuthentication::bearer(auth_fn))
      .wrap(Cors::permissive()) // TODO: only yata_frontend
      .service(get_elements)
      .service(add_todo)
      .service(set_status)
      .service(delete_element)
      .service(empty_bin))
  }
}

async fn init_database(database_server_name: String)
  -> MDBResult<Collection>
{
  let client_options = ClientOptions::parse(
    &format!("mongodb://{}:27017", database_server_name)
  ).await?;
  let client = Client::with_options(client_options)?;
  let database = client.database("yata_db");
  Ok(database.collection("yata_collection"))
}
*/
