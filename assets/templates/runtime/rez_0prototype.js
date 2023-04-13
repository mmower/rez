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

  init() {
    if(!this.initialised) {
      console.log("Initialise " + this.id);
      this.initDynamicAttributes();
      this.elementInitializer();
      this.runEvent("init", {});
      this.initialised = true;
    }
  },

  initDynamicAttributes() {
    if(this.hasAttribute("$template") && this.getAttribute("$template") == true) {
      return;
    }

    for(let attr_name of Object.keys(this.attributes)) {
      const value = this.getAttribute(attr_name);

      if(typeof(value) == "object" && value.hasOwnProperty("initializer")) {
        const initializer = value["initializer"];
        this.setAttribute(attr_name, eval(initializer));
      } else if(value.constructor == RezDie) {
        this.setAttribute(attr_name, value.roll());
      }
    }
  },

  elementInitializer() {
  },

  /*
   * Template object copying
  */

  copyAssigningId(id) {
    const attributes = this.attributes.copy();
    const copy = new this.constructor(id, attributes);
    copy.setAttribute("$template", false);
    copy.runEvent("copy", {original: this});
    copy.setAttribute("copy_of", this.id);
    copy.init();
    return copy;
  },

  // Need to check if there is a problem with copying copies
  // and ID auto-assignment. Shouldn't be, we should get
  // <id>_1_1, <id>_1_1_1 and so on but should be tested.
  copyWithAutoId() {
    this.auto_id_idx += 1;
    const copy_id = this.id + "_" + this.auto_id_idx;
    return this.copyAssigningId(copy_id);
  },

  /*
   * Event Handling
  */

  eventHandler(event_name) {
    return this.getAttribute("on_" + event_name);
  },

  willHandleEvent(event_name) {
    const handler = this.eventHandler(event_name);
    const does_handle_event = handler != null && typeof(handler) == "function";
    return does_handle_event;
  },

  runEvent(event_name, event_info) {
    console.log("Run on_" + event_name + " handler on " + this.id);
    let handler = this.eventHandler(event_name);
    if(handler != null && typeof(handler) == "function") {
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

    if(null == value) {
      return null;
    } else {
      return rest.reduce((attr, segment) => {
        let next_value = attr[segment];
        if(typeof(next_value) == "undefined") {
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
    if(typeof(attr) == "undefined") {
      if(typeof(default_value) == "undefined") {
        throw "Attempt to get value of attribute |" + name + "| which is not defined on |#" + this.id + "|";
      } else {
        return default_value;
      }
    } else if(typeof(attr) == "function") {
      return attr(this);
    } else if(attr.constructor == RezDie) {
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

  setObjectViaAttribute(name, object) {
    this.setAttribute(name, object.id);
  },

  attributeHasChanged(attr_name) {
    this.changed_attributes.push(attr_name);
  },

  setAttribute(name, value) {
    if(typeof(value) == "undefined") {
      throw "Call to setAttribute with undefined value!";
    }
    this.attributes[name] = value;
    this.attributeHasChanged(name);
  },

  addTag(tag) {
    let tags = this.getAttribute("tags");
    if(!tags) {
      tags = new Set([tag]);
    } else {
      tags.add(tag);
    }

    this.setAttribute("tags", tags);
    this.game.indexObjectForTag(this, tag);
  },

  removeTag(tag) {
    let tags = this.getAttribute("tags");
    if(!tags) {
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
    if(selectors.length == 1) {
      this.setAttribute(first_selector, value);
    } else {
      const lookup_selectors = selectors.slice(1, -1);
      let target = lookup_selectors.reduce((target, selector) => {
        return target[selector];
      }, this.getAttribute(first_selector));

      if(typeof(target) == "undefined") {
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
    if(typeof(value) == "number") {
      this.setAttribute(name, value+amount);
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
    console.log("Been asked to apply effect |"+effect_id+"| from item |"+item_id+"| to |"+this.id+"|");
  },

  removeEffect(effect_id, item_id) {
    console.log("Been asked to remove effect |"+effect_id+"| from item |"+item_id+"| to |"+this.id+"|");
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
    return this.changed_attributes.length > 0 || this.properties_to_archive.length > 0;
  },

  archiveDataContainer() {
    return {
      id: this.id,
      type: this.game_object_type
    };
  },

  dataWithArchivedAttributes(data) {
    const obj= this;
    return this.changed_attributes.reduce(
      function(data, key) {
        data["attrs"] = data["attrs"] || {};
        data["attrs"][key] = obj.getAttribute(key)
        return data;
      },
      data
    );
  },

  dataWithArchivedProperties(data) {
    const obj = this;
    return this.properties_to_archive.reduce(
      function(data, key) {
        data["props"] = data["props"] || {};
        data["props"][key] = obj[key];
        return data;
      },
      data
    );
  },

  toJSON() {
    let data = this.archiveDataContainer();
    data = this.dataWithArchivedProperties(data);
    data = this.dataWithArchivedAttributes(data);
    return data;
  },

  loadData(data) {
    const attrs = data["attrs"];
    if(typeof(attrs) == "object") {
      for(const [k, v] of Object.entries(attrs)) {
        this.setAttribute(k, v);
      }
    }

    const props = data["props"];
    if(typeof(props) == "object") {
      for(const [k, v] of Object.entries(props)) {
        this[k] = v;
      }
    }
  }
};

Object.defineProperty(Object.prototype, "isGameObject", {
  value: function() {
      return basic_object.isPrototypeOf(this);
  }
});

window.Rez ??= {};
window.Rez.basic_object = basic_object;
