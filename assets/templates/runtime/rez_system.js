//-----------------------------------------------------------------------------
// System
//-----------------------------------------------------------------------------

/**
 * @class RezSystem
 * @extends RezBasicObject
 * @description Represents a game system in the Rez game engine. Systems are used to implement
 * cross-cutting game mechanics that operate on events and game state. They can define
 * before_event and after_event handlers that are called during event processing, allowing
 * them to modify events and results. Systems have priority and enabled/disabled states.
 */
class RezSystem extends RezBasicObject {
  /**
   * @function constructor
   * @memberof RezSystem
   * @param {string} id - unique identifier for this system
   * @param {object} attributes - system attributes from Rez compilation including priority and handlers
   * @description Creates a new game system instance
   */
  constructor(id, attributes) {
    super("system", id, attributes);
  }
}

window.Rez.RezSystem = RezSystem;
