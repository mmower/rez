//-----------------------------------------------------------------------------
// Relationship
//-----------------------------------------------------------------------------

function RezRelationship(id, attributes) {
  this.id = id;
  this.game_object_type = "relationship";
  this.attributes = attributes;
  this.properties_to_archive = [];
  this.changed_attributes = [];
}

RezRelationship.prototype = {
  __proto__: basic_object,
  constructor: RezRelationship,

  get source() {
    return this.getAttributeValue("source");
  },

  get target() {
    return this.getAttributeValue("target");
  },
};

window.RezRelationship = RezRelationship;
