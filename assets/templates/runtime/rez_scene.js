//-----------------------------------------------------------------------------
// Scene
//-----------------------------------------------------------------------------

class RezScene extends RezBasicObject {
  constructor(id, attributes) {
    super("scene", id, attributes);
    this.reset();
  }

  targetType = "scene";

  get isStackLayout() {
    return this.layout_mode === "stack";
  }

  get current_block() {
    return this.getViewLayout()
  }

  bindAs() {
    return "scene";
  }

  getViewTemplate(flipped) {
    // Scenes can't be flipped, only cards
    return this.$layout_template;
  }

  getViewLayout() {
    this.$viewLayout = this.$viewLayout ?? this.createViewLayout();
    return this.$viewLayout;
  }

  createViewLayout() {
    if(this.isStackLayout) {
      return new RezStackLayout("scene", this);
    } else {
      return new RezSingleLayout("scene", this);
    }
  }

  playCardWithId(cardId, params = {}) {
    this.playCard($t(cardId, "card", true), params);
  }

  playCard(newCard, params = {}) {
    this.finishCurrentCard();

    this.startNewCard(newCard, params);
    this.game.updateView();
    this.current_card.runEvent("ready", {});
  }

  finishCurrentCard() {
    if(this.current_card) {
      this.current_card.runEvent("finish", {});
      this.runEvent("finish_card", {});
      if(this.isStackLayout) {
        this.current_card.current_block.flipped = true;
      }
      this.last_card_id = this.current_card_id;
      this.current_card_id = "";
    }
  }

  startNewCard(card, params = {}) {
    card.scene = this;
    this.current_card = card;

    this.addContentToViewLayout(params);

    this.runEvent("start_card", {});
    card.runEvent("start", {});
  }

  resumeFromLoad() {
    if(!(this.current_card instanceof RezCard)) {
      throw new Error("Attempting to resume scene after reload but there is no current card!");
    }

    this.addContentToViewLayout({});
  }

  addContentToViewLayout(params = {}) {
    const block = new RezBlock("card", this.current_card, params);
    this.current_card.current_block = block;
    this.getViewLayout().addContent(block);
  }

  reset() {
    this.current_card_id = "";
    this.$viewLayout = null;
    this.$running = false;
  }

  interrupt() {
    console.log(`Interrupting scene |${this.id}|`);
    this.runEvent("interrupt", {});
  }

  resume(params = {}) {
    console.log(`Resuming scene |${this.id}|`);
    this.runEvent("resume", params);
  }

  start(params = {}) {
    this.init();
    this.runEvent("start", params);
    this.$running = true;
    this.playCard(this.initial_card, params);
  }

  ready() {
    this.runEvent("ready", {});
  }

  finish() {
    this.finishCurrentCard();
    this.runEvent("finish", {});
    this.$running = false;
    this.reset();
  }
}

window.Rez.RezScene = RezScene;
