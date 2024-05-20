//-----------------------------------------------------------------------------
// Event Handling SubSystem
//-----------------------------------------------------------------------------

function RezEvent() {
}

RezEvent.prototype = {
  constructor: RezEvent,

  params: {},

  setParam(name, value ) {
    this.params[name] = value;
    return this;
  },

  setParams(params) {
    this.params = params;
    return this;
  },

  flash_messages: [],

  card_id: null,

  scene_change_event: false,
  scene_interlude_event: false,
  scene_id: null,

  scene_resume_event: false,

  render_event: false,

  error_message: null,

  get hashFlash() {
    return this.flash_messages.length > 0;
  },

  flash(message) {
    this.flash_messages.push(message);
    return this;
  },

  get shouldPlayCard() {
    return this.card_id != null;
  },

  playCard(card_id) {
    this.card_id = card_id;
    return this;
  },

  get shouldRender() {
    return this.render_event;
  },

  render() {
    this.render_event = true;
    return this;
  },

  get shouldChangeScene() {
    return this.scene_change_event;
  },

  sceneChange(scene_id) {
    this.scene_change_event = true;
    this.scene_id = scene_id;
    return this;
  },

  get shouldInterludeScene() {
    return this.scene_interlude_event;
  },

  sceneInterlude(scene_id) {
    this.scene_interlude_event = true;
    this.scene_id = scene_id;
    return this;
  },

  get shouldResumeScene() {
    return this.scene_resume_event;
  },

  sceneResume() {
    this.scene_resume_event = true;
    return this;
  },

  get isError() {
    return this.error_message != null;
  },

  error(message) {
    this.error_message = message;
    return this;
  },

  noop() {
    return this;
  }
}

RezEvent.built_in = function() {
  return new RezEvent().noop();
}

RezEvent.flash = function(message) {
  return new RezEvent().flash(message);
}

RezEvent.playCard = function(card_id) {
  return new RezEvent().playCard(card_id);
}

RezEvent.render = function() {
  return new RezEvent().render();
}

RezEvent.sceneChange = function(scene_id) {
  return new RezEvent().sceneChange(scene_id);
}

RezEvent.sceneInterlude = function(scene_id) {
  return new RezEvent().sceneInterlude(scene_id);
}

RezEvent.sceneResume = function() {
  return new RezEvent().sceneResume();
}

RezEvent.noop = function() {
  return new RezEvent().noop();
}

RezEvent.error = function(message) {
  return new RezEvent().error(message);
}

window.Rez.RezEvent = RezEvent;

function RezEventProcessor(game) {
  this.game = game;
}

RezEventProcessor.prototype = {
  constructor: RezEventProcessor,

  get scene() {
    return this.game.current_scene;
  },

  get card() {
    return this.scene.current_card;
  },

  dispatchResponse(response) {
    if(response instanceof RezEvent) {
      if (response.hasFlash) {
        for(message of response.flash_messages) {
          this.game.addFlashMessage(message);
        }
      }

      if(response.shouldChangeScene) {
        this.game.startSceneWithId(response.scene_id, response.params);
      } else if(response.shouldInterludeScene) {
        this.game.interludeSceneWithId(response.scene_id, response.params);
      } else if(response.shouldResumeScene) {
        this.game.resumePrevScene();
      }

      if(response.shouldPlayCard) {
        this.scene.playCardWithId(response.card_id, response.params);
      }

      if (response.shouldRender) {
        this.game.updateView();
      }

      if (response.isError) {
        console.log(`Error: ${response.error_message}`);
      }
    } else {
      throw "Event handlers must return a RezEvent object!";
    }
  },

  beforeEventProcessing(evt) {
    const systems = this.game.getEnabledSystems();

    return systems.reduce((i_evt, system) => {
      const handler = system.before_event;
      const h_evt = handler ? handler(system, i_evt) : i_evt;
      if(typeof(h_evt) === "undefined") {
        throw `before_event handler of system |${system.id}| has not returned a valid evt object!`;
      }
      return h_evt;
    }, evt);
  },

  afterEventProcessing(evt, result) {
    const systems = this.game.getEnabledSystems();

    return systems.reduce((i_result, system) => {
      const handler = system.after_event;
      const h_result = handler ? handler(system, evt, i_result) : i_result;
      if(typeof(h_result) === "undefined") {
        throw `after_event handler of system |${system.id}| has not returned a valid result object!`;
      }
      return h_result;
    }, result);
  },

  raiseTimerEvent(timer) {
    const evt = new CustomEvent('timer', {detail: {timer: timer}});
    return this.handleBrowserEvent(evt);
  },

  raiseKeyBindingEvent(event_name) {
    const evt = new CustomEvent("key_binding", {detail: {event_name: event_name}});
    return this.handleBrowserEvent(evt);
  },

  handleBrowserEvent(evt) {
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
  },

  decodeEvent(evt) {
    const { event, target, ...params } = evt.target.dataset;
    return [event.toLowerCase(), target, params];
  },

  handleTimerEvent(evt) {
    const timer = evt.detail.timer;
    const result = this.handleCustomEvent(timer.event, {timer: timer.id});
    if(!typeof(result) === "object") {
      return {handled: true}
    } else {
      return result;
    }
  },

  handleKeyBindingEvent(evt) {
    const result = this.handleCustomEvent(evt.detail.event_name, {});
    if(!typeof(result) === "object") {
      return {handled: true}
    } else {
      return result;
    }
  },

  handleBrowserClickEvent(evt) {
    const [event_name, target, params] = this.decodeEvent(evt);

    if(typeof(event_name) === "undefined") {
      console.log("Received click event without an event name!");
      return false;
    }

    if (event_name === "card") {
      return this.handleCardEvent(target, params);
    } else if (event_name === "switch") {
      return this.handleSwitchEvent(target, params);
    } else if (event_name === "interlude") {
      return this.handleInterludeEvent(target, params);
    } else if (event_name === "resume") {
      return this.handleResumeEvent(params);
    } else {
      return this.handleCustomEvent(event_name, params);
    }
  },

  getReceiverEventHandler(receiver, event_name) {
    let handler = receiver.eventHandler(event_name);
    if(handler && typeof(handler) === "function") {
      return handler;
    } else {
      return null;
    }
  },

  getEventHandler(event_name) {
    const receivers = [this.card, this.scene, this.game];
    const handlers = receivers.map((receiver) => [receiver, this.getReceiverEventHandler(receiver, event_name)]);
    return handlers.find(([receiver, handler]) => handler) ?? [null, null];
  },

  handleCustomEvent(event_name, params) {
    const [receiver, handler] = this.getEventHandler(event_name);
    if(!handler) {
      return RezEvent.error(`Unable to find an event handler for |${event_name}|`);
    } else {
      console.log(`Routing event |${event_name}| to |${receiver.id}|`);
      return handler(receiver, params);
    }
  },

  handleCardEvent(target, params) {
    console.log(`Handle card event: |${target}|`);
    return RezEvent.playCard(target).setParams(params);
  },

  handleSwitchEvent(target, params) {
    console.log(`Handle switch event: |${target}|`);
    return RezEvent.sceneChange(target).setParams(params);
  },

  handleInterludeEvent(target, params) {
    console.log(`Handle interlude event: |${target}|`);
    return RezEvent.sceneInterlude(target).setParams(params);
  },

  handleResumeEvent(params) {
    console.log("Handle resume event");
    return RezEvent.sceneResume().setParams(params);
  },

  handleBrowserInputEvent(evt) {
    console.log("Handle input event");
    const card_div = evt.target.closest("div.card");
    if (!card_div) {
      throw "Cannot find div for input " + evt.target.id + "!";
    }

    const card_id = card_div.dataset.card;
    if (!card_id) {
      throw "Cannot get card id for input" + evt.target.id + "!";
    }

    const card = $(card_id);
    return card.runEvent("input", { evt: evt });
  },

  handleBrowserSubmitEvent(evt) {
    console.log("Handle submit event");

    const form_name = evt.target.getAttribute("name");
    if (!form_name) {
      throw "Cannot get form name!";
    }

    const card_div = evt.target.closest("div.card");
    if (!card_div) {
      throw "Cannot find div for form: " + form_name + "!";
    }

    const card_id = card_div.dataset.card;
    const card = $(card_id);

    return card.runEvent(form_name, { form: evt.target });
  },

};

window.Rez.RezEventProcessor = RezEventProcessor;
