//-----------------------------------------------------------------------------
// Card
//-----------------------------------------------------------------------------

class RezCard extends RezBasicObject {
  #scene;
  #current_block;

  constructor(id, attributes) {
    super("card", id, attributes);
    this.#current_block = null;
    this.#scene = null;
  }

  get current_block() {
    return this.#current_block;
  }

  set current_block(block) {
    this.#current_block = block;
  }

  // Transient reference set by the scene via startNewCard().
  // Valid for the card's lifecycle within that scene. In single layout mode the
  // reference becomes stale when the card is replaced. In stack layout mode the
  // reference persists as long as the scene is running.
  get scene() {
    return this.#scene;
  }

  set scene(scene) {
    this.#scene = scene;
  }

  bindAs() {
    return "card";
  }

  getViewTemplate(flipped) {
    if (arguments.length === 0) {
      flipped = this.$flipped;
    }

    const template = flipped
      ? (this.$flipped_template || this.$content_template)
      : this.$content_template;

    if (!template) {
      throw new Error(`Card |${this.id}| has no content template!`);
    }

    return template;
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
