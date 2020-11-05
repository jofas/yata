use actix_web::{get, post, web, App, HttpRequest, HttpResponse,
  HttpServer, Responder};
use actix_cors::Cors;
use serde_derive::{Serialize, Deserialize};

#[macro_use]
extern crate lazy_static;

use std::sync::{Mutex};

#[derive(Serialize, Clone)]
struct Elements {
  todos: Vec<String>,
  done: Vec<String>,
  deleted: Vec<String>
}

impl Elements {
  fn new() -> Self {
    Self {todos: Vec::new(), done: Vec::new(), deleted: Vec::new()}
  }

  fn add_todo(&mut self, value: String) {
    self.todos.insert(0, value);
  }

  fn set_done(&mut self, index: usize) {
    move_element(&mut self.todos, &mut self.done, index);
  }

  fn unset_done(&mut self, index: usize) {
    move_element(&mut self.done, &mut self.todos, index);
  }

  fn unset_deleted(&mut self, index: usize) {
    move_element(&mut self.deleted, &mut self.todos, index);
  }

  fn set_todo_deleted(&mut self, index: usize) {
    move_element(&mut self.todos, &mut self.deleted, index);
  }

  fn set_done_deleted(&mut self, index: usize) {
    move_element(&mut self.done, &mut self.deleted, index);
  }

  fn delete_completely(&mut self, index: usize) {
    self.deleted.remove(index);
  }

  fn delete_all_completely(&mut self) {
    self.deleted = Vec::new();
  }
}

fn move_element(src: &mut Vec<String>, dest: &mut Vec<String>, index: usize) {
  dest.insert(0, src.remove(index));
}

#[derive(Deserialize)]
struct AddTodo {
  value: String
}

// data as global variable
//
// TODO: into database
//
// somehow get global db handle (via App.data)
//
//
lazy_static! {
  static ref DATA: Mutex<Elements> = Mutex::new(Elements::new());
}

#[get("/")]
async fn get_elements() -> impl Responder {
  HttpResponse::Ok().json((*DATA.lock().unwrap()).clone())
}

#[post("/add_todo")]
async fn add_todo(todo: web::Json<AddTodo>) -> impl Responder {
  DATA.lock().unwrap().add_todo(todo.value.clone());
  println!("Adding TODO: {}", todo.value);
  HttpResponse::Ok().finish()
}

#[post("/set_done/{index}")]
async fn set_done(web::Path((index,)): web::Path<(usize,)>) -> impl Responder {
  DATA.lock().unwrap().set_done(index);
  println!("Setting TODO to done: {}", index);
  HttpResponse::Ok().finish()
}

#[post("/unset_done/{index}")]
async fn unset_done(web::Path((index,)): web::Path<(usize,)>) -> impl Responder {
  DATA.lock().unwrap().unset_done(index);
  println!("Unsetting done: {}", index);
  HttpResponse::Ok().finish()
}

#[post("/unset_deleted/{index}")]
async fn unset_deleted(web::Path((index,)): web::Path<(usize,)>) -> impl Responder {
  DATA.lock().unwrap().unset_deleted(index);
  println!("Unsetting deleted: {}", index);
  HttpResponse::Ok().finish()
}

#[post("/set_todo_deleted/{index}")]
async fn set_todo_deleted(web::Path((index,)): web::Path<(usize,)>) -> impl Responder {
  DATA.lock().unwrap().set_todo_deleted(index);
  println!("Setting TODO to deleted: {}", index);
  HttpResponse::Ok().finish()
}

#[post("/set_done_deleted/{index}")]
async fn set_done_deleted(web::Path((index,)): web::Path<(usize,)>) -> impl Responder {
  DATA.lock().unwrap().set_done_deleted(index);
  println!("Setting done to deleted: {}", index);
  HttpResponse::Ok().finish()
}

#[post("/delete_completely/{index}")]
async fn delete_completely(web::Path((index,)): web::Path<(usize,)>) -> impl Responder {
  DATA.lock().unwrap().delete_completely(index);
  println!("deleting completely: {}", index);
  HttpResponse::Ok().finish()
}

#[post("/delete_completely")]
async fn delete_all_completely() -> impl Responder {
  DATA.lock().unwrap().delete_all_completely();
  println!("deleting all completely");
  HttpResponse::Ok().finish()
}

use mongodb::{Client, Collection};
use mongodb::options::ClientOptions;
use mongodb::error::Result as MDBResult;
use mongodb::bson::doc;

use futures::stream::StreamExt;

async fn init_database() -> MDBResult<Collection> {
  let client_options = ClientOptions::parse("mongodb://localhost:27017").await?;
  let client = Client::with_options(client_options)?;
  let db = client.database("yata_db");
  Ok(db.collection("yata_collection"))
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
  println!("STARTING YATA_API SERVER");

  let collection = init_database().await.unwrap();

  let docs = vec![
    doc! { "title": "1984", "author": "George Orwell" },
    doc! { "title": "Animal Farm", "author": "George Orwell" },
    doc! { "title": "The Great Gatsby", "author": "F. Scott Fitzgerald" },
  ];

  collection.insert_many(docs, None).await.unwrap();

  let filter = doc!{};
  let mut cursor = collection.find(filter, None).await.unwrap();

  while let Some(result) = cursor.next().await {
    println!("{:?}", result.unwrap());
  }

  println!("INSERTED DATA");

  HttpServer::new(move || {
    App::new()
      .data(collection.clone())
      .wrap(Cors::permissive())
      .service(get_elements)
      .service(add_todo)
      .service(set_done)
      .service(unset_done)
      .service(unset_deleted)
      .service(set_todo_deleted)
      .service(set_done_deleted)
      .service(delete_completely)
      .service(delete_all_completely)
  })
  .bind("0.0.0.0:9999")?
  .run()
  .await
}
