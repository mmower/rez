//-----------------------------------------------------------------------------
// Effect
//-----------------------------------------------------------------------------

/**
 * @namespace effect_proto
 */
let effect_proto = {
  __proto__: basic_object,

  apply(owner_id, slot_id, item_id) {
    this.runEvent("apply", {owner_id: owner_id, slot_id: slot_id, item_id: item_id});

  },

  remove(owner_id, slot_id, item_id) {
    this.runEvent("remove", {owner_id: owner_id, slot_id: slot_id, item_id: item_id});
  }
};

function RezEffect(id, attributes) {
  this.id = id;
  this.game_object_type = "effect";
  this.attributes = attributes;
  this.properties_to_archive = [];
  this.changed_attributes = [];
}

RezEffect.prototype = effect_proto;
RezEffect.prototype.constructor = RezEffect;
window.Rez.Effect = RezEffect;
