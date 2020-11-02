use actix_web::{get, post, web, App, HttpRequest, HttpResponse,
  HttpServer, Responder};
use actix_cors::Cors;

#[get("/")]
async fn all(req: HttpRequest) -> impl Responder {
  println!("Request: {:?}", req);
  let response = HttpResponse::Ok()
    .body("Hello!");
  println!("{:?}", response.headers());
  response
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
// GET /todos gets the list of todos
// GET /done gets the list of done items
// GET /deleted gets the list of deleted items
// POST /todos {"value": "<...>"} adds a new todo to the list
//
// connect the API to a database

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
