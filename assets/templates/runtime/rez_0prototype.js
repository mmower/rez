class RezBasicObject {
  static #game;

  #id;
  #element;
  #attributes;
  #changedAttributes;
  #initialized;

  constructor(element, id, attributes) {
    this.#element = element;
    this.#id = id;
    this.#attributes = attributes;
    this.#changedAttributes = [];
    this.#initialized = false;
  }

  static set game(game) {
    RezBasicObject.#game = game;
  }

  static get game() {
    return RezBasicObject.#game;
  }

  get game() {
    return RezBasicObject.game;
  }

  get element() {
    return this.#element;
  }

  get id() {
    return this.#id;
  }

  get attributes() {
    return this.#attributes;
  }

  set attributes(newAttributes) {
    this.#attributes = newAttributes;
  }

  get changedAttributes() {
    return this.#changedAttributes;
  }

  set id(new_id) {
    this.#id = new_id;
  }

  get initialized() {
    return this.#initialized;
  }

  set initialized(value) {
    this.#initialized = value;
  }

  initAll() {
    for (let initLevel of this.game.initLevels()) {
      this.init(initLevel);
    }
  }

  init(level) {
    const initMethod = `init${level}`;
    if (typeof this[initMethod] == "function") {
      this[initMethod]();
    }
  }

  init0() {
    this.createStaticProperties();
    this.createDynamicProperties();
  }

  init1() {
    this.initDynamicAttributes();
  }

  init2() {
    // Templates don't initialise like regular objects
    if (!this.isTemplateObject()) {
      this.elementInitializer();
      this.runEvent("init", {});
    }
  }

  init3() {
    this.initialised = true;
  }

  /**
   * @function createStaticProperty
   * @memberof basic_object
   * @param {string} attr_name - name of the attribute to create a corresponding property for
   * @description use this to create a JS property backed by a Rez attribute
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

    if (attrName.endsWith("_id")) {
      const directAttrName = attrName.slice(0, -3);
      Object.defineProperty(this, directAttrName, {
        get: function () {
          const ref_id = this.getAttribute(attrName);
          return $(ref_id);
        },
        set: function (ref) {
          if(ref === null || typeof(ref.id) === "undefined") {
            throw new Error("Cannot assign an empty ID ref");
          }
          this.setAttribute(attrName, ref.id);
        },
      });
    }
  }

  /**
   * @function createStaticProperties
   * @memberof basic_object
   * @description uses basic_object.createStaticProperty to create static properties for all of the objects declared Rez attributes
   */
  createStaticProperties() {
    for (let [attrName, _] of Object.entries(this.attributes)) {
      this.createStaticProperty(attrName);
    }
  }

  /**
   * @function createDynamicProperties
   * @memberof basic_object
   * @description creates synthetic properties to represent dynamic attributes types such as `ptable` and `tracery_grammar`.
   */
  createDynamicProperties() {
    if (this.getAttributeValue("$template", false)) {
      return;
    }

    for (let attrName of Object.keys(this.attributes)) {
      const value = this.getAttribute(attrName);
      if (typeof value == "object") {
        if (value.hasOwnProperty("ptable")) {
          this.createProbabilityTable(attrName, value);
        } else if (value.hasOwnProperty("property")) {
          this.createCustomProperty(attrName, value);
        } else if (value.hasOwnProperty("attr_ref")) {
          this.createReferenceAttribute(attrName, value);
        } else if (value.hasOwnProperty("dynamic_value")) {
          this.createDynamicValueAttribute(attrName, value);
        } else if (value.hasOwnProperty("tracery_grammar")) {
          this.createTraceryGrammarAttribute(attrName, value);
        } else if (value.hasOwnProperty("bht")) {
          this.createBehaviourTreeAttribute(attrName, value);
        }
      }
    }
  }

  initDynamicAttributes() {
    if(this.getAttributeValue("$template", false)) {
      return;
    }

    for(let attrName of Object.keys(this.attributes)) {
      const value = this.getAttribute(attrName);
      if(typeof value == "object") {
        if(value.hasOwnProperty("initializer")) {
          this.createDynamicallyInitializedAttribute(attrName, value);
        }
      }
    }
  }

  createProbabilityTable(attrName, value) {
    delete this[attrName];

    const pTable = JSON.parse(value["ptable"]);

    Object.defineProperty(this, attrName, {
      get: function () {
        const p = Math.random();
        const idx = pTable.findIndex((pair) => p <= pair[1]);
        if (idx == -1) {
          throw new Error("Invalid p_table. Must contain range 0<n<1");
        }

        return pTable[idx][0];
      },
    });

    Object.defineProperty(this, `${attrName}_roll`, {
      get: function () {
        const p = Math.random();
        const idx = pTable.findIndex((pair) => p <= pair[1]);
        if(idx == -1) {
          throw new Error("Invalid p_table. Must contain range 0<n<1");
        }

        return { p: p, obj: pTable[idx][0] };
      },
    });
  }

  createCustomProperty(attrName, value) {
    delete this[attrName];
    const propertyDef = value["property"];
    const propertySrc = `function() {${propertyDef}}`;
    eval(`Object.defineProperty(this, "${attrName}", {get: ${propertySrc}})`);
  }

  createDynamicallyInitializedAttribute(attrName, value) {
    if(value.constructor == RezDie) {
      this.setAttribute(attrName, value.roll(), false);
    } else {
      const initializer = value["initializer"];
      this.setAttribute(attrName, eval(initializer), false);
    }
  }

  createReferenceAttribute(attrName, value) {
    delete this[attrName];
    const ref = value["attr_ref"];

    Object.defineProperty(this, attrName, {
      get: function () {
        return $(ref.elem_id).getAttributeValue(ref.attrName);
      },
    });
  }

  createDynamicValueAttribute(attrName, value) {
    delete this[attrName];

    const valGen = value["dynamic_value"];
    const src = `(${this.id}) => {return ${valGen};}`;
    const f = eval(src);
    Object.defineProperty(this, attrName, {
      get: function () {
        return f(this);
      },
    });
  }

  createBehaviourTreeAttribute(attrName, value) {
    delete this[attrName];

    const tree = this.instantiateBehaviourTree(value["bht"]);
    Object.defineProperty(this, attrName, {
      get: function() {
        return tree;
      }
    });
  }

  instantiateBehaviourTree(treeSpec) {
    const behaviour_template = $(treeSpec["behaviour"], true);
    const options = treeSpec["options"];
    const children = treeSpec["children"].map((spec) => this.instantiateBehaviourTree(spec));

    return behaviour_template.instantiate(this, options, children);
  }

  createTraceryGrammarAttribute(attrName, value) {
    delete this[attrName];

    const grammar = tracery.createGrammar(JSON.parse(value.tracery_grammar));
    grammar.addModifiers(tracery.baseEngModifiers);

    Object.defineProperty(this, attrName, {
      get: function () {
        return grammar.flatten("#origin#");
      },
    });
  }

  /**
   * @function elementInitializer
   * @memberof basic_object
   * @description objects using basic_object as a prototype should define their own elementInitializer function to handle any element-specific initialization
   */
  elementInitializer() {}

  /**
   * @function copyAssigningId
   * @memberof basic_object
   * @param {string} id the id to assign to the copy
   * @description creates a copy of this object. If this object has `$template: true` the copy will have `$template: false`. The copy will also be assigned a new attribute `$original_id` containing the id of this object.
   * @returns {object} copy of the current object
   */
  copyAssigningId(id) {
    const attributes = this.attributes.copy();
    const copy = new this.constructor(id, attributes);
    copy.setAttribute("$auto_id_idx", 0, false);
    copy.setAttribute("$template", false, false);
    copy.setAttribute("$original_id", this.id, false);
    copy.initAll();
    copy.runEvent("copy", { original: this });
    return copy;
  }

  /**
   * @function getNextAutoId
   * @memberof basic_object
   * @description returns the next auto id in the sequence
   */
  getNextAutoId() {
    const lastId = this.getAttribute("$auto_id_idx");
    const nextId = lastId + 1;
    this.setAttribute("$auto_id_idx", nextId);
    return this.id + "_" + nextId;
  }

  /**
   * @function copyWithAutoId
   * @memberof basic_object
   * @description creates a copy of this object that is assigned an ID automatically. In all other respects its behaviour is identical to `copyAssigningId`
   * Copies an object with an auto-generated ID
   */
  copyWithAutoId() {
    return this.copyAssigningId(this.getNextAutoId());
  }

  /**
   * @function isTemplateObject
   * @memberof basic_object
   * @description returns the value of the `$template` attribute
   * @returns {boolean} true if this object has a $template attribute with value true
   */
  isTemplateObject() {
    return this.getAttributeValue("$template", false);
  }

  /**
   * @function eventHandler
   * @memberof basic_object
   * @param {string} event_name name of the event whose handler should be returned
   * @returns {function|undefined} event handle function or undefined
   * @description Returns the event handler function stored in attribute "on_<event_name>" or undefined if no handler is present
   */
  eventHandler(eventName) {
    return this.getAttribute(`on_${eventName}`);
  }

  /**
   * @function willHandleEvent
   * @memberof basic_object
   * @param {string} event_name name of the event to check for a handler, e.g. "speak"
   * @returns {boolean} true if this object handles the specified event
   * @description Returns `true` if this object defines an event handler function for the given event_name
   */
  willHandleEvent(eventName) {
    const handler = this.eventHandler(eventName);
    const doesHandleEvent = handler != null && typeof handler == "function";
    return doesHandleEvent;
  }

  /**
   * @function runEvent
   * @memberof basic_object
   * @param {string} event_name name of the event to run, e.g. "speak"
   * @param {object} params object containing event params
   * @returns {*|boolean} returns a response object, or false if the event was not handled
   * @description attempts to run the event handler function for the event name, passing the specified params to the handler
   */
  runEvent(eventName, params) {
    console.log("Run on_" + eventName + " handler on " + this.id);
    let handler = this.eventHandler(eventName);
    if(handler != null && typeof handler == "function") {
      return handler(this, params);
    } else {
      return false;
    }
  }

  /**
   * @function hasAttribute
   * @memberof basic_object
   * @param {string} name name of the attribute
   * @returns {boolean} true if the object defines the specified attribute
   */
  hasAttribute(attrName) {
    return this.attributes.hasOwnProperty(attrName);
  }

  /**
   * @function getAttribute
   * @memberof basic_object
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
   * @memberof basic_object
   * @param {string} name name of the attribute
   * @param {*} default_value value to return if no such attribute is present
   * @returns {*} attribute value
   * @description returns the value of the attribute with the given name. If no such value is present it returns the default value. If no default value is given it throws an exception.
   */
  getAttributeValue(name, defaultValue) {
    const attr = this.getAttribute(name);
    if(typeof attr == "undefined") {
      if(typeof defaultValue == "undefined") {
        throw new Error(`Attempt to get value of attribute |${this.name}| which is not defined on |${this.id}|`);
      } else {
        return defaultValue;
      }
    } else if(typeof attr == "function") {
      return attr(this);
    } else if(attr.constructor == RezDie) {
      return attr.roll();
    } else {
      return attr;
    }
  }

  /**
   * @function getObjectViaAttribute
   * @memberof basic_object
   * @param {string} name attribute name
   * @param {*} default_value
   */
  getObjectViaAttribute(name, defaultValue) {
    const id = this.getAttributeValue(name, defaultValue);
    return this.game.getGameObject(id);
  }

  /**
   * @function setAttribute
   * @memberof basic_object
   * @param {string} attr_name name of attribute to set
   * @param {*} new_value value for attribute
   * @param {boolean} notify_observers whether observers should be notified that the value has changed
   */
  setAttribute(attrName, newValue, notifyObservers = true) {
    if(typeof newValue == "undefined") {
      throw new Error(`Call to setAttribute(${attrName}, …) with undefined value!`);
    }

    const oldValue = this.attributes[attrName];
    this.attributes[attrName] = newValue;
    this.changedAttributes.push(attrName);
    if(notifyObservers) {
      this.game.elementAttributeHasChanged(
        this,
        attrName,
        oldValue,
        newValue
      );
    }
  }

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
   * @memberof basic_object
   * @param {set} tags tags the object should have after the call
   */
  setTags(newTags) {
    newTags = new Set(newTags); // Just in case they are passed as an array
    const oldTags = this.getAttributeValue("tags", new Set());

    const tagsToRemove = oldTags.difference(newTags);
    tagsToRemove.forEach((tag) => this.removeTag(tag));

    const tagsToAdd = newTags.difference(oldTags);
    tagsToAdd.forEach((tag) => this.addTag(tag));
  }

  getRelationshipWith(targetId) {
    return this.game.getRelationship(this.id, targetId);
  }

  /**
   * @function applyEffect
   * @memberof basic_object
   * @param {string} effect_id
   * @param {string} slot_id
   * @param {string} item_id
   */
  applyEffect(effectId, slotId, itemId) {
    console.log(
      "Been asked to apply effect |" +
        effectId +
        "| from item |" +
        itemId +
        "| to |" +
        this.id +
        "|"
    );
  }

  /**
   * @function removeEffect
   * @memberof basic_object
   * @param {string} effect_id
   * @param {string} slotId
   *itemId {string} item_id
   */
   removeEffect(effectId, slotId, itemId) {
    console.log(
      "Been asked to remove effect |" +
        effectId +
        "| from item |" +
        itemId +
        "| to |" +
        this.id +
        "|"
    );
  }

  /**
   * @function needsArchiving
   * @memberof basic_object
   * @returns {boolean} true if this object requires archiving
   */
  needsArchiving() {
    return this.#changedAttributes.length > 0;
  }

  archiveDataContainer() {
    return {
      id: this.id,
      element: this.element,
    };
  }

  dataWithArchivedAttributes(data) {
    const obj = this;
    return this.#changedAttributes.reduce(function (data, key) {
      data["attrs"] = data["attrs"] || {};
      data["attrs"][key] = obj.getAttribute(key);
      return data;
    }, data);
  }

  toJSON() {
    let data = this.archiveDataContainer();
    data = this.dataWithArchivedAttributes(data);
    return data;
  }

  loadData(data) {
    const attrs = data["attrs"];
    if (typeof attrs == "object") {
      for (const [k, v] of Object.entries(attrs)) {
        this.setAttribute(k, v);
      }
    }
  }
}

const noValue = new RezBasicObject("nothing", "nothing", {});

window.Rez ??= {};
window.Rez.RezBasicObject = RezBasicObject;
