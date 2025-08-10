//-----------------------------------------------------------------------------
// Behaviour
//-----------------------------------------------------------------------------

/**
 * @class RezBehaviour
 * @extends RezBasicObject
 * @description Represents a behaviour in the Rez game engine's behaviour tree system.
 * Behaviours are reusable templates that define game logic and can be instantiated with
 * specific options and child behaviours. They execute with working memory (wmem) and
 * return success/failure results.
 */
class RezBehaviour extends RezBasicObject {
  #options;
  #children;

  /**
   * @function constructor
   * @memberof RezBehaviour
   * @param {string} id - unique identifier for this behaviour
   * @param {object} attributes - behaviour attributes from Rez compilation
   * @description Creates a new behaviour template with empty options and children
   */
  constructor(id, attributes) {
    super("behaviour", id, attributes);

    this.#options = {};
    this.#children = [];
  }

  /**
   * @function firstChild
   * @memberof RezBehaviour
   * @returns {RezBehaviour|undefined} the first child behaviour or undefined if no children
   * @description Convenience accessor for the first child behaviour
   */
  get firstChild() {
    return this.#children[0];
  }

  /**
   * @function secondChild
   * @memberof RezBehaviour
   * @returns {RezBehaviour|undefined} the second child behaviour or undefined if fewer than 2 children
   * @description Convenience accessor for the second child behaviour
   */
  get secondChild() {
    return this.#children[1];
  }

  /**
   * @function childCount
   * @memberof RezBehaviour
   * @returns {number} the number of child behaviours
   * @description Returns the count of child behaviours attached to this behaviour
   */
  get childCount() {
    return this.#children.length;
  }

  /**
   * @function configure
   * @memberof RezBehaviour
   * @description Runs the behaviour's configuration function if defined.
   * This is called during instantiation to set up behaviour-specific configuration.
   */
  configure() {
    const config_fn = this.getAttribute("configure");
    if(typeof(config_fn) === "function") {
      config_fn(this);
    }
  }

  /**
   * @function option
   * @memberof RezBehaviour
   * @param {string} name - the option name to retrieve
   * @returns {*} the option value
   * @description Gets an option value by name
   * @throws {Error} if the option is not defined
   */
  option(name) {
    const value = this.#options[name];
    if(typeof(value) === "undefined") {
      throw new Error(`Behaviour ${this.id} does not define option '${name}'!`);
    }
    return value;
  }

  /**
   * @function numberOption
   * @memberof RezBehaviour
   * @param {string} name - the option name to retrieve
   * @returns {number} the option value as a number
   * @description Gets an option value and ensures it's a number
   * @throws {Error} if the option is not defined or not a number
   */
  numberOption(name) {
    const value = this.option(name);
    if(typeof(value) !== "number") {
      throw new Error(`Behaviour ${this.id} option '${name}' is not a number (${typeof(value)})!`);
    }
    return value;
  }

  /**
   * @function intOption
   * @memberof RezBehaviour
   * @param {string} name - the option name to retrieve
   * @returns {number} the option value as an integer
   * @description Gets an option value as an integer (floors any decimal values)
   */
  intOption(name) {
    return Math.floor(this.numberOption(name));
  }

  /**
   * @function setOption
   * @memberof RezBehaviour
   * @param {string} name - the option name to set
   * @param {*} value - the value to set
   * @description Sets an option value by name
   */
  setOption(name, value) {
    this.#options[name] = value;
  }

  /**
   * @function getChildAt
   * @memberof RezBehaviour
   * @param {number} idx - the index of the child to retrieve
   * @returns {RezBehaviour|undefined} the child behaviour at the specified index
   * @description Gets a child behaviour by index
   */
  getChildAt(idx) {
    return this.#children[idx];
  }

  /**
   * @function result
   * @memberof RezBehaviour
   * @param {object} wmem - the working memory object
   * @param {boolean} success - whether the behaviour succeeded
   * @returns {object} a standardized behaviour result object
   * @description Creates a standardized result object for behaviour execution
   */
  result(wmem, success) {
    return {
      id: this.id,
      wmem: wmem,
      success: success
    };
  }

  /**
   * @function executeBehaviour
   * @memberof RezBehaviour
   * @param {object} wmem - the working memory object containing context for execution
   * @returns {object} result object with id, wmem, success, and optional error properties
   * @description Executes this behaviour with the provided working memory.
   * Validates expected keys in wmem before execution and ensures proper result format.
   * @throws {Error} if the execute function returns an invalid result format
   */
  executeBehaviour(wmem) {
    // By definition this is a function of two attributes
    // (behaviour, wmem)
    const execute = this.getAttribute("execute");
    if(typeof(execute) !== "function") {
      return {
        id: this.id,
        wmem: wmem,
        success: false,
        error: "No execute handler found."
      };
    }

    const expectedKeys = this.getAttribute("expected_keys");
    if(Array.isArray(expectedKeys)) {
      for(let propKey of expectedKeys) {
        if(!wmem.hasOwnProperty(propKey)) {
          return {
            id: this.id,
            wmem: wmem,
            success: false,
            error: `Expected key '${propKey}' is not present in wmem.`
          };
        }
      }
    }

    // owner is a property that is set in the default attributes of the
    // @behaviour element
    const result = execute(this.owner, this, wmem);
    if(typeof(result) !== "object") {
      throw new Error("Behaviour execute returned non-object");
    } else if(!result.hasOwnProperty("success")) {
      throw new Error("Behaviour execute return object without success");
    } else if(typeof(result.success) == "undefined") {
      throw new Error("Behaviour execute returned success undefined");
    }

    return result;
  }

  /**
   * @function instantiate
   * @memberof RezBehaviour
   * @param {object} owner - the object that owns this behaviour instance
   * @param {object} options - options to configure this behaviour instance
   * @param {RezBehaviour[]} children - child behaviours for this instance
   * @returns {RezBehaviour} a new configured behaviour instance
   * @description Creates a new instance of this behaviour template with the specified owner,
   * options, and children. The instance is configured after creation.
   */
  instantiate(owner, options, children = []) {
    const behaviour = this.copyWithAutoId();
    behaviour.owner = owner;
    behaviour.options = options;
    behaviour.children = children;
    behaviour.configure();
    return behaviour;
  }
}

window.Rez.RezBehaviour = RezBehaviour;
