use actix_web::{get, post, web, dev, App, HttpResponse, HttpServer,
  Responder};
use actix_web::client::{Client, ClientResponse};

use actix_cors::Cors;

use serde_derive::{Serialize, Deserialize};
//use serde_json as json;
use serde_qs as qs;

use std::convert::From;

trait IntoFlattenedUrlString {
  fn into_flattened_url_string(self) -> String;
}

#[derive(Serialize, Deserialize, Debug)]
struct TokenRequest {
  data: TokenRequestData,
  meta: TokenRequestMeta,
}

impl IntoFlattenedUrlString for TokenRequest {
  fn into_flattened_url_string(self) -> String {
    format!(
      "{}&{}",
      self.data.into_flattened_url_string(),
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
}

impl IntoFlattenedUrlString for TokenRequestData {
  fn into_flattened_url_string(self) -> String {
    match self {
      TokenRequestData::RefreshToken(data) =>
        qs::to_string(&data).unwrap(),
      TokenRequestData::Password(data) =>
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
        client_id: String::from(CLIENT_ID),
      },
      &TokenRequestData::Password(_) => TokenRequestMeta {
        grant_type: String::from("password"),
        client_id: String::from(CLIENT_ID),
      },
    }
  }
}

#[derive(Serialize, Deserialize, Debug)]
struct RefreshTokenRequestData {
  refresh_token: String,
}

#[derive(Serialize, Deserialize, Debug)]
struct PasswordTokenRequestData {
  username: String,
  password: String,
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

static CLIENT_ID: &'static str = "yata_keycloak_proxy";
static SRV: &'static str = "http://localhost:8080/auth/realms/yata/";

static CERTS_ENDPOINT: &'static str = "protocol/openid-connect/certs";
static TOKEN_ENDPOINT: &'static str = "protocol/openid-connect/token";

#[post("/token")]
async fn token(
  body: web::Json<TokenRequestData>,
  client: web::Data<Client>) -> impl Responder
{
  let token_request = TokenRequest::from(body.into_inner());

  into_response(client.post(format!("{}{}", SRV, TOKEN_ENDPOINT))
    .header("Content-Type", "application/x-www-form-urlencoded")
    .send_body(token_request.into_flattened_url_string())
    .await
    .unwrap()).await
}

#[get("/certs")]
async fn certs(client: web::Data<Client>) -> impl Responder {
  into_response(client.get(format!("{}{}", SRV, CERTS_ENDPOINT))
    .send()
    .await
    .unwrap()).await
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
  println!("STARTING KEYCLOAK_PROXY SERVER");

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
  })
  .bind("0.0.0.0:9998")?
  .run()
  .await
}
