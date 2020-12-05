use mongodb::bson::document::ValueAccessError;
use mongodb::bson::de::Error as BsonDeserializationError;
use mongodb::bson::ser::Error as BsonSerializationError;

use std::convert::From;
use std::option::NoneError;

#[derive(Debug)]
pub enum ParseDocumentError {
  NotPresent,
  UnexpectedType,
  BsonDeserializationError(BsonDeserializationError),
  BsonSerializationError(BsonSerializationError),
  Impossible
}

impl From<NoneError> for ParseDocumentError {
  fn from(_: NoneError) -> Self {
    ParseDocumentError::NotPresent
  }
}

impl From<ValueAccessError> for ParseDocumentError {
  fn from(e: ValueAccessError) -> Self {
    match e {
      ValueAccessError::NotPresent =>
        ParseDocumentError::NotPresent,
      ValueAccessError::UnexpectedType =>
        ParseDocumentError::UnexpectedType,
      _ => ParseDocumentError::Impossible,
    }
  }
}

impl From<BsonDeserializationError> for ParseDocumentError {
  fn from(e: BsonDeserializationError) -> Self {
    ParseDocumentError::BsonDeserializationError(e)
  }
}

impl From<BsonSerializationError> for ParseDocumentError {
  fn from(e: BsonSerializationError) -> Self {
    ParseDocumentError::BsonSerializationError(e)
  }
}
