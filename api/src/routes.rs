use actix_web::{get, post, put, delete, web, HttpResponse, Responder};

use mongodb::Collection;
use mongodb::bson::{doc, to_bson};
use mongodb::bson::oid::ObjectId;

use futures::stream::StreamExt;

use std::convert::TryFrom;

use crate::to_mongodb_entry;
use crate::inputs::{SingleContent, SingleStatus};
use crate::elements::{Element, ElementStatus};

#[get("/{user}")]
pub async fn get_elements(
  web::Path((user,)): web::Path<(String,)>,
  collection: web::Data<Collection>) -> impl Responder
{
  let filter = doc!{"user": user};
  let mut cursor = collection.find(filter, None).await.unwrap();

  let mut res: Vec<Element> = Vec::new();

  while let Some(result) = cursor.next().await {
    res.push(Element::try_from(result.unwrap()).unwrap());
  }

  HttpResponse::Ok().json(res)
}

#[post("/{user}/add_todo")]
pub async fn add_todo(
  web::Path((user,)): web::Path<(String,)>,
  collection: web::Data<Collection>,
  todo: web::Json<SingleContent>) -> impl Responder
{
  let insert = to_mongodb_entry(todo.into_inner(), user).unwrap();

  let id = collection.insert_one(insert, None)
    .await
    .unwrap()
    .inserted_id;

  let filter = doc!{"_id": id};

  let inserted_elem = collection.find_one(filter, None)
    .await
    .unwrap()
    .unwrap();

  HttpResponse::Ok().json(Element::try_from(inserted_elem).unwrap())
}

#[put("/{user}/{id}/status")]
pub async fn set_status(
  web::Path((user, id)): web::Path<(String, String)>,
  collection: web::Data<Collection>,
  new_status: web::Json<SingleStatus>) -> impl Responder
{
  let id = ObjectId::with_string(&id).unwrap();

  let filter = doc!{
    "_id": id,
    "user": user,
  };

  let update = doc!{
    "$set": {"status": to_bson(&new_status.status).unwrap()}
  };

  collection.update_one(filter, update, None).await.unwrap();

  HttpResponse::Ok().finish()
}

#[delete("/{user}/{id}")]
pub async fn delete_element(
  web::Path((user, id)): web::Path<(String, String)>,
  collection: web::Data<Collection>) -> impl Responder
{
  let id = ObjectId::with_string(&id).unwrap();

  let filter = doc!{
    "_id": id,
    "user": user,
  };

  collection.delete_one(filter, None).await.unwrap();

  HttpResponse::Ok().finish()
}

#[post("/{user}/empty_bin")]
pub async fn empty_bin(
  web::Path((user,)): web::Path<(String,)>,
  collection: web::Data<Collection>) -> impl Responder
{
  let filter = doc!{
    "user": user,
    "status": to_bson(&ElementStatus::Deleted).unwrap(),
  };

  collection.delete_many(filter, None).await.unwrap();

  HttpResponse::Ok().finish()
}
