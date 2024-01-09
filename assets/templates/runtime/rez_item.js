/**
 * Creates a new object with RezItem as its prototype.
 */
function RezItem(id, attributes) {
  this.id = id;
  this.auto_id_idx = 0;
  this.game_object_type = "item";
  this.attributes = attributes;
  this.properties_to_archive = ["auto_id_idx"];
  this.changed_attributes = [];
}

RezItem.prototype = {
  __proto__: basic_object,
  constructor: RezItem,

  get template() {
    return this.getAttribute("description_template");
  },

  size() {
    return this.getAttributeValue("size");
  },
};

window.RezItem = RezItem;
