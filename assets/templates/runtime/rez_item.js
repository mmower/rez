//-----------------------------------------------------------------------------
// Item
//-----------------------------------------------------------------------------

let item_proto = {
  __proto__: basic_object,

  get template() {
    return this.getAttribute("description_template");
  },

  size() {
    return this.getAttributeValue("size");
  },
};

function RezItem(id, attributes) {
  this.id = id;
  this.auto_id_idx = 0;
  this.game_object_type = "item";
  this.attributes = attributes;
  this.properties_to_archive = ["auto_id_idx"];
  this.changed_attributes = [];
}

RezItem.prototype = item_proto;
RezItem.prototype.constructor = RezItem;
window.Rez.Item = RezItem;
