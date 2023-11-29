//-----------------------------------------------------------------------------
// Card
//-----------------------------------------------------------------------------

let card_proto = {
  __proto__: basic_object,
  targetType: "card",

  // Return the compiled template function that returns content for this card to the current view.
  get viewTemplate() {
    if (this.$flipped) {
      if (!this.$flipped_template) {
        throw (
          "Card |" +
          this.id +
          "| was asked for its flipped content template but does not define one."
        );
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

function RezCard(id, attributes) {
  this.id = id;
  this.auto_id_idx = 0;
  this.game_object_type = "card";
  this.attributes = attributes;
  this.render_id = 0;
  this.properties_to_archive = [];
  this.changed_attributes = [];
}

RezCard.prototype = card_proto;
RezCard.prototype.constructor = RezCard;
window.Rez.Card = RezCard;
