//-----------------------------------------------------------------------------
// Location
//-----------------------------------------------------------------------------

let location_proto = {
  __proto__: basic_object
};

function RezLocation(id, template, attributes) {
  this.id = id;
  this.game_object_type = "location";
  this.attributes = attributes;
  this.template = template;
  this.properties_to_archive = [];
  this.changed_attributes = [];
}

RezLocation.prototype = location_proto;
RezLocation.prototype.constructor = RezLocation;
window.Rez.Location = RezLocation;
