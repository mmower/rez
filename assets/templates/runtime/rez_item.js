/**
 * Creates a new object with RezItem as its prototype.
 */
function RezItem(id, attributes) {
  this.id = id;
  this.game_object_type = "item";
  this.attributes = attributes;
  this.properties_to_archive = [];
  this.changed_attributes = [];
}

RezItem.prototype = {
  __proto__: basic_object,
  constructor: RezItem,
};

window.Rez.RezItem = RezItem;
