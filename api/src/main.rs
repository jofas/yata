use actix_web::{get, post, web, App, HttpRequest, HttpResponse,
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
use mongodb::bson::doc;

use futures::stream::StreamExt;

#[macro_use]
extern crate lazy_static;

#[macro_use]
extern crate partial_application;

use std::sync::{Mutex, Arc};

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
// change api data model:
//
// Entry {
//  value: String,
//  list: Enum<Todo, Done, Deleted>,
//  index: usize,
// }
//
//
//
// in event api: query for the exact entry with index and list
//               sucks too, since I need to change indices
//
//
lazy_static! {
  static ref DATA: Mutex<Elements> = Mutex::new(Elements::new());
}

#[get("/")]
async fn get_elements(db: web::Data<Collection>) -> impl Responder {
  /*
  let filter = doc!{};
  let mut cursor = db.find(filter, None).await.unwrap();

  while let Some(result) = cursor.next().await {
    let document = result.unwrap();

    println!("{:?}", result.unwrap());
  }
  */
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

async fn init_database() -> MDBResult<Collection> {
  let client_options = ClientOptions::parse("mongodb://localhost:27017").await?;
  let client = Client::with_options(client_options)?;
  let db = client.database("yata_db");
  Ok(db.collection("yata_collection"))
}

async fn auth(
  req: ServiceRequest,
  bearer: BearerAuth,
  key_set:Arc<KeyStore>) -> Result<ServiceRequest, ActixError>
{
  match key_set.verify(bearer.token()) {
    Ok(jwt) => {
      // TODO: make sure user can access path

      println!("{:?}", jwt.payload());
      Ok(req)
    }
    Err(JWTError { msg, typ: _ }) => {
      eprintln!("Could not verify token. Reason: {}", msg);

      let config = req.app_data::<BearerConfig>()
        .map(|data| data.clone())
        .unwrap_or_else(Default::default);

      Err(AuthenticationError::from(config).into())
    }
  }
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
  println!("STARTING YATA_API SERVER");

  /*

  // PLAYING AROUND WITH MONGODB
  let collection = init_database().await.unwrap();

  // save the todos as {"value": "...", "state": "{todo|done|deleted}"}
  // and have a collection for each user

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
      //.data(collection.clone())
      .wrap(HttpAuthentication::bearer(auth_fn.clone()))
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
