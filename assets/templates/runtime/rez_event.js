//-----------------------------------------------------------------------------
// Event Handling SubSystem
//-----------------------------------------------------------------------------

class RezEvent {
  #params;
  #flashMessages;
  #cardId;
  #sceneId;
  #sceneChangeEvent;
  #sceneInterludeEvent;
  #sceneResumeEvent;
  #renderEvent;
  #errorMessage;

  constructor() {
    this.#params = {};
    this.#flashMessages = [];
    this.#cardId = null;
    this.#sceneId = null;
    this.#sceneChangeEvent = false;
    this.#sceneInterludeEvent = false;
    this.#sceneResumeEvent = false;
    this.#renderEvent = false;
    this.#errorMessage = null;
  }

  get params() {
    return this.#params;
  }

  get flashMessages() {
    return this.#flashMessages;
  }

  get cardId() {
    return this.#cardId;
  }

  get sceneId() {
    return this.#sceneId;
  }

  get sceneChangeEvent() {
    return this.#sceneChangeEvent;
  }

  get sceneInterludeEvent() {
    return this.#sceneInterludeEvent;
  }

  get sceneResumeEvent() {
    return this.#sceneResumeEvent;
  }

  get renderEvent() {
    return this.#renderEvent;
  }

  get errorMessage() {
    return this.#errorMessage;
  }

  setParam(name, value ) {
    this.#params[name] = value;
    return this;
  }

  setParams(params) {
    this.#params = params;
    return this;
  }

  get hasFlash() {
    return this.#flashMessages.length > 0;
  }

  flash(message) {
    this.#flashMessages.push(message);
    return this;
  }

  get shouldPlayCard() {
    return this.#cardId != null;
  }

  playCard(cardId) {
    this.#cardId = cardId;
    return this;
  }

  get shouldRender() {
    return this.#renderEvent;
  }

  render() {
    this.#renderEvent = true;
    return this;
  }

  get shouldChangeScene() {
    return this.#sceneChangeEvent;
  }

  sceneChange(sceneId) {
    this.#sceneChangeEvent = true;
    this.#sceneId = sceneId;
    return this;
  }

  get shouldInterludeScene() {
    return this.#sceneInterludeEvent;
  }

  sceneInterlude(sceneId) {
    this.#sceneInterludeEvent = true;
    this.#sceneId = sceneId;
    return this;
  }

  get shouldResumeScene() {
    return this.#sceneResumeEvent;
  }

  sceneResume() {
    this.#sceneResumeEvent = true;
    return this;
  }

  get isError() {
    return this.#errorMessage != null;
  }

  error(message) {
    this.#errorMessage = message;
    return this;
  }

  noop() {
    return this;
  }

  static built_in() {
    return new RezEvent();
  }

  static flash(message) {
    return new RezEvent().flash(message);
  }

  static playCard(cardId) {
    return new RezEvent().playCard(cardId);
  }

  static render() {
    return new RezEvent().render();
  }

  static setParam(param, value) {
    return new RezEvent().setParam(param, value);
  }

  static sceneChange(sceneId) {
    return new RezEvent().sceneChange(sceneId);
  }

  static sceneInterlude(sceneId) {
    return new RezEvent().sceneInterlude(sceneId);
  }

  static sceneResume() {
    return new RezEvent().sceneResume();
  }

  static noop() {
    return new RezEvent();
  }

  static error(message) {
    return new RezEvent().error(message);
  }
}

window.Rez.RezEvent = RezEvent;

class RezEventProcessor {
  #game;

  constructor(game) {
    this.#game = game;
  }

  get game() {
    return this.#game;
  }

  get scene() {
    return this.#game.current_scene;
  }

  get card() {
    return this.#game.current_scene.current_card;
  }

  dispatchResponse(response) {
    if(response instanceof RezEvent) {
      if(response.hasFlash) {
        for(let message of response.flashMessages) {
          this.game.addFlashMessage(message);
        }
      }

      if(response.shouldChangeScene) {
        this.game.startSceneWithId(response.sceneId, response.params);
      } else if(response.shouldInterludeScene) {
        this.game.interludeSceneWithId(response.sceneId, response.params);
      } else if(response.shouldResumeScene) {
        this.game.resumePrevScene();
      }

      if(response.shouldPlayCard) {
        this.scene.playCardWithId(response.cardId, response.params);
      }

      if(response.shouldRender) {
        this.game.updateView();
      }

      if(response.isError) {
        console.log(`Error: ${response.errorMessage}`);
      }
    } else {
      throw new Error("Event handlers must return a RezEvent object!");
    }
  }

  beforeEventProcessing(evt) {
    const systems = this.game.getEnabledSystems();

    return systems.reduce((eventInProgress, system) => {
      const handler = system.before_event;
      const handledEvent = handler ? handler(system, eventInProgress) : eventInProgress;
      if(typeof(handledEvent) === "undefined") {
        throw new Error(`before_event handler of system |${system.id}| has not returned a valid evt object!`);
      }
      return handledEvent;
    }, evt);
  }

  afterEventProcessing(evt, result) {
    const systems = this.game.getEnabledSystems();

    return systems.reduce((intermediateResult, system) => {
      const handler = system.after_event;
      const handledResult = handler ? handler(system, evt, intermediateResult) : intermediateResult;
      if(typeof(handledResult) === "undefined") {
        throw new Error(`after_event handler of system |${system.id}| has not returned a valid result object!`);
      }
      return handledResult;
    }, result);
  }

  raiseTimerEvent(timer) {
    const evt = new CustomEvent('timer', {detail: {timer: timer}});
    return this.handleBrowserEvent(evt);
  }

  raiseKeyBindingEvent(event_name) {
    const evt = new CustomEvent("key_binding", {detail: {event_name: event_name}});
    return this.handleBrowserEvent(evt);
  }

  isAutoUndoEvent(evt) {
    const evtTypes = ["click", "input", "submit", "key_binding"];
    return evtTypes.includes(evt.type);
  }

  handleBrowserEvent(evt) {
    console.log("HandleBrowserEvent");

    if(this.isAutoUndoEvent(evt)) {
      this.game.undoManager.startChange();
      this.game.undoManager.recordViewChange(this.game.view.copy());
    }

    evt = this.beforeEventProcessing(evt);

    let result;

    if (evt.type === "click") {
      result = this.handleBrowserClickEvent(evt);
    } else if (evt.type === "input") {
      result = this.handleBrowserInputEvent(evt);
    } else if (evt.type === "submit") {
      result = this.handleBrowserSubmitEvent(evt);
    } else if(evt.type === "timer") {
      result = this.handleTimerEvent(evt);
    } else if(evt.type === "key_binding") {
      result = this.handleKeyBindingEvent(evt);
    } else {
      result = {unhandled: true};
    }

    return this.afterEventProcessing(evt, result);
  }

  decodeEvent(evt) {
    const { event, target, ...params } = evt.currentTarget.dataset;
    return [event.toLowerCase(), target, params];
  }

  handleTimerEvent(evt) {
    const timer = evt.detail.timer;
    const result = this.handleCustomEvent(timer.event, {timer: timer.id});
    if(!typeof(result) === "object") {
      return {handled: true}
    } else {
      return result;
    }
  }

  handleKeyBindingEvent(evt) {
    const result = this.handleCustomEvent(evt.detail.event_name, {});
    if(!typeof(result) === "object") {
      return {handled: true}
    } else {
      return result;
    }
  }

  handleBrowserClickEvent(evt) {
    const [eventName, target, params] = this.decodeEvent(evt);

    if(typeof(eventName) === "undefined") {
      console.log("Received click event without an event name!");
      return false;
    }

    if (eventName === "card") {
      return this.handleCardEvent(target, params);
    } else if (eventName === "switch") {
      return this.handleSwitchEvent(target, params);
    } else if (eventName === "interlude") {
      return this.handleInterludeEvent(target, params);
    } else if (eventName === "resume") {
      return this.handleResumeEvent(params);
    } else {
      return this.handleCustomEvent(eventName, params);
    }
  }

  getReceiverEventHandler(receiver, eventname) {
    let handler = receiver.eventHandler(eventname);
    if(handler && typeof(handler) === "function") {
      return handler;
    } else {
      return null;
    }
  }

  getEventHandler(eventName) {
    const receivers = [this.card, this.scene, this.game];
    const handlers = receivers.map((receiver) => [receiver, this.getReceiverEventHandler(receiver, eventName)]);
    return handlers.find(([receiver, handler]) => handler) ?? [null, null];
  }

  handleCustomEvent(eventName, params) {
    const [receiver, handler] = this.getEventHandler(eventName);
    if(!handler) {
      return RezEvent.error(`Unable to find an event handler for |${eventName}|`);
    } else {
      console.log(`Routing event |${eventName}| to |${receiver.id}|`);
      return handler(receiver, params);
    }
  }

  handleCardEvent(target, params) {
    console.log(`Handle card event: |${target}|`);
    return RezEvent.playCard(target).setParams(params);
  }

  handleSwitchEvent(target, params) {
    console.log(`Handle switch event: |${target}|`);
    return RezEvent.sceneChange(target).setParams(params);
  }

  handleInterludeEvent(target, params) {
    console.log(`Handle interlude event: |${target}|`);
    return RezEvent.sceneInterlude(target).setParams(params);
  }

  handleResumeEvent(params) {
    console.log("Handle resume event");
    return RezEvent.sceneResume().setParams(params);
  }

  handleBrowserInputEvent(evt) {
    console.log("Handle input event");
    const card_div = evt.target.closest("div.rez-active-card div[data-card]");
    if(!card_div) {
      throw new Error(`Cannot find div for input |${evt.target.id}|`);
    }

    const cardId = card_div.dataset.card;
    if(!cardId) {
      throw new Error(`Cannot get card id for input |${evt.target.id}|`);
    }

    const card = $(cardId);
    return card.runEvent("input", { evt: evt }) || RezEvent.noop();
  }

  handleBrowserSubmitEvent(evt) {
    console.log("Handle submit event");

    const formName = evt.target.getAttribute("name");
    if (!formName) {
      throw new Error("Cannot get form name!");
    }

    const cardDiv = evt.target.closest("div.rez-active-card div[data-card]");
    if (!cardDiv) {
      throw new Error(`Cannot find div for form: |${formName}|`);
    }

    const cardId = cardDiv.dataset.card;
    const card = $(cardId);

    return card.runEvent(formName, { form: evt.target }) || RezEvent.noop();
  }
}

window.Rez.RezEventProcessor = RezEventProcessor;
