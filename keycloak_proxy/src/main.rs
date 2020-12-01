use actix_web::{get, post, web, dev, App, HttpResponse, HttpServer,
  Responder};
use actix_web::client::{Client, ClientResponse};

use actix_cors::Cors;

use serde_derive::{Serialize, Deserialize};
//use serde_json as json;
use serde_qs as qs;

#[macro_use]
extern crate lazy_static;

use std::convert::From;
use std::env;
use std::default::Default;
use std::sync::Arc;

trait ToFlattenedUrlString {
  fn to_flattened_url_string(&self) -> String;
}

#[derive(Serialize, Deserialize, Debug)]
struct TokenRequest {
  data: TokenRequestData,
  meta: TokenRequestMeta,
}

impl ToFlattenedUrlString for TokenRequest {
  fn to_flattened_url_string(&self) -> String {
    format!(
      "{}&{}",
      self.data.to_flattened_url_string(),
      qs::to_string(&self.meta).unwrap(),
    )
  }
}

impl From<TokenRequestData> for TokenRequest {
  fn from(data: TokenRequestData) -> Self {
    let meta = TokenRequestMeta::from(&data);
    TokenRequest{data: data, meta: meta}
  }
}

#[derive(Serialize, Deserialize, Debug)]
enum TokenRequestData {
  RefreshToken(RefreshTokenRequestData),
  Password(PasswordTokenRequestData),
  Admin(AdminTokenRequestData),
}

impl ToFlattenedUrlString for TokenRequestData {
  fn to_flattened_url_string(&self) -> String {
    match self {
      TokenRequestData::RefreshToken(data) =>
        qs::to_string(&data).unwrap(),
      TokenRequestData::Password(data) =>
        qs::to_string(&data).unwrap(),
      TokenRequestData::Admin(data) =>
        qs::to_string(&data).unwrap(),
    }
  }
}

#[derive(Serialize, Deserialize, Debug)]
struct TokenRequestMeta {
  grant_type: String,
  client_id: String,
}

impl From<&TokenRequestData> for TokenRequestMeta {
  fn from(token_request_data: &TokenRequestData) -> Self {
    match token_request_data {
      &TokenRequestData::RefreshToken(_) => TokenRequestMeta {
        grant_type: String::from("refresh_token"),
        client_id: CLIENT_ID.clone(),
      },
      &TokenRequestData::Password(_) => TokenRequestMeta {
        grant_type: String::from("password"),
        client_id: CLIENT_ID.clone(),
      },
      &TokenRequestData::Admin(_) => TokenRequestMeta {
        grant_type: String::from("client_credentials"),
        client_id: String::from(ADMIN_CLI_CLIENT_ID),
      },
    }
  }
}

#[derive(Serialize, Deserialize, Debug)]
struct RefreshTokenRequestData {
  refresh_token: String,
}

impl RefreshTokenRequestData {
  fn new(refresh_token: String) -> RefreshTokenRequestData {
    RefreshTokenRequestData{refresh_token: refresh_token}
  }
}

#[derive(Serialize, Deserialize, Debug)]
struct PasswordTokenRequestData {
  username: String,
  password: String,
}

#[derive(Serialize, Deserialize, Debug)]
struct AdminTokenRequestData {
  client_secret: String,
}

impl Default for AdminTokenRequestData {
  fn default() -> Self {
    AdminTokenRequestData{client_secret: ADMIN_CLI_SECRET.clone()}
  }
}

async fn into_response(
  mut client_response: ClientResponse<dev::Decompress<dev::Payload>>
) -> HttpResponse {
  let mut response = HttpResponse::build(client_response.status());

  client_response.headers().iter().for_each(|(k, v)| {
    response.set_header(k, v.clone());
  });

  response.body(client_response.body().await.unwrap())
}

#[post("/token")]
async fn token(
  body: web::Json<TokenRequestData>,
  client: web::Data<Client>) -> impl Responder
{
  let token_request = TokenRequest::from(body.into_inner());

  into_response(client.post(format!("{}{}", *SERVER, TOKEN_ENDPOINT))
    .header("Content-Type", "application/x-www-form-urlencoded")
    .send_body(token_request.to_flattened_url_string())
    .await
    .unwrap()).await
}

#[get("/certs")]
async fn certs(client: web::Data<Client>) -> impl Responder {
  let response = client.get(format!("{}{}", SERVER.clone(), CERTS_ENDPOINT))
    .send()
    .await;

  match response {
    Ok(response) => into_response(response).await,
    Err(e) => {
      println!("{:?}", e);
      HttpResponse::InternalServerError().finish()
    }
  }
}

// TODO: register endpoint
#[post("/register")]
async fn register(client: web::Data<Client>) -> impl Responder {
  // TODO: get access token (refresh in different thread all the time)

  // then here pass token in header as bearer
  "Unimplemented!"
}

lazy_static!{
  static ref CLIENT_ID: String = env::var("KEYCLOAK_PROXY_CLIENT_ID")
    .unwrap();
  static ref SERVER: String = format!(
    "http://{}:8080/auth/realms/{}/",
    env::var("KEYCLOAK_PROXY_KEYCLOAK_SERVER").unwrap(),
    env::var("KEYCLOAK_PROXY_REALM").unwrap(),
  );
  static ref ADMIN_CLI_SECRET: String =
    env::var("KEYCLOAK_PROXY_ADMIN_CLI_SECRET").unwrap();
}

static ADMIN_CLI_CLIENT_ID: &'static str = "admin-cli";
static CERTS_ENDPOINT: &'static str = "protocol/openid-connect/certs";
static TOKEN_ENDPOINT: &'static str = "protocol/openid-connect/token";

#[derive(Serialize, Deserialize, Debug)]
struct TokenResponse {
  access_token: String,
  refresh_token: String,
  expires_in: i64,
  refresh_expires_in: i64,
}

use actix_rt::time;
use std::time::Duration;

use tokio::sync::Mutex;

#[actix_web::main]
async fn main() -> std::io::Result<()> {
  println!("STARTING KEYCLOAK_PROXY SERVER");

  let port = env::var("KEYCLOAK_PROXY_PORT").unwrap();
  let addr = format!("0.0.0.0:{}", port);

  let admin_token_endpoint = format!(
    "http://{}:8080/auth/realms/master/protocol/openid-connect/token",
    env::var("KEYCLOAK_PROXY_KEYCLOAK_SERVER").unwrap()
  );

  let admin_token_request = TokenRequest::from(
    TokenRequestData::Admin(AdminTokenRequestData::default())
  );

  let admin_token: Arc<Mutex<TokenResponse>> = Arc::new(Mutex::new(
    Client::default().post(&admin_token_endpoint)
      .header("Content-Type", "application/x-www-form-urlencoded")
      .send_body(admin_token_request.to_flattened_url_string())
      .await
      .unwrap()
      .json()
      .await
      .unwrap()));

  actix_rt::spawn(async move {
    loop {
      let mut admin_token_inner = admin_token.lock().await;

      time::delay_for(Duration::from_secs_f64(
          admin_token_inner.expires_in as f64 * 0.98
      )).await;

      let admin_token_request = TokenRequest::from(
        TokenRequestData::Admin(AdminTokenRequestData::default())
      );

      *admin_token_inner =
        Client::default().post(&admin_token_endpoint)
          .header("Content-Type", "application/x-www-form-urlencoded")
          .send_body(admin_token_request.to_flattened_url_string())
          .await
          .unwrap()
          .json()
          .await
          .unwrap();
    }
  });

  HttpServer::new(move || {
    App::new()
      .data(Client::default())
      .wrap(Cors::permissive()) // TODO: only yata_frontend
      /*
      .wrap_fn(|req, srv| {
        println!("{:?}", req);
        srv.call(req).map(|res| {
          println!("{:?}", res);
          res
        })
      })
      */
      .service(certs)
      .service(token)
      .service(register)
  })
  .bind(&addr)?
  .run()
  .await
}
