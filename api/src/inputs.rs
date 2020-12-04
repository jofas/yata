use serde_derive::Deserialize;

use crate::elements::ElementStatus;

#[derive(Deserialize)]
pub struct SingleContent {
  pub content: String,
}

#[derive(Deserialize)]
pub struct SingleStatus {
  pub status: ElementStatus,
}
