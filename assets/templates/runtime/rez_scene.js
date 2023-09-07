//-----------------------------------------------------------------------------
// Scene
//-----------------------------------------------------------------------------

let scene_proto = {
  __proto__: basic_object,
  targetType: "scene",

  get viewTemplate() {
    return this.$layout_template;
  },

  getCurrentCard() {
    return this.game.$(this.current_card_id);
  },

  getInitialCard() {
    return this.game.$(this.initial_card);
  },

  finish() {
    this.runEvent("finish", {});
  },

  finishCurrentCard() {
    if (this.current_card_id != null) {
      const card = this.getCurrentCard();
      if (card) {
        card.runEvent("finish", { scene: this.id });
        this.runEvent("finish_card", { card: card.id });
      }
    }
  },

  startNewCard() {
    const card = this.getCurrentCard();
    if (card) {
      card.scene = this;

      this.runEvent("start_card", { card: card.id });
      card.runEvent("start", { scene: this.id });

      const block = new RezBlock(card);
      this.getViewLayout().addContent(block);
    }
  },

  handleCustomEvent(event_name, evt) {
    const handler = this.eventHandler(event_name);
    if (handler && typeof handler == "function") {
      return handler(this, evt);
    } else {
      return this.getCurrentCard().handleCustomEvent(event_name, evt);
    }
  },

  playCardWithId(new_card_id) {
    // Obviously if you try to set no card we should blow up
    if (new_card_id == null) {
      throw "Cannot specify null card_id!";
    }

    this.finishCurrentCard();

    this.current_card_id = new_card_id;
    this.startNewCard();

    this.game.updateView();
    this.getCurrentCard().runEvent("ready", {});
  },

  getCard(card_id) {
    const card = this.$(card_id);
    if (card.game_object_type != "card") {
      throw "Attempt to get id which does not correspond to a card";
    }
    return card;
  },

  createViewLayout() {
    if (this.layout_mode == "stack") {
      return new RezStackLayout(this);
    } else {
      return new RezSingleLayout(this);
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
    this.playCardWithId(this.getAttribute("initial_card"));
  },
};

function RezScene(id, attributes) {
  this.id = id;
  this.game_object_type = "scene";
  this.attributes = attributes;
  this.properties_to_archive = [
    "current_card_id",
    "current_render",
    "cards_played",
  ];
  this.changed_attributes = [];
  this.reset();
}

RezScene.prototype = scene_proto;
RezScene.prototype.constructor = RezScene;
window.Rez.Scene = RezScene;
