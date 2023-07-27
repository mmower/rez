//-----------------------------------------------------------------------------
// Location
//-----------------------------------------------------------------------------

let location_proto = {
  __proto__: basic_object,

  get template() {
    return this.getAttribute("description_template");
  },
};

function RezLocation(id, attributes) {
  this.id = id;
  this.game_object_type = "location";
  this.attributes = attributes;
  this.properties_to_archive = [];
  this.changed_attributes = [];
}

RezLocation.prototype = location_proto;
RezLocation.prototype.constructor = RezLocation;
window.Rez.Location = RezLocation;
