#![feature(try_trait)]

use mongodb::bson::{Document, doc, to_bson};

use chrono::offset::Utc;

pub mod errors;
pub mod inputs;
pub mod elements;

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
