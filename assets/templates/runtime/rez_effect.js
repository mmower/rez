//-----------------------------------------------------------------------------
// Effect
//-----------------------------------------------------------------------------

let effect_proto = {
  __proto__: basic_object
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
