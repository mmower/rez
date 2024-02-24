//-----------------------------------------------------------------------------
// Object
//
// The RezObject is a way for authors to define their own types of object
// that don't belong to one of the provided functionalities (e.g. actors,
// items, and the like). An author can define a RezObject and put whatever
// data they like into it and make use of it from their own scripted functions
// or behaviours.
//-----------------------------------------------------------------------------

function RezObject(id, attributes) {
  this.id = id;
  this.game_object_type = "object";
  this.attributes = attributes;
  this.properties_to_archive = [];
  this.changed_attributes = [];
}

RezObject.prototype = {
  __proto__: basic_object,
  constructor: RezObject
};

window.RezObject = RezObject;
