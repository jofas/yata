use actix_web::{get, post, web, dev, App, HttpResponse, HttpServer,
  Responder};
use actix_web::client::{Client, ClientResponse};
use actix_cors::Cors;
use actix_rt::time;

use tokio::sync::RwLock;

use serde_derive::{Serialize, Deserialize};
//use serde_json as json;
use serde_qs as qs;

#[macro_use]
extern crate lazy_static;

use std::env;
use std::convert::From;
use std::default::Default;
use std::sync::Arc;
use std::time::Duration;

trait ToFlattenedUrlString {
  fn to_flattened_url_string(&self) -> String;
}

struct AdminToken {
  token_response: Option<TokenResponse>,
  endpoint: String,
  token_request: TokenRequest,
  client: Client,
}

impl AdminToken {
  fn new(
    endpoint: String, token_request: TokenRequest, client: Client
  ) -> AdminToken {
    AdminToken{
      token_response: None,
      endpoint: endpoint,
      token_request: token_request,
      client: client
    }
  }

  async fn get_token(&mut self) {
    self.token_response = Some(self.client.post(&self.endpoint)
      .header("Content-Type", "application/x-www-form-urlencoded")
      .send_body(self.token_request.to_flattened_url_string())
      .await
      .unwrap()
      .json()
      .await
      .unwrap());
  }

  fn expires_in(&self) -> Option<i64> {
    let token_response = self.token_response.as_ref()?;
    Some(token_response.expires_in)
  }
}

impl Default for AdminToken {
  fn default() -> Self {
    let token_request = TokenRequest::from(
      TokenRequestData::Admin(AdminTokenRequestData::default())
    );

    let client = Client::default();

    AdminToken::new(
      ADMIN_TOKEN_ENDPOINT.clone(), token_request, client
    )
  }
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

#[derive(Serialize, Deserialize, Debug)]
struct TokenResponse {
  access_token: String,
  refresh_token: String,
  expires_in: i64,
  refresh_expires_in: i64,
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

  into_response(client.post(&*TOKEN_ENDPOINT)
    .header("Content-Type", "application/x-www-form-urlencoded")
    .send_body(token_request.to_flattened_url_string())
    .await
    .unwrap()).await
}

#[get("/certs")]
async fn certs(client: web::Data<Client>) -> impl Responder {
  let response = client.get(&*CERTS_ENDPOINT)
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

#[derive(Serialize, Deserialize, Debug)]
#[allow(non_snake_case)]
struct RegisterRequest {
  firstName: String,
  lastName: String,
  email: String,
  enabled: bool,
  username: String,
  credentials: Vec<Credentials>,
}

#[derive(Serialize, Deserialize, Debug)]
struct Credentials {
  r#type: String,
  value: String,
}

// TODO: register endpoint
#[post("/register")]
async fn register(client: web::Data<Client>) -> impl Responder {
  let new_user = RegisterRequest{
    firstName: String::from("test"),
    lastName: String::from("test"),
    email: String::from("jonas@fassbender.dev"),
    enabled: true,
    username: String::from("test"),
    credentials: vec![
      Credentials{
        r#type: String::from("password"),
        value: String::from("test"),
      },
    ]
  };

  let mut response = client.get(&*REGISTER_ENDPOINT)
    .header("Content-Type", "application/json")
    //.header("Authorization", format!("Bearer {}", ))
    .send_json(&new_user)
    .await
    .unwrap();

  println!("{:?}", new_user);

  // pass json as to keycloak... receive something easier:
  //
  // { firstName:"...",
  //   lasName:"...",
  //   email:"...",
  //   enabled:"...",
  //   username:"...",
  //   credentials:[{type:"password", value:"..."}]
  // } ,

  // then here pass token in header as bearer
  "Unimplemented!"
}

lazy_static!{
  static ref CLIENT_ID: String = env::var("KEYCLOAK_PROXY_CLIENT_ID")
    .unwrap();
  static ref ADMIN_CLI_SECRET: String =
    env::var("KEYCLOAK_PROXY_ADMIN_CLI_SECRET").unwrap();
  static ref CERTS_ENDPOINT: String = format!(
    "http://{}:8080/auth/realms/{}/protocol/openid-connect/certs",
    env::var("KEYCLOAK_PROXY_KEYCLOAK_SERVER").unwrap(),
    env::var("KEYCLOAK_PROXY_REALM").unwrap(),
  );
  static ref TOKEN_ENDPOINT: String = format!(
    "http://{}:8080/auth/realms/{}/protocol/openid-connect/token",
    env::var("KEYCLOAK_PROXY_KEYCLOAK_SERVER").unwrap(),
    env::var("KEYCLOAK_PROXY_REALM").unwrap(),
  );
  static ref REGISTER_ENDPOINT: String = format!(
    "http://{}:8080/auth/admin/realms/{}/users",
    env::var("KEYCLOAK_PROXY_KEYCLOAK_SERVER").unwrap(),
    env::var("KEYCLOAK_PROXY_REALM").unwrap(),
  );
  static ref ADMIN_TOKEN_ENDPOINT: String = format!(
    "http://{}:8080/auth/realms/master/protocol/openid-connect/token",
    env::var("KEYCLOAK_PROXY_KEYCLOAK_SERVER").unwrap(),
  );
}

static ADMIN_CLI_CLIENT_ID: &'static str = "admin-cli";

fn spawn_task_for_periodically_refreshing_admin_token(
  admin_token: Arc<RwLock<AdminToken>>
) {
  actix_rt::spawn(async move {
    loop {
      let delay = {
        let expires_in = admin_token.read().await.expires_in()
          .unwrap() as f64;

        Duration::from_secs_f64(expires_in * 0.98)
      };

      time::delay_for(delay).await;
      admin_token.write().await.get_token().await;
      println!("successfully refreshed admin token");
    }
  });
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
  let port = env::var("KEYCLOAK_PROXY_PORT").unwrap();
  let addr = format!("0.0.0.0:{}", port);

  let mut admin_token = AdminToken::default();
  admin_token.get_token().await;

  let admin_token: Arc<RwLock<AdminToken>> =
    Arc::new(RwLock::new(admin_token));

  spawn_task_for_periodically_refreshing_admin_token(
    admin_token.clone()
  );

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
      .service(register)
  })
  .bind(&addr)?
  .run()
  .await
}
