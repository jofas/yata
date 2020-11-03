use actix_web::{Result as ActixResult, get, post, web, App,
  HttpRequest, HttpResponse, HttpServer, Responder};
use actix_cors::Cors;
use serde_derive::Serialize;

#[macro_use]
extern crate lazy_static;

use std::sync::Mutex;

#[derive(Serialize, Clone)]
struct YataData {
  todos: Vec<String>,
  done: Vec<String>,
  deleted: Vec<String>
}

impl YataData {
  fn new() -> YataData {
    YataData{todos: Vec::new(), done: Vec::new(), deleted: Vec::new()}
  }
}

// data as global variable
lazy_static! {
  static ref DATA: Mutex<YataData> = Mutex::new(YataData::new());
}

#[get("/")]
async fn all(_req: HttpRequest) -> ActixResult<web::Json<YataData>> {
  Ok(web::Json((*DATA.lock().unwrap()).clone()))
}

#[get("/todos")]
async fn todos() -> impl Responder {
  HttpResponse::Ok().body("Hello!")
}

#[get("/done")]
async fn done() -> impl Responder {
  HttpResponse::Ok().body("Hello!")
}

#[get("/deleted")]
async fn deleted() -> impl Responder {
  HttpResponse::Ok().body("Hello!")
}

// TODO:
//
// GET / gets the whole deal
// POST /todos {value} add new item
// POST /todo_set_done {id}
// POST /todo_set_deleted {id}
// POST /done_set_todo {id}
// POST /done_set_deleted {id}
// POST /deleted_set_todo {id}
// POST /delete_completely {id}
//
//
// connect the API to a database
//
// websocket API for live changes instead of HTTP API

#[actix_web::main]
async fn main() -> std::io::Result<()> {
  HttpServer::new(|| {
    App::new()
      .wrap(Cors::permissive())
      .service(all)
      .service(todos)
      .service(done)
      .service(deleted)
  })
  .bind("127.0.0.1:9999")?
  .run()
  .await
}
