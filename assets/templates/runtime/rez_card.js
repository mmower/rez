//-----------------------------------------------------------------------------
// Card
//-----------------------------------------------------------------------------

class RezCard extends RezBasicObject {
  #currentBlock;

  constructor(id, attributes) {
    super("card", id, attributes);
    this.#currentBlock = null;
  }

  get currentBlock() {
    return this.#currentBlock;
  }

  set currentBlock(block) {
    this.#currentBlock = block;
  }

  targetType = "card";

  bindAs() {
    return "card";
  }

  getViewTemplate(flipped) {
    return flipped ? (this.$flipped_template || this.$content_template) : this.$content_template;
  }

  handleCustomEvent(event_name, evt) {
    const handler = this.eventHandler(event_name);
    if(handler && typeof handler == "function") {
      return handler(this, evt);
    } else {
      return {
        error: `No handler for event ${event_name}. Did you use an on_xxx prefix?`,
      };
    }
  }
}

window.Rez.RezCard = RezCard;
