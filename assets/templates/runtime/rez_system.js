//-----------------------------------------------------------------------------
// System
//-----------------------------------------------------------------------------

let system_proto = {
  __proto__: basic_object
};

function RezSystem(id, attributes) {
  this.id = id;
  this.game_object_type = "system";
  this.attributes = attributes;
  this.properties_to_archive = [];
  this.changed_attributes = [];
}

RezSystem.prototype = system_proto;
RezSystem.prototype.constructor = RezSystem;
window.Rez.System = RezSystem;
