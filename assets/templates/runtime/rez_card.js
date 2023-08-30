//-----------------------------------------------------------------------------
// Card
//-----------------------------------------------------------------------------

let card_proto = {
  __proto__: basic_object,
  targetType: "card",

  get viewTemplate() {
    return this.$content_template;
  },

  handleCustomEvent(event_name, evt) {
    const handler = this.eventHandler(event_name);
    if (handler && typeof handler == "function") {
      return handler(this, evt);
    } else {
      console.log("No handler for custom event");
    }
  },
};

function RezCard(id, attributes) {
  this.id = id;
  this.game_object_type = "card";
  this.attributes = attributes;
  this.render_id = 0;
  this.properties_to_archive = [];
  this.changed_attributes = [];
}

RezCard.prototype = card_proto;
RezCard.prototype.constructor = RezCard;
window.Rez.Card = RezCard;
