//-----------------------------------------------------------------------------
// Card
//-----------------------------------------------------------------------------

/**
 * @class RezCard
 * @extends RezBasicObject
 * @category Elements
 * @description Represents a card in the Rez game engine. Cards are the primary content
 * containers that display narrative text, choices, and interactive elements to the player.
 *
 * Cards exist within scenes and follow a defined lifecycle:
 * 1. **start** - Card is initialized and becomes the current card
 * 2. **ready** - Card is rendered and ready for player interaction
 * 3. **finish** - Card is being replaced or scene is ending
 *
 * ## Template System
 * Cards use templates to render their content:
 * - `$content_template` - The main content template (required)
 * - `$flipped_template` - Optional back-side template for use in stack layouts
 * - `$flipped` - Boolean indicating whether to show the flipped template
 *
 * ## Scene Relationship
 * Cards have a transient reference to their containing scene, set when the scene
 * calls `playCard()`. In single layout mode, this reference becomes stale when
 * the card is replaced. In stack layout mode, the reference persists while the
 * scene is running.
 *
 * ## Block System
 * Each card is wrapped in a RezBlock for rendering. The block manages the card's
 * position in the layout and handles flip state transitions.
 *
 * ## Event Handlers
 * Cards can define event handlers using the `on_<event>` attribute naming convention:
 * - `on_start` - Called when the card becomes the current card
 * - `on_ready` - Called after the card is rendered
 * - `on_finish` - Called when the card is being replaced
 * - `on_<custom>` - Custom events triggered by game logic
 */
class RezCard extends RezBasicObject {
  #scene;
  #current_block;

  /**
   * @function constructor
   * @memberof RezCard#
   * @param {string} id - unique identifier for this card
   * @param {object} attributes - card attributes from Rez compilation
   * @description Creates a new card instance with null scene and block references
   */
  constructor(id, attributes) {
    super("card", id, attributes);
    this.#current_block = null;
    this.#scene = null;
  }

  /**
   * @function current_block
   * @memberof RezCard#
   * @returns {RezBlock|null} the block currently rendering this card
   * @description Gets the RezBlock instance that wraps this card for rendering.
   * The block manages the card's position in the layout and its flip state.
   */
  get current_block() {
    return this.#current_block;
  }

  /**
   * @function current_block
   * @memberof RezCard#
   * @param {RezBlock} block - the block to set
   * @description Sets the RezBlock instance for this card. Called by the scene
   * when adding the card to the view layout.
   */
  set current_block(block) {
    this.#current_block = block;
  }

  /**
   * @function scene
   * @memberof RezCard#
   * @returns {RezScene|null} the scene containing this card
   * @description Gets the scene that currently contains this card. This is a transient
   * reference set by the scene via startNewCard(). In single layout mode the reference
   * becomes stale when the card is replaced. In stack layout mode the reference persists
   * as long as the scene is running.
   */
  get scene() {
    return this.#scene;
  }

  /**
   * @function scene
   * @memberof RezCard#
   * @param {RezScene} scene - the scene to set
   * @description Sets the scene reference for this card. Called by the scene when
   * starting a new card.
   */
  set scene(scene) {
    this.#scene = scene;
  }

  /**
   * @function bindAs
   * @memberof RezCard#
   * @returns {string} "card"
   * @description Returns the binding identifier used in template rendering. When a card
   * is rendered, its properties are bound to the template context under this name.
   */
  bindAs() {
    return "card";
  }

  /**
   * @function getViewTemplate
   * @memberof RezCard#
   * @param {boolean} [flipped] - whether to get the flipped template. Defaults to the card's $flipped attribute.
   * @returns {function} the template function for rendering this card
   * @description Returns the appropriate template for rendering this card based on flip state.
   * If flipped is true, returns the $flipped_template (falling back to $content_template if
   * no flipped template exists). Otherwise returns the $content_template.
   * @throws {Error} if the card has no content template defined
   */
  getViewTemplate(flipped = this.$flipped) {
    const template = flipped
      ? (this.$flipped_template || this.$content_template)
      : this.$content_template;

    if(!template) {
      throw new Error(`Card |${this.id}| has no content template!`);
    }

    return template;
  }

  /**
   * @function handleCustomEvent
   * @memberof RezCard#
   * @param {string} event_name - the name of the custom event to handle
   * @param {RezEvent} evt - the event object containing event data
   * @returns {object} the result from the event handler, or an error object if no handler exists
   * @description Handles custom events by looking up and invoking the appropriate event handler.
   * Event handlers are defined using the `on_<event_name>` attribute naming convention.
   * Returns an error object with a descriptive message if no handler is found.
   */
  handleCustomEvent(event_name, evt) {
    const handler = this.eventHandler(event_name);
    if(handler && typeof handler === "function") {
      return handler(this, evt);
    } else {
      return {
        error: `No handler for event ${event_name}. Did you use an on_xxx prefix?`,
      };
    }
  }
}

window.Rez.RezCard = RezCard;
