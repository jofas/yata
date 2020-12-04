use serde_derive::{Serialize, Deserialize};

use mongodb::bson::Document;
use mongodb::bson::from_bson;

use chrono::DateTime;
use chrono::offset::Utc;

use std::convert::TryFrom;

#[derive(Serialize, Deserialize, Debug)]
pub enum ElementStatus { Todo, Done, Deleted }

#[derive(Serialize, Deserialize, Debug)]
pub struct Element {
  id: String,
  content: String,
  status: ElementStatus,
  created: DateTime<Utc>,
}

impl TryFrom<Document> for Element {
  type Error = crate::errors::ParseDocumentError;

  fn try_from(doc: Document) -> Result<Self, Self::Error> {
    let id = doc.get_object_id("_id")?.to_hex();
    let content = String::from(doc.get_str("content")?);
    let status: ElementStatus =
      from_bson(doc.get("status")?.clone())?;
    let created = *doc.get_datetime("created")?;

    Ok(Element{
      id: id, content: content, status: status, created: created
    })
  }
}
