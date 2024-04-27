//-----------------------------------------------------------------------------
// System
//-----------------------------------------------------------------------------

function RezSystem(id, attributes) {
  this.id = id;
  this.game_object_type = "system";
  this.attributes = attributes;
  this.properties_to_archive = [];
  this.changed_attributes = [];
}

RezSystem.prototype = {
  __proto__: basic_object,
  constructor: RezSystem
};
