//-----------------------------------------------------------------------------
// Object
//-----------------------------------------------------------------------------

/**
 * @class RezObject
 * @extends RezBasicObject
 * @category Elements
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
 * **Define in Rez:**
 * <pre><code>
 * &#64;object weather_system {
 *   current_weather: "sunny"
 *   temperature: 72
 *   wind_speed: 5
 * }
 * </code></pre>
 *
 * @example <caption>Access at runtime</caption>
 * const weather = $("weather_system");
 * weather.temperature = 65;
 * weather.current_weather = "rainy";
 */
class RezObject extends RezBasicObject {
  /**
   * @function constructor
   * @memberof RezObject
   * @description Creates a new RezObject.
   *
   * @param {string} id - Unique identifier for this object
   * @param {Object} attributes - Initial attribute values
   */
  constructor(id, attributes) {
    super("object", id, attributes)
  }
}

window.Rez.RezObject = RezObject;
