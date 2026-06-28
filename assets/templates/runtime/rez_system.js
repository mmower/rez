//-----------------------------------------------------------------------------
// System
//-----------------------------------------------------------------------------

/**
 * @class RezSystem
 * @extends RezBasicObject
 * @category Elements
 * @description Represents a game system in the Rez game engine. Systems are used to implement
 * cross-cutting game mechanics that operate on events and game state. Systems have priority
 * and enabled/disabled states, and may define handlers on two parallel paths:
 *
 * ## Event path (originating browser events)
 * `before_event(system, evt)` and `after_event(system, evt, result)` are called by the
 * RezEventProcessor around the handling of the six originating events (click, input, submit,
 * timer, key_binding, window_event). These may modify the event and the result (they are
 * threaded/reduced across systems in priority order).
 *
 * ## Lifecycle path (game-level transitions)
 * `before_lifecycle_event(system, eventName, params)` and
 * `after_lifecycle_event(system, eventName, params, result)` are called by
 * `RezGame.broadcastLifecycle` around the game's lifecycle broadcasts, letting a system
 * observe scene/card transitions and renders that never flow through the event processor.
 * `before_lifecycle_event` runs before the game's own `on_<eventName>` handler;
 * `after_lifecycle_event` runs after it, receiving that handler's return value as `result`.
 *
 * This path is observe-only: return values are not threaded back into dispatch (handlers may
 * still mutate the shared `params` object). The lifecycle events delivered are:
 * `scene_will_start`, `scene_did_end`, `scene_will_pause`, `scene_did_resume`,
 * `card_will_start`, `card_did_start`, `card_did_finish`, `will_render`, `did_render`, and
 * `game_did_start`. (`game_will_start` reaches systems via the per-object broadcast instead.)
 *
 * A system must define at least one of these four handlers.
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
