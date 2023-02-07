//-----------------------------------------------------------------------------
// Slot
//-----------------------------------------------------------------------------

let slot_proto = {
  __proto__: basic_object,

  capacity() {
    return this.getAttributeValue("capacity");
  },
};

function RezSlot(id, attributes) {
  this.id = id;
  this.game_object_type = "slot";
  this.attributes = attributes;
  this.properties_to_archive = [];
  this.changed_attributes = [];
}

RezSlot.prototype = slot_proto;
RezSlot.prototype.constructor = RezSlot;
window.Rez.Slot = RezSlot;
