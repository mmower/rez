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

  get affinity() {
    return this.getAttributeValue("affinity");
  },

  set affinity(affinity) {
    const prior_affinity = this.aAffinity;
    this.checkInRange(affinity);
    this.setAttribute("affinity", affinity);
    this.runEvent("change_affinity", {
      prior: prior_affinity,
      current: affinity,
    });
  },

  get tags() {
    return this.getAttributeValue("tags");
  },

  checkInRange(affinity) {
    if (typeof affinity != "number") {
      throw "Cannot set affinity to a non-numeric value!";
    } else if (affinity < -5.0) {
      throw "-5.0 is the lowest affinity value";
    } else if (affinity > 5.0) {
      throw "5.0 is the greatest affinity value";
    }
  },

  alterAffinity(change) {
    if (typeof change != "number") {
      throw "Affinity values are numbers!";
    }
    const cur_affinity = this.getAffinity();
    const new_affinity = cur_affinity + change;
    this.checkInRange(new_affinity);
    this.setAttribute("affinity", new_affinity);
    this.runEvent("change_affinity", {
      prior: cur_affinity,
      current: new_affinity,
    });
  },

  getSource() {
    return this.getAttributeValue("source");
  },

  getTarget() {
    return this.getAttributeValue("target");
  },
};

window.RezRelationship = RezRelationship;
