//-----------------------------------------------------------------------------
// Event Handling SubSystem
//-----------------------------------------------------------------------------

const event_processor_proto = {
  get scene() {
    return this.game.current_scene;
  },

  get card() {
    return this.scene.current_card;
  },

  dispatchResponse(response) {
    if (typeof response == "object") {
      if (response.flash) {
        this.game.addFlashMessage(response.flash);
      }

      if (response.scene) {
        this.game.startSceneWithId(response.scene, response.params ?? {});
      }

      if(response.interlude) {
        this.game.interludeSceneWithId(response.interlude, response.params ?? {});
      }

      if (response.card) {
        this.scene.playCardWithId(response.card, response.params ?? {});
      }

      if (response.render) {
        this.game.updateView();
      }

      if (response.error) {
        console.log(`Error: ${response.error}`);
      }
    } else if (typeof response == "undefined") {
      throw "Event handlers must return an object with at least one key from: [scene, card, flash, render, error, nop]!";
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

  handleBrowserEvent(evt) {
    evt = this.beforeEventProcessing(evt);

    let result;

    if (evt.type == "click") {
      result = this.handleBrowserClickEvent(evt);
    } else if (evt.type == "input") {
      result = this.handleBrowserInputEvent(evt);
    } else if (evt.type == "submit") {
      result = this.handleBrowserSubmitEvent(evt);
    } else {
      result = {unhandled: true};
    }

    return this.afterEventProcessing(evt, result);
  },

  decodeEvent(evt) {
    const { event, target, ...params } = evt.target.dataset;
    return [event.toLowerCase(), target, params];
  },

  handleBrowserClickEvent(evt) {
    const [event_name, target, params] = this.decodeEvent(evt);

    if(typeof(event_name) == "undefined") {
      console.log("Received click event without an event name!");
      return false;
    }

    if (event_name == "card") {
      return this.handleCardEvent(target, params);
    } else if (event_name == "switch") {
      return this.handleSwitchEvent(target, params);
    } else if (event_name == "interlude") {
      return this.handleInterludeEvent(target, params);
    } else if (event_name == "resume") {
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
      return {error: `Unable to find an event handler for |${event_name}|`};
    } else {
      console.log(`Routing event |${event_name}| to |${receiver.id}|`);
      return handler(receiver, params);
    }
  },

  handleCardEvent(target, params) {
    console.log(`Handle card event: |${target}|`);
    this.scene.playCardWithId(target, params);
    return {builtin: true};
  },

  handleSwitchEvent(target, params) {
    console.log(`Handle switch event: |${target}|`);
    this.game.startSceneWithId(target, params);
    return {builtin: true};
  },

  handleInterludeEvent(target, params) {
    console.log(`Handle interlude event: |${target}|`);
    this.game.interludeSceneWithId(target, params);
    return {builtin: true};
  },

  handleResumeEvent(params) {
    console.log("Handle resume event");
    this.game.resumePrevScene(params);
    return {builtin: true};
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

function RezEventProcessor(game) {
  this.game = game;
}

RezEventProcessor.prototype = event_processor_proto;
RezEventProcessor.prototype.constructor = RezEventProcessor;
window.Rez.EventProcessor = RezEventProcessor;
