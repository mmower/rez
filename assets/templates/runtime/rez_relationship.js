//-----------------------------------------------------------------------------
// Relationship
//-----------------------------------------------------------------------------

let relationship_proto = {
  __proto__: basic_object,

  getAffinity() {
    return this.getAttributeValue("affinity");
  },

  checkInRange(affinity) {
    if(typeof(affinity) != "number") {
      throw "Cannot set affinity to a non-numeric value!";
    } else if(affinity < -5.0) {
      throw "-5.0 is the lowest affinity value";
    } else if(affinity > 5.0) {
      throw "5.0 is the greatest affinity value";
    }
  },

  setAffinity(affinity) {
    const prior_affinity = this.getAffinity();
    this.checkInRange(affinity);
    this.setAttribute("affinity", affinity);
    this.runEvent("change_affinity", {prior: cur_affinity, current: affinity});
  },

  alterAffinity(change) {
    if(typeof(change) != "number") {
      throw "Affinity values are numbers!";
    }
    const cur_affinity = this.getAffinity();
    const new_affinity = cur_affinity + change;
    this.checkInRange(new_affinity);
    this.setAttribute("affinity", new_affinity);
    this.runEvent("change_affinity", {prior: cur_affinity, current: new_affinity});
  },

  getSource() {
    return this.getAttributeValue("source");
  },

  getTarget() {
    return this.getAttributeValue("target");
  }
}

function RezRelationship(id, attributes) {
  this.id = id;
  this.game_object_type = "relationship";
  this.attributes = attributes;
  this.properties_to_archive = [];
  this.changed_attributes = [];
}

RezRelationship.prototype = relationship_proto;
RezRelationship.prototype.constructor = RezRelationship;
window.Rez.Relationship = RezRelationship;
