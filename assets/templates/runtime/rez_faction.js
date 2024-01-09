//-----------------------------------------------------------------------------
// Faction
//-----------------------------------------------------------------------------

function RezFaction(id, attributes) {
  this.id = id;
  this.game_object_type = "faction";
  this.attributes = attributes;
  this.properties_to_archive = [];
  this.changed_attributes = [];
}

RezFaction.prototype = {
  __proto__: basic_object,
  constructor: RezFaction
};

window.RezFaction = RezFaction;
