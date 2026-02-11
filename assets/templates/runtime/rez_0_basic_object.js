//-----------------------------------------------------------------------------
// Basic Object - Foundation for all Rez runtime objects
//-----------------------------------------------------------------------------

/**
 * @function normalizeRefs
 * @param {*} value - any value that may contain $ref objects
 * @returns {*} the value with all {$ref: "id"} objects collapsed to plain "id" strings
 * @description Recursively normalizes reference objects in attribute values. The Rez compiler
 * outputs element references as `{$ref: "element_id"}` objects. This function collapses them
 * to plain ID strings for simpler runtime handling. Handles primitives, arrays, Sets, and
 * plain objects. Special object types (RezDie, Map, etc.) pass through unchanged.
 */
function normalizeRefs(value) {
  // Primitives pass through
  if(value === null || value === undefined || typeof value !== 'object') {
    return value;
  }

  // Check for pure ref: {$ref: "id"} with only that property
  if('$ref' in value && Object.keys(value).length === 1) {
    return value.$ref;
  }

  // Handle Arrays
  if(Array.isArray(value)) {
    return value.map(normalizeRefs);
  }

  // Handle Sets - must recreate
  if(value instanceof Set) {
    return new Set([...value].map(normalizeRefs));
  }

  // Handle plain objects - recurse into properties
  if(value.constructor === Object) {
    const result = {};
    for (const [k, v] of Object.entries(value)) {
      result[k] = normalizeRefs(v);
    }
    return result;
  }

  // Other object types (RezDie, Map, etc.) pass through unchanged
  return value;
}

/**
 * @class RezBasicObject
 * @category Internal
 * @description The foundational base class for all Rez game objects. Bridges Rez language
 * elements (defined in .rez source files) to living JavaScript objects at runtime.
 *
 * Every Rez element (@actor, @card, @scene, @item, etc.) extends this class. It provides:
 * - **Identity**: Unique IDs and element type tracking
 * - **Attributes**: Key-value store bridging Rez declarations to JS properties
 * - **Property Generation**: Automatic JS property creation from attributes
 * - **Initialization Lifecycle**: Three-phase object setup
 * - **Event System**: Handler dispatch for game logic
 * - **Persistence**: Save/load via change tracking
 * - **Template/Copying**: Runtime object instantiation from templates
 *
 * ## Initialization Lifecycle
 * Objects initialize in three phases via the `init()` method:
 * - **init_0**: Creates static properties (from declared attributes) and dynamic properties
 *   (ptable, property, bht, template types), then runs dynamic attribute initializers
 * - **init_1**: Applies mixins defined in the `$mixins` attribute
 * - **init_2**: Calls `elementInitializer()` for subclass-specific setup, then fires the
 *   'init' event (skipped for template objects)
 *
 * ## Property Generation
 * Attributes become JS properties automatically:
 * - `foo` → `obj.foo` (getter/setter backed by attribute)
 * - `bar_id` → `obj.bar` (dereferences ID to actual game object)
 * - `damage_die` → `obj.damage_roll` (rolls the RezDie and returns result)
 * - `ptable:` → weighted random selection property
 * - `property:` → computed property with custom getter
 * - `bht:` → behaviour tree instance
 * - `template:` → template function property
 *
 * ## Template Objects
 * Objects with `$template: true` are templates meant to be copied via `addCopy()` or
 * `copyWithAutoId()`, not used directly. Templates skip init_2 phase initialization.
 *
 * ## Persistence
 * The `changedAttributes` Set tracks every modified attribute. On save, `archiveInto()`
 * serializes only changed attributes (excluding those listed in `$no_archive`).
 * The `loadData()` method restores attributes from a saved archive.
 *
 * ## Static Game Reference
 * The static `game` property provides access to the singleton RezGame instance from
 * any game object via `this.game`.
 */
class RezBasicObject {
  static #game;

  #id;
  #element;
  #attributes;
  #changedAttributes;
  #initialized;

  /**
   * @function constructor
   * @memberof RezBasicObject#
   * @param {string} element - the Rez element type (e.g., "actor", "card", "scene")
   * @param {string} id - unique identifier for this object
   * @param {object} attributes - attribute key-value pairs from Rez compilation
   * @description Creates a new RezBasicObject. The attributes are normalized to collapse
   * any `{$ref: "id"}` objects to plain ID strings. The object starts uninitialized;
   * call `init()` to complete setup.
   */
  constructor(element, id, attributes) {
    this.#element = element;
    this.#id = id;
    this.#attributes = normalizeRefs(attributes);
    this.#changedAttributes = new Set();
    this.#initialized = false;
  }

  /**
   * @function game
   * @memberof RezBasicObject
   * @static
   * @param {RezGame} game - the game instance to set
   * @description Sets the static game reference shared by all RezBasicObject instances.
   * Called once during game initialization.
   */
  static set game(game) {
    RezBasicObject.#game = game;
  }

  /**
   * @function game
   * @memberof RezBasicObject
   * @static
   * @returns {RezGame} the singleton game instance
   * @description Gets the static game reference shared by all RezBasicObject instances.
   */
  static get game() {
    return RezBasicObject.#game;
  }

  /**
   * @function game
   * @memberof RezBasicObject#
   * @returns {RezGame} the singleton game instance
   * @description Instance accessor for the game. Delegates to the static game property.
   */
  get game() {
    return RezBasicObject.game;
  }

  /**
   * @function element
   * @memberof RezBasicObject#
   * @returns {string} the Rez element type (e.g., "actor", "card", "scene")
   * @description Returns the element type string that identifies what kind of Rez
   * element this object represents.
   */
  get element() {
    return this.#element;
  }

  /**
   * @function id
   * @memberof RezBasicObject#
   * @returns {string} the unique identifier for this object
   * @description Returns the unique ID assigned to this object. IDs are defined in Rez
   * source files (e.g., `@card my_card { ... }` creates an object with id "my_card").
   */
  get id() {
    return this.#id;
  }

  /**
   * @function ref
   * @memberof RezBasicObject#
   * @returns {{$ref: string}} a reference object containing this object's ID
   * @description Returns a reference object in the format `{$ref: "id"}`. This format
   * is used by the Rez compiler for element references and can be used for serialization.
   */
  get ref() {
    return {$ref: this.id};
  }

  /**
   * @function attributes
   * @memberof RezBasicObject#
   * @returns {object} the raw attributes object
   * @description Returns the internal attributes object. Prefer using `getAttribute()`,
   * `setAttribute()`, or property accessors rather than accessing this directly.
   */
  get attributes() {
    return this.#attributes;
  }

  /**
   * @function changedAttributes
   * @memberof RezBasicObject#
   * @returns {Set<string>} set of attribute names that have been modified
   * @description Returns the set of attribute names that have been changed since object
   * creation. Used by the persistence system to determine what needs to be saved.
   */
  get changedAttributes() {
    return this.#changedAttributes;
  }

  /**
   * @function isInitialized
   * @memberof RezBasicObject#
   * @returns {boolean} true if init() has completed
   * @description Returns whether this object has completed its initialization lifecycle.
   * Objects are not fully usable until initialization completes.
   */
  get isInitialized() {
    return this.#initialized;
  }

  /**
   * @function needsArchiving
   * @memberof RezBasicObject#
   * @returns {boolean} true if this object has changed attributes requiring save
   * @description Returns whether this object has any modified attributes that need to
   * be saved. Used by the persistence system to skip unchanged objects.
   */
  get needsArchiving() {
    return this.#changedAttributes.size > 0;
  }

  /**
   * @function archiveInto
   * @memberof RezBasicObject#
   * @param {object} archive - the archive object to write to
   * @description Serializes this object's changed attributes into the archive object.
   * Only attributes that have been modified (tracked in changedAttributes) are saved.
   * Attributes listed in the `$no_archive` attribute are excluded. Functions are
   * serialized with a special wrapper for later restoration.
   */
  archiveInto(archive) {
    if(this.needsArchiving) {
      const noArchive = this.getAttributeValue("$no_archive", new Set());
      archive[this.id] = [... this.#changedAttributes].reduce((archive, attrName) => {
        if(noArchive.has(attrName)) {
          return archive;
        }
        let value = this.getAttribute(attrName);
        if(typeof(value) === "function") {
          value = {
            json$safe: true,
            type: "function",
            value: value.toString()
          }
        }
        archive[attrName] = value;
        return archive;
      }, {});
    }
  }

  /**
   * @function loadData
   * @memberof RezBasicObject#
   * @param {object} attrs - attribute key-value pairs from a saved archive
   * @throws {Error} if attrs is not an object
   * @description Restores attributes from a saved archive. Handles special serialized
   * types like functions (wrapped with `json$safe` markers). Each attribute is set
   * using setAttribute, which triggers change tracking and observers.
   */
  loadData(attrs) {
    if(typeof attrs !== "object") {
      throw new Error("Attempting to load attributes from improper object!");
    }
    for (const [attrName, attrValue] of Object.entries(attrs)) {
      if(typeof(attrValue) === "object" && Object.hasOwn(attrValue, "json$safe")) {
        if(attrValue.type === "function") {
          const functionBody = attrValue.value;
          try {
            // Use the Function constructor to create a new function
            const restoredFunction = new Function(`return (${functionBody})`)();
            this.setAttribute(attrName, restoredFunction);
          } catch (error) {
            console.error(`Failed to restore function for attribute '${attrName}':`, error);
          }
        } else {
          console.error(`Failed to restore unknwon type for attribute '${attrName}' (${attrValue.type})`);
        }
      } else {
        this.setAttribute(attrName, attrValue);
      }
    }
  }

  /**
   * @function init
   * @memberof RezBasicObject#
   * @description Runs the complete three-phase initialization lifecycle for this object.
   * After init completes, `isInitialized` returns true. The phases are:
   * - init_0: Property creation and dynamic attribute initialization
   * - init_1: Mixin application
   * - init_2: Element-specific initialization and 'init' event
   */
  init() {
    this.init_0();
    this.init_1();
    this.init_2();
    this.#initialized = true;
  }

  /**
   * @function init_0
   * @memberof RezBasicObject#
   * @description Phase 0 of initialization: Creates all JavaScript properties from attributes.
   * First creates static properties (simple getter/setters for each attribute), then
   * creates dynamic properties for special attribute types (ptable, property, bht, template),
   * and finally runs dynamic attribute initializers in priority order.
   */
  init_0() {
    this.createStaticProperties();
    this.createDynamicProperties();
    this.initDynamicAttributes();
  }

  /**
   * @function init_1
   * @memberof RezBasicObject#
   * @description Phase 1 of initialization: Applies mixins. Iterates through the `$mixins`
   * attribute (an array of mixin IDs) and applies each mixin's properties and methods
   * to this object. Mixin properties use `createCustomProperty`, while mixin methods
   * are bound directly to this object.
   */
  init_1() {
    // Initialize Mixins
    for(const mixin_ref of this.getAttributeValue("$mixins", [])) {
      const mixin_id = (typeof mixin_ref === "object" && mixin_ref.$ref) ? mixin_ref.$ref : mixin_ref;
      const mixin = window.Rez.mixins[mixin_id];

      // Apply properties
      for(const [propName, propDef] of Object.entries(mixin)) {
        if(propDef.property) {
          this.createCustomProperty(propName, propDef);
        } else if(typeof propDef === 'function') {
          // Apply methods directly
          this[propName] = propDef.bind(this);
        }
      }
    }
  }

  /**
   * @function init_2
   * @memberof RezBasicObject#
   * @description Phase 2 of initialization: Element-specific setup and 'init' event.
   * Calls `elementInitializer()` for subclass-specific initialization, then fires
   * the 'init' event. This phase is skipped for template objects (those with
   * `$template: true`), since templates are not meant to be used directly.
   */
  init_2() {
    // Templates don't initialise like regular objects
    if(!this.isTemplateObject()) {
      this.elementInitializer();
      this.runEvent("init", {});
    }
  }

  /**
   * @function createStaticProperty
   * @memberof RezBasicObject#
   * @param {string} attrName - name of the attribute to create a corresponding property for
   * @description Creates a JavaScript property backed by a Rez attribute. The property
   * provides getter/setter access to the underlying attribute value via getAttribute/setAttribute.
   *
   * Additionally creates synthetic accessor properties for special attribute name patterns:
   * - Attributes ending in `_id` get a dereferenced accessor (e.g., `location_id` creates
   *   a `location` property that returns the actual game object, not just the ID)
   * - Attributes ending in `_die` get a roll accessor (e.g., `damage_die` creates a
   *   `damage_roll` property that returns the result of rolling the die)
   */
  createStaticProperty(attrName) {
    Object.defineProperty(this, attrName, {
      get: function () {
        return this.getAttribute(attrName);
      },
      set: function (value) {
        this.setAttribute(attrName, value);
      },
      configurable: true,
    });

    if(attrName.endsWith("_id")) {
      const directAttrName = attrName.slice(0, -3);
      Object.defineProperty(this, directAttrName, {
        get: function () {
          const ref_id = this.getAttribute(attrName);
          return $(ref_id);
        },
        set: function (ref) {
          if(ref?.id == null) {
            throw new Error("Cannot assign an empty ID ref");
          }
          this.setAttribute(attrName, ref.id);
        },
      });
    } else if(attrName.endsWith("_die")) {
      const directAttrName = attrName.slice(0, -4);
      const syntheticAttrName = `${directAttrName}_roll`;
      Object.defineProperty(this, syntheticAttrName, {
        get: function() {
          const attr = this.getAttribute(attrName);
          return attr.roll();
        }
      })
    }
  }

  /**
   * @function createStaticProperties
   * @memberof RezBasicObject#
   * @description Iterates through all declared attributes and calls `createStaticProperty`
   * for each one, creating JavaScript property accessors for the entire attribute set.
   */
  createStaticProperties() {
    for(const [attrName, _] of Object.entries(this.attributes)) {
      this.createStaticProperty(attrName);
    }
  }

  /**
   * @function createDynamicProperties
   * @memberof RezBasicObject#
   * @description Creates synthetic properties for special attribute types that require
   * custom behavior beyond simple getter/setter access. Handles:
   * - `ptable:` - probability tables for weighted random selection
   * - `property:` - computed properties with custom getter functions
   * - `bht:` - behaviour tree instances
   * - `template:` - template function properties
   *
   * Skipped for template objects since they don't need runtime property initialization.
   */
  createDynamicProperties() {
    if(this.getAttributeValue("$template", false)) {
      return;
    }

    for (const attrName of Object.keys(this.attributes)) {
      const value = this.getAttribute(attrName);
      if(typeof value === "object") {
        if(Object.hasOwn(value, "ptable")) {
          this.createProbabilityTable(attrName, value);
        } else if(Object.hasOwn(value, "property")) {
          this.createCustomProperty(attrName, value);
        } else if(Object.hasOwn(value, "bht")) {
          this.createBehaviourTreeAttribute(attrName, value);
        } else if(Object.hasOwn(value, "template")) {
          this.createTemplateProperty(attrName, value);
        }
      }
    }
  }

  /**
   * @function createTemplateProperty
   * @memberof RezBasicObject#
   * @param {string} attrName - name of the template attribute
   * @param {object} value - attribute value containing the template function
   * @description Creates a property for a template function attribute. The template
   * function is assigned directly to the object. For system template attributes
   * (those matching `$*_template` pattern), also creates a convenience accessor
   * that evaluates the template with `this` bound to the object.
   */
  createTemplateProperty(attrName, value) {
    const template_fn = value.template;
    this[attrName] = template_fn;

    // Regular templates get compiled to an attribute
    // $<attr_name>_template
    // and this is what RezView expects for layout:
    // and content: attributes. However we can unwrap
    // this for regular attributes and bind 'self' to
    // the object in question.
    if(attrName.startsWith("$") && attrName.endsWith("_template")) {
      const directAttrName = attrName.slice(1, -9);

      Object.defineProperty(this, directAttrName, {
        get: function() {
          const templateFn = this.getAttribute(attrName);
          const bindings = {
            self: this
          };
          return templateFn(bindings);
        }
      })
    }
  }

  /**
   * @function initDynamicAttributes
   * @memberof RezBasicObject#
   * @description Initializes dynamic attributes that require runtime computation. Processes
   * three types of dynamic attributes in order:
   * 1. `$copy` attributes - creates copies of template objects
   * 2. `$delegate` attributes - creates delegate properties to other objects
   * 3. `initializer` attributes - runs initialization functions
   *
   * Attributes are processed in priority order (1-10, as set by the compiler) to ensure
   * dependencies are satisfied. Skipped for template objects.
   */
  initDynamicAttributes() {
    if(this.getAttributeValue("$template", false)) {
      return;
    }

    // Priority is fixed by the Rez compiler to be between 1 & 10
    const dyn_initializers = [[], [], [], [], [], [], [], [], [], []];
    const copy_initializers = [[], [], [], [], [], [], [], [], [], []];
    const delegates = [];

    for(const attrName of Object.keys(this.attributes)) {
      const value = this.getAttribute(attrName);
      if(typeof value === "object") {
        if(Object.hasOwn(value, "initializer")) {
          const prio = parseInt(value.priority, 10);
          dyn_initializers[prio-1].push([attrName, value]);
        } else if(Object.hasOwn(value, "$copy")) {
          const prio = parseInt(value.priority, 10);
          copy_initializers[prio-1].push([attrName, value]);
        } else if(Object.hasOwn(value, "$delegate")) {
          delegates.push([attrName, value.$delegate]);
        }
      }
    }

    copy_initializers.flat().forEach(
      ([attrName, elem_ref]) => {
        this.createAttributeByCopying(attrName, elem_ref);
      }
    );

    delegates.forEach(
      ([attrName, targetAttr]) => {
        this.createDelegateProperty(attrName, targetAttr);
      }
    );

    dyn_initializers.flat().forEach(
      ([attrName, value]) => {
        this.createDynamicallyInitializedAttribute(attrName, value);
      }
    );
  }

  /**
   * @function createProbabilityTable
   * @memberof RezBasicObject#
   * @param {string} attrName - name of the ptable attribute
   * @param {object} value - attribute value containing the ptable JSON
   * @description Creates a probability table property for weighted random selection.
   * The ptable is an array of [value, cumulative_probability] pairs. Accessing the
   * property returns a randomly selected value based on the weights.
   *
   * Also creates a `<attrName>_roll` property that returns both the random probability
   * and the selected value as `{p: number, obj: any}`.
   */
  createProbabilityTable(attrName, value) {
    delete this[attrName];

    const pTable = JSON.parse(value.ptable);

    Object.defineProperty(this, attrName, {
      get: () => {
        const p = Math.random();
        const idx = pTable.findIndex((pair) => p <= pair[1]);
        if(idx === -1) {
          throw new Error("Invalid p_table. Must contain range 0<n<1");
        }

        return pTable[idx][0];
      },
    });

    Object.defineProperty(this, `${attrName}_roll`, {
      get: () => {
        const p = Math.random();
        const idx = pTable.findIndex((pair) => p <= pair[1]);
        if(idx === -1) {
          throw new Error("Invalid p_table. Must contain range 0<n<1");
        }

        return { p: p, obj: pTable[idx][0] };
      },
    });
  }

  /**
   * @function createCustomProperty
   * @memberof RezBasicObject#
   * @param {string} attrName - name of the property to create
   * @param {object} value - attribute value containing the property getter source code
   * @description Creates a computed property with a custom getter function. The `property`
   * field contains JavaScript source code that becomes the getter body. The getter
   * executes with `this` bound to the object.
   */
  createCustomProperty(attrName, value) {
    delete this[attrName];
    Object.defineProperty(this, attrName, {get: new Function(value.property)});
  }

  /**
   * @function createDynamicallyInitializedAttribute
   * @memberof RezBasicObject#
   * @param {string} attrName - name of the attribute to initialize
   * @param {object|RezDie} value - initializer specification or RezDie instance
   * @description Initializes an attribute with a computed value at runtime. If the value
   * is a RezDie, rolls it and stores the result. Otherwise, executes the `initializer`
   * field as JavaScript code with `this` bound to the object, and stores the result.
   * The attribute is set without notifying observers (third parameter is false).
   */
  createDynamicallyInitializedAttribute(attrName, value) {
    if(value.constructor === RezDie) {
      this.setAttribute(attrName, value.roll(), false);
    } else {
      const initializerFn = new Function(value.initializer);
      this.setAttribute(attrName, initializerFn.call(this), false);
    }
  }

  /**
   * @function createAttributeByCopying
   * @memberof RezBasicObject#
   * @param {string} attrName - name of the attribute to set
   * @param {object} value - object containing `$copy` field with source element reference
   * @description Creates an attribute by copying a template object. Looks up the source
   * element via the `$copy` reference, creates a copy of it using `addCopy()`, and
   * stores the new copy's ID in this attribute.
   */
  createAttributeByCopying(attrName, value) {
    const elem_ref = value.$copy;
    const source = $(elem_ref);
    this.setAttribute(attrName, source.addCopy().id);
  }

  /**
   * @function createDelegateProperty
   * @memberof RezBasicObject#
   * @param {string} attrName - name of the attribute to create a delegate property for
   * @param {string} targetAttr - name of the attribute that holds a reference to the delegate target
   * @description Creates a read-only property that delegates to the corresponding property of
   * the referenced element. For example, if targetAttr is "hull", this will look up this.hull
   * (which is the dereferenced element from hull_id) and return its attrName property.
   */
  createDelegateProperty(attrName, targetAttr) {
    delete this[attrName];
    Object.defineProperty(this, attrName, {
      get: function() {
        const target = this[targetAttr];
        if(target == null) {
          return undefined;
        }
        const value = target[attrName];
        if(typeof value === "function") {
          return value.bind(target);
        }
        return value;
      },
      configurable: true
    });
  }

  /**
   * @function createBehaviourTreeAttribute
   * @memberof RezBasicObject#
   * @param {string} attrName - name of the behaviour tree attribute
   * @param {object} value - attribute value containing the bht specification
   * @description Creates a read-only property that returns an instantiated behaviour tree.
   * The tree is created once during initialization and cached. Uses `instantiateBehaviourTree`
   * to recursively build the tree structure.
   */
  createBehaviourTreeAttribute(attrName, value) {
    delete this[attrName];

    const tree = this.instantiateBehaviourTree(value.bht);
    Object.defineProperty(this, attrName, {
      get: () => tree
    });
  }

  /**
   * @function instantiateBehaviourTree
   * @memberof RezBasicObject#
   * @param {object} treeSpec - behaviour tree specification with behaviour, options, and children
   * @returns {RezBehaviour} instantiated behaviour tree node
   * @description Recursively instantiates a behaviour tree from a specification object.
   * Each node references a behaviour template by ID, has options, and may have child nodes.
   * Child specifications are recursively instantiated before the parent.
   */
  instantiateBehaviourTree(treeSpec) {
    const behaviour_template = $(treeSpec.behaviour, true);
    const options = treeSpec.options;
    const children = treeSpec.children.map((spec) => this.instantiateBehaviourTree(spec));

    return behaviour_template.instantiate(this, options, children);
  }

  /**
   * @function elementInitializer
   * @memberof RezBasicObject#
   * @description Hook method for subclass-specific initialization. Called during init_2
   * phase before the 'init' event fires. Subclasses (RezActor, RezScene, etc.) override
   * this method to perform element-type-specific setup. The base implementation is empty.
   */
  elementInitializer() {}

  /**
   * @function addToGame
   * @memberof RezBasicObject#
   * @returns {RezBasicObject} this object for method chaining
   * @description Registers this object with the game world by calling `$game.addGameObject()`.
   * This makes the object accessible via the `$()` lookup function and indexes it by tags.
   */
  addToGame() {
    $game.addGameObject(this);
    return this;
  }

  /**
   * @function copyAssigningId
   * @memberof RezBasicObject#
   * @param {string} id the id to assign to the copy
   * @description creates a copy of this object. If this object has `$template: true` the copy will have `$template: false`. The copy will also be assigned a new attribute `$original_id` containing the id of this object.
   * @returns {object} copy of the current object
   */
  copyAssigningId(id) {
    const attributes = this.attributes.copy();
    // Subclasses override the RezBasicElement constructor
    const copy = new this.constructor(id, attributes);
    copy.setAttribute("$auto_id_idx", 0, false);
    copy.setAttribute("$template", false, false);
    copy.setAttribute("$original_id", this.id, false);
    copy.init();
    copy.runEvent("copy", { original: this });
    return copy;
  }

  /**
   * @function getNextAutoId
   * @memberof RezBasicObject#
   * @description returns the next auto id in the sequence
   */
  getNextAutoId() {
    const lastId = this.getAttribute("$auto_id_idx");
    const nextId = lastId + 1;
    this.setAttribute("$auto_id_idx", nextId);
    return `${this.id}_${nextId}`;
  }

  /**
   * @function copyWithAutoId
   * @memberof RezBasicObject#
   * @description creates a copy of this object that is assigned an ID automatically. In all other respects its behaviour is identical to `copyAssigningId`
   * Copies an object with an auto-generated ID
   */
  copyWithAutoId() {
    return this.copyAssigningId(this.getNextAutoId());
  }

  /**
   * @function addCopy
   * @memberof RezBasicObject#
   * @param {string} copyId - id to assign to the object copy
   * @description create a copy of this object with the specified, rather than autogenerated, id
   */
  addCopy(copyId) {
    const copy = copyId === undefined ? this.copyWithAutoId() : this.copyAssigningId(copyId);
    return copy.addToGame();
  }

  /**
   * @function unmap
   * @memberof RezBasicObject#
   * @returns {RezBasicObject} this object for method chaining
   * @description Removes this object from the game world by calling `$game.unmapObject()`.
   * After unmapping, the object is no longer accessible via the `$()` lookup function
   * and is removed from tag indexes. Use this for cleanup when an object is no longer needed.
   */
  unmap() {
    $game.unmapObject(this);
    return this;
  }

  /**
   * @function unmap_attr
   * @memberof RezBasicObject#
   * @param {string} attr_name - name of an `_id` attribute referencing another object
   * @throws {Error} if attr_name doesn't end with "_id"
   * @throws {Error} if the attribute is not defined on this object
   * @description Unmaps a related object referenced by an `_id` attribute. First nulls
   * the attribute on this object, then unmaps the referenced object from the game.
   * Use this to clean up owned/related objects when they should be removed.
   */
  unmap_attr(attr_name) {
    if(!attr_name.endsWith("_id")) {
      throw new Error("Cannot unmap attributes that do not relate to an element id!");
    }

    if(!Object.hasOwn(this, attr_name)) {
      throw new Error("Cannot unmap attribute not defined on this object!");
    }

    const related_obj = $(this[attr_name], true);

    this[attr_name] = null;
    related_obj.unmap();
  }

  /**
   * @function isTemplateObject
   * @memberof RezBasicObject#
   * @description returns the value of the `$template` attribute
   * @returns {boolean} true if this object has a $template attribute with value true
   */
  isTemplateObject() {
    return this.getAttributeValue("$template", false);
  }

  /**
   * @function eventHandler
   * @memberof RezBasicObject#
   * @param {string} event_name name of the event whose handler should be returned
   * @returns {function|undefined} event handle function or undefined
   * @description Returns the event handler function stored in attribute "on_<event_name>" or undefined if no handler is present
   */
  eventHandler(eventName) {
    return this[`on_${eventName}`];
  }

  /**
   * @function willHandleEvent
   * @memberof RezBasicObject#
   * @param {string} event_name name of the event to check for a handler, e.g. "speak"
   * @returns {boolean} true if this object handles the specified event
   * @description Returns `true` if this object defines an event handler function for the given event_name
   */
  willHandleEvent(eventName) {
    const handler = this.eventHandler(eventName);
    const doesHandleEvent = handler != null && typeof handler === "function";
    return doesHandleEvent;
  }

  /**
   * @function runEvent
   * @memberof RezBasicObject#
   * @param {string} event_name name of the event to run, e.g. "speak"
   * @param {object} params object containing event params
   * @returns {*|boolean} returns a response object, or false if the event was not handled
   * @description attempts to run the event handler function for the event name, passing the specified params to the handler
   */
  runEvent(eventName, params) {
    if(RezBasicObject.game.$debug_events) {
      console.log(`Run on_${eventName} handler on '${this.id}'`);
    }
    const handler = this.eventHandler(eventName);
    if(handler != null && typeof handler === "function") {
      return handler(this, params);
    } else {
      return false;
    }
  }

  /**
   * @function hasAttribute
   * @memberof RezBasicObject#
   * @param {string} name name of the attribute
   * @returns {boolean} true if the object defines the specified attribute
   */
  hasAttribute(attrName) {
    return Object.hasOwn(this.attributes, attrName);
  }

  /**
   * @function getAttribute
   * @memberof RezBasicObject#
   * @param {string} name name of the attribute
   * @returns {*} attribute value
   * @description returns the value of the attribute with the given name. If no such attribute is present returns `undefined`
   */
  getAttribute(name) {
    const attr = this.attributes[name];
    return attr;
  }

  /**
   * @function getAttributeValue
   * @memberof RezBasicObject#
   * @param {string} name name of the attribute
   * @param {*} default_value value to return if no such attribute is present
   * @returns {*} attribute value
   * @description returns the value of the attribute with the given name. If no such value is present it returns the default value. If no default value is given it throws an exception.
   */
  getAttributeValue(name, defaultValue) {
    const attr = this.getAttribute(name);
    if(typeof attr === "undefined") {
      if(typeof defaultValue === "undefined") {
        throw new Error(`Attempt to get value of attribute |${name}| which is not defined on |${this.id}|`);
      } else {
        return defaultValue;
      }
    } else if(typeof attr === "function") {
      return attr(this);
    } else if(attr.constructor === RezDie) {
      return attr.roll();
    } else {
      return attr;
    }
  }

  /**
   * @function getObjectViaAttribute
   * @memberof RezBasicObject#
   * @param {string} name - attribute name containing an object ID
   * @param {*} defaultValue - default ID to use if attribute is not defined
   * @returns {RezBasicObject} the game object referenced by the attribute
   * @description Retrieves a game object by looking up its ID from an attribute value.
   * Useful for following ID references to get the actual object.
   */
  getObjectViaAttribute(name, defaultValue) {
    const id = this.getAttributeValue(name, defaultValue);
    return this.game.getGameObject(id);
  }

  /**
   * @function setAttribute
   * @memberof RezBasicObject#
   * @param {string} attr_name name of attribute to set
   * @param {*} new_value value for attribute
   * @param {boolean} notify_observers whether observers should be notified that the value has changed
   */
  setAttribute(attrName, newValue, notifyObservers = true) {
    if(typeof newValue === "undefined") {
      throw new Error(`Call to setAttribute(${attrName}, …) with undefined value!`);
    }

    const oldValue = this.attributes[attrName];
    this.attributes[attrName] = newValue;
    this.changedAttributes.add(attrName);

    if(notifyObservers) {
      this.runEvent("attr_change", {attrName: attrName, oldValue: oldValue, newValue: newValue});
      this.game.elementAttributeHasChanged(
        this,
        attrName,
        oldValue,
        newValue
      );
    }
  }

  /**
   * @function hasTag
   * @memberof RezBasicObject#
   * @param {string} tag - the tag to check for
   * @returns {boolean} true if this object has the specified tag
   * @description Checks whether this object has the specified tag in its `tags` attribute.
   */
  hasTag(tag) {
    return this.getAttribute("tags").has(tag);
  }

  /**
   * @function addTag
   * @memberof RezBasicObject#
   * @param {string} tag - the tag to add
   * @description Adds a tag to this object's `tags` attribute and updates the game's
   * tag index so this object can be found via `$game.getObjectsWithTag()`.
   */
  addTag(tag) {
    let tags = this.getAttribute("tags");
    if(!tags) {
      tags = new Set([tag]);
    } else {
      tags.add(tag);
    }

    this.setAttribute("tags", tags);
    this.game.indexObjectForTag(this, tag);
  }

  /**
   * @function removeTag
   * @memberof RezBasicObject#
   * @param {string} tag - the tag to remove
   * @description Removes a tag from this object's `tags` attribute and updates the game's
   * tag index so this object is no longer found via `$game.getObjectsWithTag()`.
   */
  removeTag(tag) {
    let tags = this.getAttribute("tags");
    if(!tags) {
      tags = new Set();
    } else {
      tags.delete(tag);
    }

    this.setAttribute("tags", tags);
    this.game.unindexObjectForTag(this, tag);
  }

  /**
   * @function setTags
   * @memberof RezBasicObject#
   * @param {Set|Array} newTags - the complete set of tags this object should have
   * @description Replaces this object's tags with the specified set. Computes the
   * difference between old and new tags, removing tags that are no longer present
   * and adding new tags. Updates the game's tag index accordingly.
   */
  setTags(newTags) {
    newTags = new Set(newTags); // Just in case they are passed as an array
    const oldTags = this.getAttributeValue("tags", new Set());

    const tagsToRemove = oldTags.difference(newTags);
    tagsToRemove.forEach((tag) => {
      this.removeTag(tag);
    });

    const tagsToAdd = newTags.difference(oldTags);
    tagsToAdd.forEach((tag) => {
      this.addTag(tag);
    });
  }

  /**
   * @function getRelationshipWith
   * @memberof RezBasicObject#
   * @param {string} targetId - ID of the target object
   * @returns {RezRelationship|undefined} the relationship object, or undefined if none exists
   * @description Retrieves the relationship from this object to another object.
   * Relationships are unidirectional - the relationship from A to B is distinct
   * from the relationship from B to A. Use `relationship.inverse` to get the
   * reverse direction.
   */
  getRelationshipWith(targetId) {
    return this.game.getRelationship(this.id, targetId);
  }

  /**
   * @function applyEffect
   * @memberof RezBasicObject#
   * @param {string} effectId - ID of the effect to apply
   * @param {string} slotId - ID of the inventory slot the item is in
   * @param {string} itemId - ID of the item providing the effect
   * @description Hook method for applying an effect to this object. The base implementation
   * only logs the request. Subclasses (particularly RezActor) should override this to
   * actually apply the effect's modifications.
   */
  applyEffect(effectId, slotId, itemId) {
    console.log(`Apply effect |${effectId}| of item |${itemId}| in slot ${slotId} to |${this.id}|`);
  }

  /**
   * @function removeEffect
   * @memberof RezBasicObject#
   * @param {string} effectId - ID of the effect to remove
   * @param {string} slotId - ID of the inventory slot the item was in
   * @param {string} itemId - ID of the item that provided the effect
   * @description Hook method for removing an effect from this object. The base implementation
   * only logs the request. Subclasses (particularly RezActor) should override this to
   * actually remove the effect's modifications.
   */
   removeEffect(effectId, slotId, itemId) {
    console.log(`Remove effect |${effectId}| of item |${itemId}| in slot ${slotId} to |${this.id}|`);
  }
}

const _placeHolderValue = new RezBasicObject("placeholder", "$place_holder_value", {});

window.Rez.RezBasicObject = RezBasicObject;
