//-----------------------------------------------------------------------------
// Object
//-----------------------------------------------------------------------------

/**
 * @class RezObject
 * @extends RezBasicObject
 * @description A generic game object for author-defined data structures.
 *
 * RezObject provides a way for authors to define custom object types that
 * don't fit into the predefined categories (actors, items, scenes, etc.).
 * Authors can store any attributes they need and use the object from
 * their own scripted functions or behaviours.
 *
 * This is useful for:
 * - Custom game mechanics not covered by built-in types
 * - Data containers for complex game state
 * - Grouping related configuration values
 * - Prototyping new object types before formalizing them
 *
 * @example
 * // Define in Rez
 * @object weather_system {
 *   current_weather: "sunny"
 *   temperature: 72
 *   wind_speed: 5
 * }
 *
 * @example
 * // Access at runtime
 * const weather = $("weather_system");
 * weather.temperature = 65;
 * weather.current_weather = "rainy";
 */
class RezObject extends RezBasicObject {
  /**
   * Creates a new RezObject.
   *
   * @param {string} id - Unique identifier for this object
   * @param {Object} attributes - Initial attribute values
   */
  constructor(id, attributes) {
    super("object", id, attributes)
  }
}

window.Rez.RezObject = RezObject;
