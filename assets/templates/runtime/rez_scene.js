//-----------------------------------------------------------------------------
// Scene
//-----------------------------------------------------------------------------

function RezScene(id, attributes) {
  this.id = id;
  this.auto_id_idx = 0;
  this.game_object_type = "scene";
  this.attributes = attributes;
  this.properties_to_archive = [];
  this.changed_attributes = [];
  this.reset();
}

RezScene.prototype = {
  __proto__: basic_object,
  constructor: RezScene,

  get isStackLayout() {
    return this.layout_mode === "stack";
  },

  get current_block() {
    return this.getViewLayout()
  },

  targetType: "scene",

  bindAs() {
    return "scene";
  },

  getViewTemplate(flipped) {
    return this.$layout_template;
  },

  getViewLayout() {
    this.$viewLayout = this.$viewLayout ?? this.createViewLayout();
    return this.$viewLayout;
  },

  createViewLayout() {
    if (this.isStackLayout) {
      return new RezStackLayout("scene", this);
    } else {
      return new RezSingleLayout("scene", this);
    }
  },

  playCardWithId(card_id, params = {}) {
    this.playCard($(card_id), params);
  },

  playCard(new_card, params = {}) {
    this.finishCurrentCard();

    this.startNewCard(new_card, params);
    this.game.updateView();
    this.current_card.runEvent("ready", {});
  },

  finishCurrentCard() {
    console.log("> finishCurrentCard");
    if (this.current_card) {
      this.current_card.runEvent("finish", {});
      this.runEvent("finish_card", {});
      if (this.isStackLayout) {
        this.current_card.current_block.flipped = true;
      }
      this.current_card_id = "";
    }
  },

  startNewCard(card, params = {}) {
    card.scene = this;
    this.current_card = card;

    this.runEvent("start_card", {});
    card.runEvent("start", {});
    const block = new RezBlock("card", card, params);
    card.current_block = block;
    this.getViewLayout().addContent(block);
  },

  reset() {
    this.current_card_id = "";
    this.$viewLayout = null;
  },

  interrupt() {
    console.log(`Interrupting scene |${this.id}|`);
    this.runEvent("interrupt", {});
  },

  resume(params = {}) {
    console.log(`Resuming scene |${this.id}|`);
    this.runEvent("resume", params);
  },

  start() {
    this.init();
    this.runEvent("start", {});
    this.playCard(this.initial_card);
  },

  ready() {
    this.runEvent("ready", {});
  },

  finish() {
    this.finishCurrentCard();
    this.runEvent("finish", {});
    this.reset();
  },
};

window.RezScene = RezScene;
