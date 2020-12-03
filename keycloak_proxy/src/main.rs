use actix_web::{get, post, web, dev, App, HttpResponse, HttpServer,
  Responder};
use actix_web::client::{Client, ClientResponse};
use actix_cors::Cors;
use actix_rt::time;
use actix_web_httpauth::headers::authorization::Bearer;

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
}

impl AdminToken {
  fn new(endpoint: String, token_request: TokenRequest) -> AdminToken
  {
    AdminToken {
      token_response: None,
      endpoint: endpoint,
      token_request: token_request,
    }
  }

  async fn get_token(&mut self, client: &Client) {
    self.token_response = Some(client.post(&self.endpoint)
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

  fn access_token(&self) -> Option<String> {
    let token_response = self.token_response.as_ref()?;
    Some(token_response.access_token.clone())
  }
}

impl Default for AdminToken {
  fn default() -> Self {
    let token_request = TokenRequest::from(
      TokenRequestData::Admin(AdminTokenRequestData::default())
    );
    AdminToken::new(ADMIN_TOKEN_ENDPOINT.clone(), token_request)
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

impl From<ProxyRegisterRequest> for RegisterRequest {
  fn from(proxy: ProxyRegisterRequest) -> RegisterRequest {
    RegisterRequest {
      firstName: proxy.first_name,
      lastName: proxy.last_name,
      email: proxy.email,
      enabled: true,
      username: proxy.username,
      credentials: vec![
        Credentials {
          r#type: String::from("password"),
          value: proxy.password,
        }
      ],
    }
  }
}

#[derive(Serialize, Deserialize, Debug)]
struct Credentials {
  r#type: String,
  value: String,
}

#[derive(Serialize, Deserialize, Debug)]
struct ProxyRegisterRequest {
  first_name: String,
  last_name: String,
  username: String,
  email: String,
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
      eprintln!("{:?}", e);
      HttpResponse::InternalServerError().finish()
    }
  }
}

#[post("/register")]
async fn register(
  client: web::Data<Client>,
  admin_token: web::Data<Arc<RwLock<AdminToken>>>,
  registration_data: web::Json<ProxyRegisterRequest>,
) -> impl Responder {
  let registration =
    RegisterRequest::from(registration_data.into_inner());

  let access_token = admin_token.read().await.access_token().unwrap();
  let access_token = Bearer::new(access_token);

  into_response(client.post(&*REGISTER_ENDPOINT)
    .header("Content-Type", "application/json")
    .header("Authorization", access_token)
    .send_json(&registration)
    .await
    .unwrap()).await
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
    let client = Client::default();
    loop {
      admin_token.write().await.get_token(&client).await;
      println!("successfully refreshed admin token");

      time::delay_for({
        let expires_in = admin_token.read().await.expires_in()
          .unwrap() as f64;

        Duration::from_secs_f64(expires_in * 0.98)
      }).await;
    }
  });
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
  let port = env::var("KEYCLOAK_PROXY_PORT").unwrap();
  let addr = format!("0.0.0.0:{}", port);

  let admin_token: Arc<RwLock<AdminToken>> =
    Arc::new(RwLock::new(AdminToken::default()));

  spawn_task_for_periodically_refreshing_admin_token(
    admin_token.clone()
  );

  println!("STARTING KEYCLOAK_PROXY SERVER");

  HttpServer::new(move || {
    App::new()
      .data(Client::default())
      .data(admin_token.clone())
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
