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
    if(flipped) {
      if (!this.$flipped_template) {
        throw new Error(`Card |${this.id}| was asked for its flipped_template but doesn't define one!`);
      }
      return this.$flipped_template;
    } else {
      return this.$content_template;
    }
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
