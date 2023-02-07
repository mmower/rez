//-----------------------------------------------------------------------------
// Faction
//-----------------------------------------------------------------------------

let faction_proto = {
  __proto__: basic_object
};

function RezFaction(id, attributes) {
  this.id = id;
  this.game_object_type = "faction";
  this.attributes = attributes;
  this.properties_to_archive = [];
  this.changed_attributes = [];
}

RezFaction.prototype = faction_proto;
RezFaction.prototype.constructor = RezFaction;
window.Rez.Faction = RezFaction;
