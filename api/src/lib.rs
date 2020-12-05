#![feature(try_trait)]

use mongodb::bson::{Document, doc, to_bson};

use chrono::offset::Utc;

pub mod errors;
pub mod inputs;
pub mod elements;
pub mod routes;
pub mod middlewares;

pub fn to_mongodb_entry(c: crate::inputs::SingleContent, user: String)
  -> Result<Document, crate::errors::ParseDocumentError>
{
  Ok(doc! {
    "user": user,
    "content": c.content,
    "status": to_bson(&crate::elements::ElementStatus::Todo)?,
    "created": Utc::now(),
  })
}

#[cfg(test)]
mod tests {
  use super::*;

  use chrono::offset::Utc;

  use mongodb::bson::oid::ObjectId;

  use crate::errors::ParseDocumentError;
  use crate::to_mongodb_entry;
  use crate::elements::{Element, ElementStatus};
  use crate::inputs::SingleContent;

  use std::convert::TryFrom;

  #[test]
  fn test_to_mongodb_entry() -> Result<(), ParseDocumentError> {
    let c = SingleContent{content: String::from("some content")};
    let user = String::from("some user");

    to_mongodb_entry(c, user)?;
    Ok(())
  }

  #[test]
  fn test_element_from_mongodb_document()
    -> Result<(), ParseDocumentError>
  {
    let doc = doc! {
      "_id": ObjectId::new(),
      "content": String::from("some content"),
      "status": to_bson(&ElementStatus::Todo).unwrap(),
      "created": Utc::now()
    };

    Element::try_from(doc)?;
    Ok(())
  }
}
