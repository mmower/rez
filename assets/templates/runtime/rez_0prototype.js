//-----------------------------------------------------------------------------
// Basic Object Prototype
//-----------------------------------------------------------------------------

/*
  Basic Object

  The basic_object is the common prototype of all in-game objects.

  It keeps a reference to the singleton Game object allowing that to be looked
  up from any other object.

  It handles getting attribute values.

  It handles execution of named event handler.
*/

const basic_object = {
  game: null,
  initialised: false,

  /*
   * Object ref lookup shortcut
   */
  $(id) {
    return this.game.getGameObject(id);
  },

  /*
   * Intialization
   */

  init(level) {
    const init_method = "init_" + level;
    if (typeof this[init_method] == "function") {
      this[init_method]();
    }
  },

  init_all() {
    for (let init_level of this.game.initLevels()) {
      this.init(init_level);
    }
  },

  init_0() {
    this.createStaticProperties();
    this.createDynamicProperties();
  },

  init_1() {
    this.initDynamicAttributes();
  },

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

  init_3() {
    this.initialised = true;
  },

  createStaticProperties() {
    for (let [attr_name, _] of Object.entries(this.attributes)) {
      Object.defineProperty(this, attr_name, {
        get: function () {
          return this.getAttribute(attr_name);
        },
        set: function (value) {
          this.setAttribute(attr_name, value);
        },
        configurable: true,
      });
    }
  },

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

  elementInitializer() {},

  /*
   * Copies an object assigning it an ID
   */
  copyAssigningId(id) {
    const attributes = this.attributes.copy();
    const copy = new this.constructor(id, attributes);
    copy.setAttribute("$template", false, false);
    copy.setAttribute("$original", this.id, false);
    copy.init_all();
    copy.runEvent("copy", { original: this });
    return copy;
  },

  /*
   * Copies an object with an auto-generated ID
   */
  copyWithAutoId() {
    this.auto_id_idx += 1;
    const copy_id = this.id + "_" + this.auto_id_idx;
    return this.copyAssigningId(copy_id);
  },

  isTemplateObject() {
    return this.getAttributeValue("$template", false);
  },

  /*
   * Event Handling
   */

  eventHandler(event_name) {
    return this.getAttribute("on_" + event_name);
  },

  willHandleEvent(event_name) {
    const handler = this.eventHandler(event_name);
    const does_handle_event = handler != null && typeof handler == "function";
    return does_handle_event;
  },

  runEvent(event_name, event_info) {
    console.log("Run on_" + event_name + " handler on " + this.id);
    let handler = this.eventHandler(event_name);
    if (handler != null && typeof handler == "function") {
      return handler(this, event_info);
    } else {
      return false;
    }
  },

  /*
   * Attribute query/get/set
   */

  getIn(path) {
    const segments = path.split(".");
    const first = segments[0];
    const rest = segments.slice(1);
    const value = this.attributes[first];

    if (null == value) {
      return null;
    } else {
      return rest.reduce((attr, segment) => {
        let next_value = attr[segment];
        if (typeof next_value == "undefined") {
          return null;
        } else {
          return next_value;
        }
      }, value);
    }
  },

  hasAttribute(name) {
    return !!this.attributes[name];
  },

  getAttribute(name) {
    const attr = this.attributes[name];
    return attr;
  },

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

  $av(name, default_value) {
    return this.getAttributeValue(name, default_value);
  },

  getObjectViaAttribute(name, default_value) {
    const id = this.getAttributeValue(name, default_value);
    return $(id);
  },

  attributeHasChanged(attr_name) {
    this.changed_attributes.push(attr_name);
  },

  setAttribute(name, value, undo_tracking = true) {
    if (typeof value == "undefined") {
      throw "Call to setAttribute with undefined value!";
    }

    if (undo_tracking) {
      this.game.undoManager.recordChange(this.id, name, this.attributes[name]);
    }

    this.attributes[name] = value;
    this.attributeHasChanged(name);
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

  setTags(new_tags) {
    new_tags = new Set(new_tags); // Just in case they are passed as an array
    const old_tags = this.getAttributeValue("tags", new Set());

    const to_remove = old_tags.difference(new_tags);
    to_remove.forEach((tag) => this.removeTag(tag));

    const to_add = new_tags.difference(old_tags);
    to_add.forEach((tag) => this.addTag(tag));
  },

  putIn(path, value) {
    const selectors = path.split(".");
    const first_selector = selectors[0];
    if (selectors.length == 1) {
      this.setAttribute(first_selector, value);
    } else {
      const lookup_selectors = selectors.slice(1, -1);
      let target = lookup_selectors.reduce((target, selector) => {
        return target[selector];
      }, this.getAttribute(first_selector));

      if (typeof target == "undefined") {
        throw "Attempt to putIn invalid path: " + path + " on " + this.id;
      } else {
        const final_selector = selectors.slice(-1);
        target[final_selector] = value;
        this.changedAttribute(first_selector);
      }
    }

    return this;
  },

  incAttribute(name, amount = 1) {
    let value = this.getAttribute(name);
    if (typeof value == "number") {
      this.setAttribute(name, value + amount);
    } else {
      throw "Attempt to inc/dec non-numeric attribute: " + name;
    }
  },

  decAttribute(name, amount = 1) {
    this.incAttribute(name, -amount);
  },

  /*
   * Effect Management
   */
  applyEffect(effect_id, item_id) {
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

  removeEffect(effect_id, item_id) {
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

  /*
   * Binding
   */

  addBinding(name, object) {
    const bindings = this.getAttribute("bindings") || {};
    bindings[name] = object.id;
    this.setAttribute("bindings", bindings);
  },

  /*
   * Archiving
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

window.isGameObject = function (v) {
  return basic_object.isPrototypeOf(v);
};

// Object.defineProperty(Object.prototype, "isGameObject", {
//   value: function() {
//       return basic_object.isPrototypeOf(this);
//   }
// });

window.Rez ??= {};
window.Rez.basic_object = basic_object;
