//-----------------------------------------------------------------------------
// Scene
//-----------------------------------------------------------------------------

let scene_proto = {
  __proto__: basic_object,
  targetType: "scene",

  get viewTemplate() {
    return this.$layout_template;
  },

  get currentCard() {
    this.current_card = this.current_card ?? $(this.current_card_id);
    return this.current_card;
  },

  get currentCardId() {
    return this.current_card_id;
  },

  get isStackLayout() {
    return this.layout_mode == "stack";
  },

  getInitialCard() {
    return this.game.$(this.initial_card);
  },

  finishCurrentCard() {
    if (this.current_card) {
      this.current_card.runEvent("finish", {});
      this.runEvent("finish_card", {});
      if (this.isStackLayout) {
        this.current_card.$flipped = true;
      }
    }
  },

  startNewCard(card) {
    card.scene = this;
    this.current_card = card;
    this.runEvent("start_card", {});
    card.runEvent("start", {});
    const block = new RezBlock("card", card);
    this.getViewLayout().addContent(block);
    if (this.isStackLayout) {
      this.cards_played.push(card);
    }
  },

  handleCustomEvent(event_name, evt) {
    const handler = this.eventHandler(event_name);
    if (handler && typeof handler == "function") {
      return handler(this, evt);
    } else {
      return this.currentCard.handleCustomEvent(event_name, evt);
    }
  },

  playCardWithId(new_card_id, params = {}) {
    // Obviously if you try to set no card we should blow up
    if (new_card_id == null) {
      throw "Cannot specify null card_id!";
    }

    this.finishCurrentCard();

    const card_template = $(new_card_id);
    const card = card_template.copyWithAutoId();

    Object.entries(params).forEach(([key, value]) => {
      card[key] = value;
    });

    this.startNewCard(card);

    this.game.updateView();
    this.currentCard.runEvent("ready", {});
  },

  createViewLayout() {
    if (this.isStackLayout) {
      return new RezStackLayout("scene", this);
    } else {
      return new RezSingleLayout("scene", this);
    }
  },

  getViewLayout() {
    this.$viewLayout = this.$viewLayout ?? this.createViewLayout();
    return this.$viewLayout;
  },

  reset() {
    this.cards_played = [];
    this.current_card_id = null;
    this.current_render = null;
  },

  interrupt() {
    console.log("Interrupting " + this.id);
    this.runEvent("interrupt", {});
  },

  resume() {
    console.log("Resuming " + this.id);
    this.runEvent("resume", {});
  },

  start() {
    this.reset();
    this.init();
    this.runEvent("start", {});
    this.playCardWithId(this.initial_card_id);
  },

  ready() {
    this.runEvent("ready", {});
  },

  finish() {
    this.runEvent("finish", {});
  },
};

function RezScene(id, attributes) {
  this.id = id;
  this.auto_id_idx = 0;
  this.game_object_type = "scene";
  this.attributes = attributes;
  this.properties_to_archive = ["current_card_id", "cards_played"];
  this.changed_attributes = [];
  this.reset();
}

RezScene.prototype = scene_proto;
RezScene.prototype.constructor = RezScene;
window.Rez.Scene = RezScene;
