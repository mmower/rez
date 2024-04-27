//-----------------------------------------------------------------------------
// Effect
//-----------------------------------------------------------------------------

function RezEffect(id, attributes) {
  this.id = id;
  this.game_object_type = "effect";
  this.attributes = attributes;
  this.properties_to_archive = [];
  this.changed_attributes = [];
}

RezEffect.prototype = {
  __proto__: basic_object,
  constructor: RezEffect,

  apply(owner_id, slot_id, item_id) {
    return this.runEvent("apply", {owner_id: owner_id, slot_id: slot_id, item_id: item_id});
  },

  remove(owner_id, slot_id, item_id) {
    return this.runEvent("remove", {owner_id: owner_id, slot_id: slot_id, item_id: item_id});
  }
};
