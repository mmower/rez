//-----------------------------------------------------------------------------
// Event Handling SubSystem
//-----------------------------------------------------------------------------

/**
 * @class RezEvent
 * @description Represents a game event response in the Rez game engine. Events are used to communicate
 * the results of user interactions and specify what actions should be taken (scene changes, card plays,
 * flash messages, etc.). Supports method chaining for building complex event responses.
 *
 * @example
 * // Create an event that plays a card and shows a message
 * return RezEvent.playCard("next_card").flash("Moving forward!").render();
 */
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

  /**
   * @function constructor
   * @memberof RezEvent#
   * @description Creates a new event response with default values
   */
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

  /**
   * @function params
   * @memberof RezEvent#
   * @returns {object} the parameters object associated with this event
   */
  get params() {
    return this.#params;
  }

  /**
   * @function flashMessages
   * @memberof RezEvent#
   * @returns {string[]} array of flash messages to display
   */
  get flashMessages() {
    return this.#flashMessages;
  }

  /**
   * @function cardId
   * @memberof RezEvent#
   * @returns {string|null} ID of the card to play, or null if no card action
   */
  get cardId() {
    return this.#cardId;
  }

  /**
   * @function sceneId
   * @memberof RezEvent#
   * @returns {string|null} ID of the scene for scene transition, or null if no scene action
   */
  get sceneId() {
    return this.#sceneId;
  }

  /**
   * @function sceneChangeEvent
   * @memberof RezEvent#
   * @returns {boolean} true if this event should trigger a scene change
   */
  get sceneChangeEvent() {
    return this.#sceneChangeEvent;
  }

  /**
   * @function sceneInterludeEvent
   * @memberof RezEvent#
   * @returns {boolean} true if this event should trigger a scene interlude
   */
  get sceneInterludeEvent() {
    return this.#sceneInterludeEvent;
  }

  /**
   * @function sceneResumeEvent
   * @memberof RezEvent#
   * @returns {boolean} true if this event should resume the previous scene
   */
  get sceneResumeEvent() {
    return this.#sceneResumeEvent;
  }

  /**
   * @function renderEvent
   * @memberof RezEvent#
   * @returns {boolean} true if this event should trigger a view render
   */
  get renderEvent() {
    return this.#renderEvent;
  }

  /**
   * @function errorMessage
   * @memberof RezEvent#
   * @returns {string|null} error message if this is an error event, or null
   */
  get errorMessage() {
    return this.#errorMessage;
  }

  /**
   * @function setParam
   * @memberof RezEvent#
   * @param {string} name - parameter name
   * @param {*} value - parameter value
   * @returns {RezEvent} this event for method chaining
   * @description Sets a single parameter on this event
   */
  setParam(name, value ) {
    this.#params[name] = value;
    return this;
  }

  /**
   * @function setParams
   * @memberof RezEvent#
   * @param {object} params - parameters object to set
   * @returns {RezEvent} this event for method chaining
   * @description Replaces the entire parameters object for this event
   */
  setParams(params) {
    this.#params = params;
    return this;
  }

  /**
   * @function hasFlash
   * @memberof RezEvent#
   * @returns {boolean} true if this event has flash messages to display
   */
  get hasFlash() {
    return this.#flashMessages.length > 0;
  }

  /**
   * @function flash
   * @memberof RezEvent#
   * @param {string} message - message to display as a flash
   * @returns {RezEvent} this event for method chaining
   * @description Adds a flash message to be displayed to the user
   */
  flash(message) {
    this.#flashMessages.push(message);
    return this;
  }

  /**
   * @function shouldPlayCard
   * @memberof RezEvent#
   * @returns {boolean} true if this event should play a card
   */
  get shouldPlayCard() {
    return this.#cardId != null;
  }

  /**
   * @function playCard
   * @memberof RezEvent#
   * @param {string} cardId - ID of the card to play
   * @returns {RezEvent} this event for method chaining
   * @description Sets this event to play the specified card
   */
  playCard(cardId) {
    this.#cardId = cardId;
    return this;
  }

  /**
   * @function shouldRender
   * @memberof RezEvent#
   * @returns {boolean} true if this event should trigger a view render
   */
  get shouldRender() {
    return this.#renderEvent;
  }

  /**
   * @function render
   * @memberof RezEvent#
   * @returns {RezEvent} this event for method chaining
   * @description Sets this event to trigger a view render
   */
  render() {
    this.#renderEvent = true;
    return this;
  }

  /**
   * @function shouldChangeScene
   * @memberof RezEvent#
   * @returns {boolean} true if this event should change to a new scene
   */
  get shouldChangeScene() {
    return this.#sceneChangeEvent;
  }

  /**
   * @function sceneChange
   * @memberof RezEvent#
   * @param {string} sceneId - ID of the scene to change to
   * @returns {RezEvent} this event for method chaining
   * @description Sets this event to change to the specified scene
   */
  sceneChange(sceneId) {
    if(this.#sceneInterludeEvent || this.#sceneResumeEvent) {
      throw new Error(`Attempt to sceneChange after sceneInterlude or sceneResume!`);
    }
    this.#sceneChangeEvent = true;
    this.#sceneId = sceneId;
    return this;
  }

  /**
   * @function shouldInterludeScene
   * @memberof RezEvent#
   * @returns {boolean} true if this event should start a scene interlude
   */
  get shouldInterludeScene() {
    return this.#sceneInterludeEvent;
  }

  /**
   * @function sceneInterlude
   * @memberof RezEvent#
   * @param {string} sceneId - ID of the scene to interlude with
   * @returns {RezEvent} this event for method chaining
   * @description Sets this event to start an interlude with the specified scene
   */
  sceneInterlude(sceneId) {
    if(this.#sceneChangeEvent || this.#sceneResumeEvent) {
      throw new Error(`Attempt to sceneInterlude after sceneChange or sceneResume!`);
    }
    this.#sceneInterludeEvent = true;
    this.#sceneId = sceneId;
    return this;
  }

  /**
   * @function shouldResumeScene
   * @memberof RezEvent#
   * @returns {boolean} true if this event should resume the previous scene
   */
  get shouldResumeScene() {
    return this.#sceneResumeEvent;
  }

  /**
   * @function sceneResume
   * @memberof RezEvent#
   * @returns {RezEvent} this event for method chaining
   * @description Sets this event to resume the previous scene from the scene stack
   */
  sceneResume() {
    if(this.#sceneChangeEvent || this.#sceneInterludeEvent) {
      throw new Error(`Attempt to sceneResume after sceneChange or sceneInterlude!`);
    }
    this.#sceneResumeEvent = true;
    return this;
  }

  /**
   * @function isError
   * @memberof RezEvent#
   * @returns {boolean} true if this is an error event
   */
  get isError() {
    return this.#errorMessage != null;
  }

  /**
   * @function error
   * @memberof RezEvent#
   * @param {string} message - error message
   * @returns {RezEvent} this event for method chaining
   * @description Sets this event as an error with the specified message
   */
  error(message) {
    this.#errorMessage = message;
    return this;
  }

  /**
   * @function noop
   * @memberof RezEvent#
   * @returns {RezEvent} this event for method chaining
   * @description No-operation method for method chaining when no action is needed
   */
  noop() {
    return this;
  }

  /**
   * @function built_in
   * @memberof RezEvent
   * @static
   * @returns {RezEvent} a new empty event
   * @description Creates a new built-in event with default values
   */
  static built_in() {
    return new RezEvent();
  }

  /**
   * @function flash
   * @memberof RezEvent
   * @static
   * @param {string} message - flash message to display
   * @returns {RezEvent} a new event with the flash message
   * @description Creates a new event that displays a flash message
   */
  static flash(message) {
    return new RezEvent().flash(message);
  }

  /**
   * @function playCard
   * @memberof RezEvent
   * @static
   * @param {string} cardId - ID of the card to play
   * @returns {RezEvent} a new event that plays the specified card
   * @description Creates a new event that plays the specified card
   */
  static playCard(cardId) {
    return new RezEvent().playCard(cardId);
  }

  /**
   * @function render
   * @memberof RezEvent
   * @static
   * @returns {RezEvent} a new event that triggers a render
   * @description Creates a new event that triggers a view render
   */
  static render() {
    return new RezEvent().render();
  }

  /**
   * @function setParam
   * @memberof RezEvent
   * @static
   * @param {string} param - parameter name
   * @param {*} value - parameter value
   * @returns {RezEvent} a new event with the specified parameter
   * @description Creates a new event with a single parameter set
   */
  static setParam(param, value) {
    return new RezEvent().setParam(param, value);
  }

  /**
   * @function sceneChange
   * @memberof RezEvent
   * @static
   * @param {string} sceneId - ID of the scene to change to
   * @returns {RezEvent} a new event that changes to the specified scene
   * @description Creates a new event that changes to the specified scene
   */
  static sceneChange(sceneId) {
    return new RezEvent().sceneChange(sceneId);
  }

  /**
   * @function sceneInterlude
   * @memberof RezEvent
   * @static
   * @param {string} sceneId - ID of the scene to interlude with
   * @returns {RezEvent} a new event that starts an interlude
   * @description Creates a new event that starts an interlude with the specified scene
   */
  static sceneInterlude(sceneId) {
    return new RezEvent().sceneInterlude(sceneId);
  }

  /**
   * @function sceneResume
   * @memberof RezEvent
   * @static
   * @returns {RezEvent} a new event that resumes the previous scene
   * @description Creates a new event that resumes the previous scene from the stack
   */
  static sceneResume() {
    return new RezEvent().sceneResume();
  }

  /**
   * @function noop
   * @memberof RezEvent
   * @static
   * @returns {RezEvent} a new empty event
   * @description Creates a new event that performs no action
   */
  static noop() {
    return new RezEvent();
  }

  /**
   * @function error
   * @memberof RezEvent
   * @static
   * @param {string} message - error message
   * @returns {RezEvent} a new error event
   * @description Creates a new event that represents an error
   */
  static error(message) {
    return new RezEvent().error(message);
  }
}

window.Rez.RezEvent = RezEvent;

/**
 * @class RezEventProcessor
 * @description Processes events in the Rez game engine. Handles browser events (clicks, inputs, submits),
 * custom game events, timer events, and system events. Routes events to appropriate handlers and manages
 * the event lifecycle including system pre/post processing and undo manager integration.
 */
class RezEventProcessor {
  #game;

  /**
   * @function constructor
   * @memberof RezEventProcessor#
   * @param {RezGame} game - the game instance this processor belongs to
   * @description Creates a new event processor for the specified game
   */
  constructor(game) {
    this.#game = game;
  }

  /**
   * @function game
   * @memberof RezEventProcessor#
   * @returns {RezGame} the game instance
   */
  get game() {
    return this.#game;
  }

  /**
   * @function scene
   * @memberof RezEventProcessor#
   * @returns {RezScene} the current scene
   */
  get scene() {
    return this.#game.current_scene;
  }

  /**
   * @function card
   * @memberof RezEventProcessor#
   * @returns {RezCard} the current card
   */
  get card() {
    return this.#game.current_scene.current_card;
  }

  /**
   * @function dispatchResponse
   * @memberof RezEventProcessor#
   * @param {RezEvent} response - the event response to process
   * @description Processes a RezEvent response by executing the actions it specifies:
   * flash messages, scene changes/interludes/resumes, card plays, view renders, and error handling.
   * @throws {Error} if the response is not a RezEvent instance
   */
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

  /**
   * @function beforeEventProcessing
   * @memberof RezEventProcessor#
   * @param {Event} evt - the browser event to pre-process
   * @returns {Event} the processed event
   * @description Runs the event through all enabled systems' before_event handlers.
   * Each system can modify the event before it gets processed.
   * @throws {Error} if any system handler doesn't return a valid event object
   */
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

  /**
   * @function afterEventProcessing
   * @memberof RezEventProcessor#
   * @param {Event} evt - the original browser event
   * @param {*} result - the result from event processing
   * @returns {*} the processed result
   * @description Runs the event result through all enabled systems' after_event handlers.
   * Each system can modify the result after the event has been processed.
   * @throws {Error} if any system handler doesn't return a valid result object
   */
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

  /**
   * @function raiseTimerEvent
   * @memberof RezEventProcessor#
   * @param {RezTimer} timer - the timer that fired
   * @returns {*} the result of processing the timer event
   * @description Creates and processes a custom timer event
   */
  raiseTimerEvent(timer) {
    const evt = new CustomEvent('timer', {detail: {timer: timer}});
    return this.handleBrowserEvent(evt);
  }

  /**
   * @function raiseKeyBindingEvent
   * @memberof RezEventProcessor#
   * @param {string} event_name - the name of the key binding event
   * @returns {*} the result of processing the key binding event
   * @description Creates and processes a custom key binding event
   */
  raiseKeyBindingEvent(event_name) {
    const evt = new CustomEvent("key_binding", {detail: {event_name: event_name}});
    return this.handleBrowserEvent(evt);
  }

  /**
   * @function isAutoUndoEvent
   * @memberof RezEventProcessor#
   * @param {Event} evt - the event to check
   * @returns {boolean} true if this event type should trigger automatic undo recording
   * @description Determines if an event should automatically record undo state
   */
  isAutoUndoEvent(evt) {
    const evtTypes = ["click", "input", "submit", "key_binding"];
    return evtTypes.includes(evt.type);
  }

  /**
   * @function handleBrowserEvent
   * @memberof RezEventProcessor#
   * @param {Event} evt - the browser event to handle
   * @returns {*} the result of processing the event
   * @description Main event handler that processes browser events. Handles undo recording,
   * system pre/post processing, and routes events to specific handlers based on type.
   */
  handleBrowserEvent(evt) {
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
      result = RezEvent.error(`No handler for event of type '${evt.type}'!`);
    }

    return this.afterEventProcessing(evt, result);
  }

  /**
   * @function decodeEvent
   * @memberof RezEventProcessor#
   * @param {Event} evt - the browser event to decode
   * @returns {Array} [eventName, target, params] decoded from the event's dataset
   * @description Extracts event name, target, and parameters from an element's dataset attributes
   */
  decodeEvent(evt) {
    const {event, target, ...params} = evt.currentTarget.dataset;
    if(event === undefined) {
      throw new Error(`Improperly encoded event!`);
    }
    return [event.toLowerCase(), target, params];
  }

  /**
   * @function handleTimerEvent
   * @memberof RezEventProcessor#
   * @param {CustomEvent} evt - the timer event with timer details
   * @returns {*} the result of handling the timer event
   * @description Handles timer events by routing them to custom event handlers
   */
  handleTimerEvent(evt) {
    const timer = evt.detail.timer;
    const result = this.handleCustomEvent(timer.event, {timer: timer.id});
    if(typeof(result) !== "object") {
      return RezEvent.noop();
    } else {
      return result;
    }
  }

  /**
   * @function handleKeyBindingEvent
   * @memberof RezEventProcessor#
   * @param {CustomEvent} evt - the key binding event with event name details
   * @returns {*} the result of handling the key binding event
   * @description Handles key binding events by routing them to custom event handlers
   */
  handleKeyBindingEvent(evt) {
    const result = this.handleCustomEvent(evt.detail.event_name, {});
    if(typeof(result) !== "object") {
      return RezEvent.noop();
    } else {
      return result;
    }
  }

  /**
   * @function handleBrowserClickEvent
   * @memberof RezEventProcessor#
   * @param {Event} evt - the click event
   * @returns {*} the result of handling the click event
   * @description Handles browser click events by decoding the event data and routing to appropriate handlers.
   * Supports built-in event types (card, switch, interlude, resume) and custom events.
   */
  handleBrowserClickEvent(evt) {
    const [eventName, target, params] = this.decodeEvent(evt);

    if(typeof(eventName) === "undefined") {
      if(RezBasicObject.game.$debug_events) {
        console.log("Received click event without an event name!");
      }
      return RezEvent.error("Received event without an event name. Cannot process it!");
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

  /**
   * @function getReceiverEventHandler
   * @memberof RezEventProcessor#
   * @param {*} receiver - the object to check for event handlers
   * @param {string} eventname - the name of the event to find a handler for
   * @returns {Function|null} the event handler function or null if not found
   * @description Gets an event handler function from a receiver object
   */
  getReceiverEventHandler(receiver, eventname) {
    let handler = receiver.eventHandler(eventname);
    if(handler && typeof(handler) === "function") {
      return handler;
    } else {
      return null;
    }
  }

  /**
   * @function getEventHandler
   * @memberof RezEventProcessor#
   * @param {string} eventName - the name of the event to find a handler for
   * @returns {Array} [receiver, handler] pair where receiver is the object that handles the event
   * @description Finds an event handler by checking card, scene, and game in that order.
   * Returns the first receiver that has a handler for the event.
   */
  getEventHandler(eventName) {
    const receivers = [this.card, this.scene, this.game];
    const handlers = receivers.map((receiver) => [receiver, this.getReceiverEventHandler(receiver, eventName)]);
    return handlers.find(([receiver, handler]) => handler) ?? [null, null];
  }

  /**
   * @function handleCustomEvent
   * @memberof RezEventProcessor#
   * @param {string} eventName - the name of the custom event
   * @param {object} params - parameters to pass to the event handler
   * @returns {RezEvent} the result of the event handler or an error event
   * @description Handles custom events by finding and calling the appropriate event handler
   */
  handleCustomEvent(eventName, params) {
    const [receiver, handler] = this.getEventHandler(eventName);
    if(!handler) {
      return RezEvent.error(`Unable to find an event handler for |${eventName}|`);
    } else {
      if(RezBasicObject.game.$debug_events) {
        console.log(`Routing event |${eventName}| to |${receiver.id}|`);
      }
      return handler(receiver, params);
    }
  }

  /**
   * @function handleCardEvent
   * @memberof RezEventProcessor#
   * @param {string} target - ID of the card to play
   * @param {object} params - parameters to pass to the card
   * @returns {RezEvent} event that plays the specified card
   * @description Handles built-in card events that play a specific card
   */
  handleCardEvent(target, params) {
    if(RezBasicObject.game.$debug_events) {
      console.log(`Handle card event: |${target}|`);
    }
    return RezEvent.playCard(target).setParams(params);
  }

  /**
   * @function handleSwitchEvent
   * @memberof RezEventProcessor#
   * @param {string} target - ID of the scene to switch to
   * @param {object} params - parameters to pass to the scene
   * @returns {RezEvent} event that changes to the specified scene
   * @description Handles built-in switch events that change to a new scene
   */
  handleSwitchEvent(target, params) {
    if(RezBasicObject.game.$debug_events) {
      console.log(`Handle switch event: |${target}|`);
    }
    return RezEvent.sceneChange(target).setParams(params);
  }

  /**
   * @function handleInterludeEvent
   * @memberof RezEventProcessor#
   * @param {string} target - ID of the scene to interlude with
   * @param {object} params - parameters to pass to the scene
   * @returns {RezEvent} event that starts an interlude with the specified scene
   * @description Handles built-in interlude events that interrupt the current scene
   */
  handleInterludeEvent(target, params) {
    if(RezBasicObject.game.$debug_events) {
      console.log(`Handle interlude event: |${target}|`);
    }
    return RezEvent.sceneInterlude(target).setParams(params);
  }

  /**
   * @function handleResumeEvent
   * @memberof RezEventProcessor#
   * @param {object} params - parameters to pass to the resumed scene
   * @returns {RezEvent} event that resumes the previous scene
   * @description Handles built-in resume events that return to the previous scene
   */
  handleResumeEvent(params) {
    if(RezBasicObject.game.$debug_events) {
      console.log("Handle resume event");
    }

    return RezEvent.sceneResume().setParams(params);
  }

  /**
   * @function handleBrowserInputEvent
   * @memberof RezEventProcessor#
   * @param {Event} evt - the input event
   * @returns {RezEvent} the result of the card's input event handler
   * @description Handles browser input events by finding the card that contains the input element
   * and calling its input event handler.
   * @throws {Error} if the card container or card ID cannot be found
   */
  handleBrowserInputEvent(evt) {
    console.log("Handle input event");

    // Try to find the containing card from the DOM (handles blocks/nested cards)
    const cardDiv = evt.target.closest("div[data-card]");
    if(cardDiv) {
      const cardId = cardDiv.dataset.card;
      const card = $(cardId);
      const handler = this.getReceiverEventHandler(card, "input");
      if(handler) {
        return handler(card, {evt: evt}) || RezEvent.noop();
      }
    }

    // Fall back to bubbling mechanism (scene → game)
    const [receiver, handler] = this.getEventHandler("input");
    if(!handler) {
      return RezEvent.noop();
    }
    return handler(receiver, {evt: evt}) || RezEvent.noop();
  }

  /**
   * @function handleBrowserSubmitEvent
   * @memberof RezEventProcessor#
   * @param {Event} evt - the submit event
   * @returns {RezEvent} the result of the card's form event handler
   * @description Handles browser form submit events by finding the card that contains the form
   * and calling its event handler named after the form.
   * @throws {Error} if the form name or card container cannot be found
   */
  handleBrowserSubmitEvent(evt) {
    const formName = evt.target.getAttribute("name");
    if(!formName) {
      throw new Error("Cannot get form name!");
    }

    // Try to find the containing card from the DOM (handles blocks/nested cards)
    const cardDiv = evt.target.closest("div[data-card]");
    if(cardDiv) {
      const cardId = cardDiv.dataset.card;
      const card = $(cardId);
      const handler = this.getReceiverEventHandler(card, formName);
      if(handler) {
        return handler(card, {form: evt.target}) || RezEvent.noop();
      }
    }

    // Fall back to bubbling mechanism (scene → game)
    const [receiver, handler] = this.getEventHandler(formName);
    if(!handler) {
      return RezEvent.noop();
    }
    return handler(receiver, {form: evt.target}) || RezEvent.noop();
  }
}

window.Rez.RezEventProcessor = RezEventProcessor;
