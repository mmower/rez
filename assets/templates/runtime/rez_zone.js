//-----------------------------------------------------------------------------
// Zone
//-----------------------------------------------------------------------------

let zone_proto = {
  __proto__: basic_object,

  addLocation(location) {
    location.zone = this;
    this.locations[location.id] = location;
  },

  getLocation(location_id) {
    return this.locations[location_id];
  }
};

function RezZone(id, attributes) {
  this.id = id;
  this.game_object_type = "zone";
  this.locations = {};
  this.attributes = attributes;
  this.properties_to_archive = [];
  this.changed_attributes = [];
}

RezZone.prototype = zone_proto;
RezZone.prototype.constructor = RezZone;
window.Rez.Zone = RezZone;
