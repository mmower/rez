//-----------------------------------------------------------------------------
// Scene
//-----------------------------------------------------------------------------

/**
 * @class RezScene
 * @extends RezBasicObject
 * @description Represents a scene in the Rez game engine. Scenes are containers that manage
 * the flow of cards and content, handling transitions between different parts of the game
 * narrative.
 *
 * ## Scene Lifecycle
 * Scenes follow a defined lifecycle:
 * 1. **start** - Scene is initialized and begins playing its initial card
 * 2. **ready** - Scene is fully rendered and ready for player interaction
 * 3. **interrupt** - Scene is paused for an interlude (optional)
 * 4. **resume** - Scene continues after an interlude (optional)
 * 5. **finish** - Scene completes and is reset
 *
 * ## Layout Modes
 * Scenes support two layout modes that control how cards are displayed:
 * - **single** - Each new card replaces the previous one (default)
 * - **stack** - Cards stack on top of each other; finished cards flip to show their back
 *
 * ## Card Management
 * Scenes manage the current card and coordinate card transitions:
 * - `initial_card` - The first card played when the scene starts
 * - `current_card` - The currently active card
 * - `last_card_id` - ID of the previously active card
 * - Cards are wrapped in RezBlock instances and added to the scene's view layout
 *
 * ## Interludes
 * Scenes can be interrupted for interludes - temporary scene switches that return
 * to the original scene. The game maintains a scene stack for this purpose:
 * - `interrupt()` - Called when an interlude begins
 * - `resume(params)` - Called when returning from an interlude
 *
 * ## Event Handlers
 * Scenes can define event handlers using the `on_<event>` attribute naming convention:
 * - `on_start` - Called when the scene starts
 * - `on_ready` - Called after the scene is rendered
 * - `on_start_card` - Called when a new card begins
 * - `on_finish_card` - Called when a card finishes
 * - `on_interrupt` - Called when an interlude begins
 * - `on_resume` - Called when returning from an interlude
 * - `on_finish` - Called when the scene ends
 */
class RezScene extends RezBasicObject {
  /**
   * @function constructor
   * @memberof RezScene#
   * @param {string} id - unique identifier for this scene
   * @param {object} attributes - scene attributes from Rez compilation
   * @description Creates a new scene instance and initializes it to a reset state
   */
  constructor(id, attributes) {
    super("scene", id, attributes);
    this.reset();
  }

  /**
   * @function isStackLayout
   * @memberof RezScene#
   * @returns {boolean} true if this scene uses stack layout mode
   * @description Determines if this scene stacks cards on top of each other (stack mode)
   * or replaces the current card with each new one (single mode)
   */
  get isStackLayout() {
    return this.layout_mode === "stack";
  }

  /**
   * @function current_block
   * @memberof RezScene#
   * @returns {RezLayout} the current view layout for this scene
   * @description Returns the view layout that manages how content is displayed in this scene
   */
  get current_block() {
    return this.getViewLayout();
  }

  /**
   * @function bindAs
   * @memberof RezScene#
   * @returns {string} "scene"
   * @description Returns the binding identifier for template rendering
   */
  bindAs() {
    return "scene";
  }

  /**
   * @function getViewTemplate
   * @memberof RezScene#
   * @param {boolean} flipped - ignored for scenes (only cards can be flipped)
   * @returns {*} the template used to render this scene's layout
   * @description Returns the layout template for rendering this scene. The flipped parameter is ignored since scenes cannot be flipped.
   */
  getViewTemplate(flipped) {
    // Scenes can't be flipped, only cards
    return this.$layout_template;
  }

  /**
   * @function getViewLayout
   * @memberof RezScene#
   * @returns {RezLayout} the view layout instance for this scene
   * @description Gets or creates the view layout for this scene. The layout is cached and reused.
   */
  getViewLayout() {
    this.$viewLayout = this.$viewLayout ?? this.createViewLayout();
    return this.$viewLayout;
  }

  /**
   * @function createViewLayout
   * @memberof RezScene#
   * @returns {RezStackLayout|RezSingleLayout} the appropriate layout instance
   * @description Creates a new view layout based on the scene's layout mode.
   * Returns RezStackLayout for stack mode or RezSingleLayout for single mode.
   */
  createViewLayout() {
    if(this.isStackLayout) {
      return new RezStackLayout("scene", this);
    } else {
      return new RezSingleLayout("scene", this);
    }
  }

  /**
   * @function playCardWithId
   * @memberof RezScene#
   * @param {string} cardId - ID of the card to play
   * @param {object} params - parameters to pass to the card
   * @description Plays a card by looking it up by ID and calling playCard with the card instance
   */
  playCardWithId(cardId, params = {}) {
    this.playCard($t(cardId, "card", true), params);
  }

  /**
   * @function playCard
   * @memberof RezScene#
   * @param {RezCard} newCard - the card instance to play
   * @param {object} params - parameters to pass to the card
   * @description Transitions to a new card, finishing the current card if any, starting the new one,
   * updating the view, and triggering the card's ready event.
   */
  playCard(newCard, params = {}) {
    this.finishCurrentCard();

    this.startNewCard(newCard, params);
    this.game.updateView();
    this.current_card.runEvent("ready", params);
  }

  /**
   * @function finishCurrentCard
   * @memberof RezScene#
   * @description Finishes the currently active card by running its finish event,
   * triggering the scene's finish_card event, and in stack layout mode, flipping the card.
   */
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

  /**
   * @function startNewCard
   * @memberof RezScene#
   * @param {RezCard} card - the card to start
   * @param {object} params - parameters to pass to the card
   * @description Sets up a new card as the current card, adds it to the view layout,
   * and triggers the appropriate start events.
   */
  startNewCard(card, params = {}) {
    card.scene = this;
    this.current_card = card;

    this.addContentToViewLayout(params);

    this.runEvent("start_card", {});
    card.runEvent("start", params);
  }

  /**
   * @function resumeFromLoad
   * @memberof RezScene#
   * @description Resumes the scene after loading from a saved game state.
   * Ensures the current card is properly restored to the view layout.
   * @throws {Error} if no current card is available to resume
   */
  resumeFromLoad() {
    if(!(this.current_card instanceof RezCard)) {
      throw new Error("Attempting to resume scene after reload but there is no current card!");
    }

    this.addContentToViewLayout({});
  }

  /**
   * @function addContentToViewLayout
   * @memberof RezScene#
   * @param {object} params - parameters to pass to the content block
   * @description Creates a new content block for the current card and adds it to the scene's view layout
   */
  addContentToViewLayout(params = {}) {
    const block = new RezBlock("card", this.current_card, params);
    this.current_card.current_block = block;
    this.getViewLayout().addContent(block);
  }

  /**
   * @function reset
   * @memberof RezScene#
   * @description Resets the scene to its initial state, clearing the current card,
   * view layout, and running status
   */
  reset() {
    this.current_card_id = "";
    this.$viewLayout = null;
    this.$running = false;
  }

  /**
   * @function interrupt
   * @memberof RezScene#
   * @description Interrupts the current scene execution, typically when switching to an interlude scene.
   * Triggers the scene's interrupt event.
   */
  interrupt() {
    console.log(`Interrupting scene |${this.id}|`);
    this.runEvent("interrupt", {});
  }

  /**
   * @function resume
   * @memberof RezScene#
   * @param {object} params - parameters passed from the interlude scene
   * @description Resumes the scene after an interlude, triggering the scene's resume event
   */
  resume(params = {}) {
    console.log(`Resuming scene |${this.id}|`);
    this.runEvent("resume", params);
  }

  /**
   * @function start
   * @memberof RezScene#
   * @param {object} params - parameters to pass to the scene and initial card
   * @description Starts the scene by initializing it, triggering the start event,
   * setting the running state, and playing the initial card
   */
  start(params = {}) {
    this.runEvent("start", params);
    this.setAttribute("$running", true);
    this.playCard(this.initial_card, params);
  }

  /**
   * @function ready
   * @memberof RezScene#
   * @description Triggers the scene's ready event, indicating the scene is fully initialized and ready for interaction
   */
  ready() {
    this.runEvent("ready", {});
  }

  /**
   * @function finish
   * @memberof RezScene#
   * @description Finishes the scene by completing the current card, triggering the finish event,
   * setting running state to false, and resetting the scene
   */
  finish() {
    this.finishCurrentCard();
    this.runEvent("finish", {});
    this.setAttribute("$running", false);
    this.reset();
  }
}

window.Rez.RezScene = RezScene;
