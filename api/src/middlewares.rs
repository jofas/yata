use actix_web::Error as ActixError;
use actix_web::dev::ServiceRequest;

use actix_web_httpauth::extractors::AuthenticationError;
use actix_web_httpauth::extractors::bearer::BearerAuth;
use actix_web_httpauth::extractors::bearer::Config as BearerConfig;

use jwks_client::keyset::KeyStore;
use jwks_client::error::Error as JWTError;

use std::sync::Arc;


pub async fn auth(
  req: ServiceRequest,
  bearer: BearerAuth,
  key_set:Arc<KeyStore>) -> Result<ServiceRequest, ActixError>
{
  match key_set.verify(bearer.token()) {
    Ok(jwt) => {
      let username = jwt.payload().get_str("preferred_username").unwrap();
      let path_root = req.path().split("/").nth(1).unwrap();

      if username == path_root {
        return Ok(req);
      }
    },
    Err(JWTError { msg, typ: _ }) => {
      eprintln!("Could not verify token. Reason: {}", msg);
    }
  }

  let config = req.app_data::<BearerConfig>()
    .map(|data| data.clone())
    .unwrap_or_else(Default::default);

  Err(AuthenticationError::from(config).into())
}
