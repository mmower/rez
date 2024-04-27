//-----------------------------------------------------------------------------
// Card
//-----------------------------------------------------------------------------

function RezCard(id, attributes) {
  this.id = id;
  this.game_object_type = "card";
  this.current_block = null;
  this.attributes = attributes;
  this.properties_to_archive = [];
  this.changed_attributes = [];
}

RezCard.prototype = {
  __proto__: basic_object,
  constructor: RezCard,

  targetType: "card",

  bindAs() {
    return "card";
  },

  getViewTemplate(flipped) {
    if(flipped) {
      if (!this.$flipped_template) {
        throw `Card |${this.id}| was asked for its flipped_template but doesn't define one!`;
      }
      return this.$flipped_template;

    } else {
      return this.$content_template;
    }
  },

  handleCustomEvent(event_name, evt) {
    const handler = this.eventHandler(event_name);
    if (handler && typeof handler == "function") {
      return handler(this, evt);
    } else {
      return {
        error: `No handler for event ${event_name}. Did you use an on_xxx prefix?`,
      };
    }
  },
};
