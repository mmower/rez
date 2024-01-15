/**
 * @namespace basic_object
 * @description The basic_object is the common prototype of all in-game objects.

  It keeps a reference to the singleton Game object allowing that to be looked
  up from any other object.

  It handles getting attribute values.

  It handles execution of named event handler.
*/

const basic_object = {
  game: null,
  initialised: false,

  /**
   * Performs the specified level of initialization on this game object.
   *
   * This is called automatically by the framework when the game is starting.
   *
   * @memberof basic_object
   * @param {number} level - the initialization level (0+) to perform
   */
  init(level) {
    const init_method = "init_" + level;
    if (typeof this[init_method] == "function") {
      this[init_method]();
    }
  },

  /**
   * Perform all initialization levels from 0..max_level as defined by RezGame.
   *
   * This is intended for the author to call on a dynamically created object to ensure it is properly initialized before use.
   *
   * @memberof basic_object
   */
  init_all() {
    for (let init_level of this.game.initLevels()) {
      this.init(init_level);
    }
  },

  /**
   * Initialize all static and dynamic properties
   *
   * @memberof basic_object
   */
  init_0() {
    this.createStaticProperties();
    this.createDynamicProperties();
  },

  /**
   * Initialize all dynamic attributes.
   *
   * @memberof basic_object
   */
  init_1() {
    this.initDynamicAttributes();
  },

  /**
   * For game objects that do not define $template: true run the element initializer
   * and the per-object init event.
   *
   * @memberof basic_object
   */
  init_2() {
    if (!this.initialised) {
      if (!this.isTemplateObject()) {
        // Templates don't initialise like regular objects
        this.elementInitializer();
        this.runEvent("init", {});
      }
      this.initialised = true;
    }
  },

  /**
   * Mark the object has having been fully initialized.
   *
   * @memberof basic_object
   */
  init_3() {
    this.initialised = true;
  },

  /**
   * @function createStaticProperty
   * @memberof basic_object
   * @param {string} attr_name - name of the attribute to create a corresponding property for
   * @description use this to create a JS property backed by a Rez attribute
   */
  createStaticProperty(attr_name) {
    Object.defineProperty(this, attr_name, {
      get: function () {
        return this.getAttribute(attr_name);
      },
      set: function (value) {
        this.setAttribute(attr_name, value);
      },
      configurable: true,
    });

    if (attr_name.endsWith("_id")) {
      const direct_attr_name = attr_name.slice(0, -3);
      Object.defineProperty(this, direct_attr_name, {
        get: function () {
          const ref_id = this.getAttribute(attr_name);
          return $(ref_id);
        },
        set: function (ref) {
          this.setAttribute(attr_name, ref.id);
        },
      });
    }
  },

  /**
   * @function createStaticProperties
   * @memberof basic_object
   * @description uses basic_object.createStaticProperty to create static properties for all of the objects declared Rez attributes
   */
  createStaticProperties() {
    for (let [attr_name, _] of Object.entries(this.attributes)) {
      this.createStaticProperty(attr_name);
    }
  },

  /**
   * @function createDynamicProperties
   * @memberof basic_object
   * @description creates synthetic properties to represent dynamic attributes types such as `ptable` and `tracery_grammar`.
   */
  createDynamicProperties() {
    if (this.getAttributeValue("$template", false)) {
      return;
    }

    for (let attr_name of Object.keys(this.attributes)) {
      const value = this.getAttribute(attr_name);
      if (typeof value == "object") {
        if (value.hasOwnProperty("ptable")) {
          this.createProbabilityTable(attr_name, value);
        } else if (value.hasOwnProperty("property")) {
          this.createCustomProperty(attr_name, value);
        } else if (value.hasOwnProperty("attr_ref")) {
          this.createReferenceAttribute(attr_name, value);
        } else if (value.hasOwnProperty("dynamic_value")) {
          this.createDynamicValueAttribute(attr_name, value);
        } else if (value.hasOwnProperty("tracery_grammar")) {
          this.createTraceryGrammarAttribute(attr_name, value);
        }
      }
    }
  },

  initDynamicAttributes() {
    if (this.getAttributeValue("$template", false)) {
      return;
    }

    for (let attr_name of Object.keys(this.attributes)) {
      const value = this.getAttribute(attr_name);
      if (typeof value == "object") {
        if (value.hasOwnProperty("initializer")) {
          this.createDynamicallyInitializedAttribute(attr_name, value);
        }
      }
    }
  },

  createProbabilityTable(attr_name, value) {
    delete this[attr_name];

    const ptable = JSON.parse(value["ptable"]);

    Object.defineProperty(this, attr_name, {
      get: function () {
        const p = Math.random();
        const idx = ptable.findIndex((pair) => p <= pair[1]);
        if (idx == -1) {
          throw "Invalid p_table. Must contain range 0<n<1";
        }

        return ptable[idx][0];
      },
    });

    Object.defineProperty(this, `${attr_name}_roll`, {
      get: function () {
        const p = Math.random();
        const idx = ptable.findIndex((pair) => p <= pair[1]);
        if (idx == -1) {
          throw "Invalid p_table. Must contain range 0<n<1";
        }

        return { p: p, obj: ptable[idx][0] };
      },
    });
  },

  createCustomProperty(attr_name, value) {
    delete this[attr_name];
    const property_def = value["property"];
    const property_src = `function() {${property_def}}`;
    eval(`Object.defineProperty(this, "${attr_name}", {get: ${property_src}})`);
  },

  createDynamicallyInitializedAttribute(attr_name, value) {
    if (value.constructor == RezDie) {
      this.setAttribute(attr_name, value.roll(), false);
    } else {
      const initializer = value["initializer"];
      this.setAttribute(attr_name, eval(initializer), false);
    }
  },

  createReferenceAttribute(attr_name, value) {
    delete this[attr_name];
    const ref = value["attr_ref"];

    Object.defineProperty(this, attr_name, {
      get: function () {
        return $(ref.elem_id).getAttributeValue(ref.attr_name);
      },
    });
  },

  createDynamicValueAttribute(attr_name, value) {
    delete this[attr_name];

    const val_gen = value["dynamic_value"];
    const src = `(${this.id}) => {return ${val_gen};}`;
    const f = eval(src);
    Object.defineProperty(this, attr_name, {
      get: function () {
        return f(this);
      },
    });
  },

  createTraceryGrammarAttribute(attr_name, value) {
    delete this[attr_name];

    const grammar = tracery.createGrammar(JSON.parse(value.tracery_grammar));
    grammar.addModifiers(tracery.baseEngModifiers);

    Object.defineProperty(this, attr_name, {
      get: function () {
        return grammar.flatten("#origin#");
      },
    });
  },

  /**
   * @function elementInitializer
   * @memberof basic_object
   * @description objects using basic_object as a prototype should define their own elementInitializer function to handle any element-specific initialization
   */
  elementInitializer() {},

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
    copy.init_all();
    copy.runEvent("copy", { original: this });
    return copy;
  },

  /**
   * @function getNextAutoId
   * @memberof basic_object
   * @description returns the next auto id in the sequence
   */
  getNextAutoId() {
    this.$auto_id_idx += 1;
    return this.id + "_" + this.$auto_id_idx;
  },

  /**
   * @function copyWithAutoId
   * @memberof basic_object
   * @description creates a copy of this object that is assigned an ID automatically. In all other respects its behaviour is identical to `copyAssigningId`
   * Copies an object with an auto-generated ID
   */
  copyWithAutoId() {
    return this.copyAssigningId(this.getNextAutoId());
  },

  /**
   * @function isTemplateObject
   * @memberof basic_object
   * @description returns the value of the `$template` attribute
   * @returns {boolean} true if this object has a $template attribute with value true
   */
  isTemplateObject() {
    return this.getAttributeValue("$template", false);
  },

  /**
   * @function eventHandler
   * @memberof basic_object
   * @param {string} event_name name of the event whose handler should be returned
   * @returns {function|undefined} event handle function or undefined
   * @description Returns the event handler function stored in attribute "on_<event_name>" or undefined if no handler is present
   */
  eventHandler(event_name) {
    return this.getAttribute(`on_${event_name}`);
  },

  /**
   * @function willHandleEvent
   * @memberof basic_object
   * @param {string} event_name name of the event to check for a handler, e.g. "speak"
   * @returns {boolean} true if this object handles the specified event
   * @description Returns `true` if this object defines an event handler function for the given event_name
   */
  willHandleEvent(event_name) {
    const handler = this.eventHandler(event_name);
    const does_handle_event = handler != null && typeof handler == "function";
    return does_handle_event;
  },

  /**
   * @function runEvent
   * @memberof basic_object
   * @param {string} event_name name of the event to run, e.g. "speak"
   * @param {object} params object containing event params
   * @returns {*|boolean} returns a response object, or false if the event was not handled
   * @description attempts to run the event handler function for the event name, passing the specified params to the handler
   */
  runEvent(event_name, params) {
    console.log("Run on_" + event_name + " handler on " + this.id);
    let handler = this.eventHandler(event_name);
    if (handler != null && typeof handler == "function") {
      return handler(this, params);
    } else {
      return false;
    }
  },

  /**
   * @function hasAttribute
   * @memberof basic_object
   * @param {string} name name of the attribute
   * @returns {boolean} true if the object defines the specified attribute
   */
  hasAttribute(name) {
    return !!this.attributes[name];
  },

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
  },

  /**
   * @function getAttributeValue
   * @memberof basic_object
   * @param {string} name name of the attribute
   * @param {*} default_value value to return if no such attribute is present
   * @returns {*} attribute value
   * @description returns the value of the attribute with the given name. If no such value is present it returns the default value. If no default value is given it throws an exception.
   */
  getAttributeValue(name, default_value) {
    const attr = this.getAttribute(name);
    if (typeof attr == "undefined") {
      if (typeof default_value == "undefined") {
        throw (
          "Attempt to get value of attribute |" +
          name +
          "| which is not defined on |#" +
          this.id +
          "|"
        );
      } else {
        return default_value;
      }
    } else if (typeof attr == "function") {
      return attr(this);
    } else if (attr.constructor == RezDie) {
      return attr.roll();
    } else {
      return attr;
    }
  },

  /**
   * @function getObjectViaAttribute
   * @memberof basic_object
   * @param {string} name attribute name
   * @param {*} default_value
   */
  getObjectViaAttribute(name, default_value) {
    const id = this.getAttributeValue(name, default_value);
    return $(id);
  },

  /**
   * @function setAttribute
   * @memberof basic_object
   * @param {string} attr_name name of attribute to set
   * @param {*} new_value value for attribute
   * @param {boolean} notify_observers whether observers should be notified that the value has changed
   */
  setAttribute(attr_name, new_value, notify_observers = true) {
    if (typeof new_value == "undefined") {
      throw "Call to setAttribute with undefined value!";
    }

    const old_value = this.attributes[attr_name];
    this.attributes[attr_name] = new_value;
    this.changed_attributes.push(attr_name);
    if (notify_observers) {
      this.game.elementAttributeHasChanged(
        this,
        attr_name,
        old_value,
        new_value
      );
    }
  },

  addTag(tag) {
    let tags = this.getAttribute("tags");
    if (!tags) {
      tags = new Set([tag]);
    } else {
      tags.add(tag);
    }

    this.setAttribute("tags", tags);
    this.game.indexObjectForTag(this, tag);
  },

  removeTag(tag) {
    let tags = this.getAttribute("tags");
    if (!tags) {
      tags = new Set();
    } else {
      tags.delete(tag);
    }

    this.setAttribute("tags", tags);
    this.game.unindexObjectForTag(this, tag);
  },

  /**
   * @function setTags
   * @memberof basic_object
   * @param {set} tags tags the object should have after the call
   */
  setTags(new_tags) {
    new_tags = new Set(new_tags); // Just in case they are passed as an array
    const old_tags = this.getAttributeValue("tags", new Set());

    const to_remove = old_tags.difference(new_tags);
    to_remove.forEach((tag) => this.removeTag(tag));

    const to_add = new_tags.difference(old_tags);
    to_add.forEach((tag) => this.addTag(tag));
  },

  /**
   * @function applyEffect
   * @memberof basic_object
   * @param {string} effect_id
   * @param {string} slot_id
   * @param {string} item_id
   */
  applyEffect(effect_id, slot_id, item_id) {
    console.log(
      "Been asked to apply effect |" +
        effect_id +
        "| from item |" +
        item_id +
        "| to |" +
        this.id +
        "|"
    );
  },

  /**
   * @function removeEffect
   * @memberof basic_object
   * @param {string} effect_id
   * @param {string} slot_id
   * @param {string} item_id
   */
  removeEffect(effect_id, slot_id, item_id) {
    console.log(
      "Been asked to remove effect |" +
        effect_id +
        "| from item |" +
        item_id +
        "| to |" +
        this.id +
        "|"
    );
  },

  /**
   * @function needsArchiving
   * @memberof basic_object
   * @returns {boolean} true if this object requires archiving
   */
  needsArchiving() {
    return (
      this.changed_attributes.length > 0 ||
      this.properties_to_archive.length > 0
    );
  },

  archiveDataContainer() {
    return {
      id: this.id,
      type: this.game_object_type,
    };
  },

  dataWithArchivedAttributes(data) {
    const obj = this;
    return this.changed_attributes.reduce(function (data, key) {
      data["attrs"] = data["attrs"] || {};
      data["attrs"][key] = obj.getAttribute(key);
      return data;
    }, data);
  },

  dataWithArchivedProperties(data) {
    const obj = this;
    return this.properties_to_archive.reduce(function (data, key) {
      data["props"] = data["props"] || {};
      data["props"][key] = obj[key];
      return data;
    }, data);
  },

  toJSON() {
    let data = this.archiveDataContainer();
    data = this.dataWithArchivedProperties(data);
    data = this.dataWithArchivedAttributes(data);
    return data;
  },

  loadData(data) {
    const attrs = data["attrs"];
    if (typeof attrs == "object") {
      for (const [k, v] of Object.entries(attrs)) {
        this.setAttribute(k, v);
      }
    }

    const props = data["props"];
    if (typeof props == "object") {
      for (const [k, v] of Object.entries(props)) {
        this[k] = v;
      }
    }
  },
};

const no_value = {
  __proto__: basic_object,
};

window.isGameObject = function (v) {
  return basic_object.isPrototypeOf(v);
};

window.Rez ??= {};
window.Rez.basic_object = basic_object;
