//-----------------------------------------------------------------------------
// Behaviour
//-----------------------------------------------------------------------------

/**
 * @class RezBehaviour
 * @extends RezBasicObject
 * @description Represents a node in the Rez game engine's behaviour tree system.
 * Behaviours are reusable templates that define game logic and can be composed
 * into trees with parent-child relationships.
 *
 * ## Template vs Instance
 * Behaviours follow a template-instance pattern:
 * - **Templates** are defined in Rez source with `@behaviour` and registered globally
 * - **Instances** are created via `instantiate()` with specific owner, options, and children
 * - Templates are never executed directly; always instantiate first
 *
 * ## Tree Structure
 * Behaviours form trees through the `children` property:
 * - Each behaviour can have zero or more child behaviours
 * - Parent behaviours control execution flow (sequence, selector, etc.)
 * - Leaf behaviours perform actual actions
 *
 * ## Execution
 * Behaviours execute via the `execute` attribute function:
 * - Must return a boolean: `true` for success, `false` for failure
 * - The behaviour instance is passed as the first argument
 * - Access the owner object via `this.owner`
 *
 * ## Options
 * Options allow parameterizing behaviour instances:
 * - Set during instantiation
 * - Retrieved via `option()`, `numberOption()`, `intOption()`
 * - Enable reusing the same behaviour template with different configurations
 *
 * ## Configuration
 * The optional `configure` attribute function runs after instantiation:
 * - Receives the behaviour instance
 * - Used for setup that depends on options or owner
 *
 * ## Usage in Rez
 * Behaviour trees are typically attached to objects via the `bht:` attribute prefix,
 * which automatically instantiates the tree with the object as owner.
 */
class RezBehaviour extends RezBasicObject {
  #options;
  #children;

  /**
   * @function constructor
   * @memberof RezBehaviour#
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
   * @function children
   * @memberof RezBehaviour#
   * @returns {RezBehaviour[]} array of child behaviour instances
   * @description Gets the child behaviours of this behaviour node.
   */
  get children() {
    return this.#children;
  }

  /**
   * @function children
   * @memberof RezBehaviour#
   * @param {RezBehaviour[]} children - array of child behaviour instances
   * @description Sets the child behaviours for this behaviour node.
   */
  set children(children) {
    this.#children = children;
  }

  /**
   * @function options
   * @memberof RezBehaviour#
   * @returns {object} the options object for this behaviour instance
   * @description Gets the options configured for this behaviour instance.
   */
  get options() {
    return this.#options;
  }

  /**
   * @function options
   * @memberof RezBehaviour#
   * @param {object} options - options to configure this behaviour
   * @description Sets the options for this behaviour instance.
   */
  set options(options) {
    this.#options = options;
  }

  /**
   * @function firstChild
   * @memberof RezBehaviour#
   * @returns {RezBehaviour|undefined} the first child behaviour or undefined if no children
   * @description Convenience accessor for the first child behaviour
   */
  get firstChild() {
    return this.#children[0];
  }

  /**
   * @function secondChild
   * @memberof RezBehaviour#
   * @returns {RezBehaviour|undefined} the second child behaviour or undefined if fewer than 2 children
   * @description Convenience accessor for the second child behaviour
   */
  get secondChild() {
    return this.#children[1];
  }

  /**
   * @function childCount
   * @memberof RezBehaviour#
   * @returns {number} the number of child behaviours
   * @description Returns the count of child behaviours attached to this behaviour
   */
  get childCount() {
    return this.#children.length;
  }

  /**
   * @function configure
   * @memberof RezBehaviour#
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
   * @memberof RezBehaviour#
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
   * @memberof RezBehaviour#
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
   * @memberof RezBehaviour#
   * @param {string} name - the option name to retrieve
   * @returns {number} the option value as an integer
   * @description Gets an option value as an integer (floors any decimal values)
   */
  intOption(name) {
    return Math.floor(this.numberOption(name));
  }

  /**
   * @function setOption
   * @memberof RezBehaviour#
   * @param {string} name - the option name to set
   * @param {*} value - the value to set
   * @description Sets an option value by name
   */
  setOption(name, value) {
    this.#options[name] = value;
  }

  /**
   * @function getChildAt
   * @memberof RezBehaviour#
   * @param {number} idx - the index of the child to retrieve
   * @returns {RezBehaviour|undefined} the child behaviour at the specified index
   * @description Gets a child behaviour by index
   */
  getChildAt(idx) {
    return this.#children[idx];
  }


  /**
   * @function executeBehaviour
   * @memberof RezBehaviour#
   * @returns {boolean} true if the behaviour succeeded, false otherwise
   * @description Executes this behaviour using the owner's blackboard for context.
   * @throws {Error} if the execute function returns an invalid result format
   */
  executeBehaviour() {
    const execute = this.getAttribute("execute");
    if(typeof(execute) !== "function") {
      console.error(`Behaviour ${this.id}: No execute handler found.`);
      return false;
    }

    const result = execute(this);
    if(typeof(result) !== "boolean") {
      throw new Error(`Behaviour ${this.id} execute returned non-boolean: ${typeof(result)}`);
    }

    return result;
  }

  /**
   * @function instantiate
   * @memberof RezBehaviour#
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
