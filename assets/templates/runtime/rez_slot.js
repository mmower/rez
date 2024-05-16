//-----------------------------------------------------------------------------
// Slot
//-----------------------------------------------------------------------------

function RezSlot(id, attributes) {
  this.id = id;
  this.game_object_type = "slot";
  this.attributes = attributes;
  this.properties_to_archive = [];
  this.changed_attributes = [];
}

RezSlot.prototype = {
  __proto__: basic_object,
  constructor: RezSlot,

  get has_capacity() {
    return this.getAttribute("capacity") !== undefined;
  },
};

window.Rez.RezSlot = RezSlot;
