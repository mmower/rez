//-----------------------------------------------------------------------------
// Behaviour
//-----------------------------------------------------------------------------

function RezBehaviour(id, attributes) {
  this.id = id;
  this.game_object_type = "behaviour";
  this.options = {};
  this.children = [];
  this.attributes = attributes;
  this.properties_to_archive = [];
  this.changed_attributes = [];
}

RezBehaviour.prototype = {
  __proto__: basic_object,
  constructor: RezBehaviour,

  configure() {
    const config_fn = this.getAttribute("configure");
    if(typeof(config_fn) === "function") {
      config_fn(this);
    }
  },

  option(name) {
    const value = this.options[name];
    if(typeof(value) === "undefined") {
      throw `Behaviour ${this.id} does not define option '${name}'!`;
    }
    return value;
  },

  numberOption(name) {
    const value = this.option(name);
    if(typeof(value) != "number") {
      throw `Behaviour ${this.id} option '${name}' is not a number (${typeof(value)})!`;
    }
    return value;
  },

  intOption(name) {
    return Math.floor(this.numberOption(name));
  },

  setOption(name, value) {
    this.options[name] = value;
  },

  firstChild() {
      return this.children[0];
  },

  secondChild() {
    return this.children[1];
  },

  getChild(idx) {
    return this.children[idx];
  },

  children() {
    return this.children;
  },

  childCount() {
    return this.children.length;
  },

  result(wmem, success) {
    return {
      id: this.id,
      wmem: wmem,
      success: success
    };
  },

  executeBehaviour(wmem) {
    // By definition this is a function of two attributes
    // (behaviour, wmem)
    const handler = this.getAttribute("execute");
    if(typeof(handler) === "function") {
      return handler(this, wmem);
    } else {
      return {
        id: this.id,
        wmem: wmem,
        success: false,
        error: "No execute handler found."
      }
    }
  },

  instantiate(options, children = []) {
    const behaviour = this.copyWithAutoId();
    behaviour.options = options;
    behaviour.children = children;
    behaviour.configure();
    return behaviour;
  }
};

window.RezBehaviour = RezBehaviour;
