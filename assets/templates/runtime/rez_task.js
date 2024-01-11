//-----------------------------------------------------------------------------
// Task
//-----------------------------------------------------------------------------

function RezTask(id, attributes) {
  this.id = id;
  this.game_object_type = "task";
  this.options = {};
  this.children = [];
  this.attributes = attributes;
  this.properties_to_archive = [];
  this.changed_attributes = [];
}

RezTask.prototype = {
  __proto__: basic_object,
  constructor: RezTask,

  configure() {
    const config_fn = this.getAttribute("configure");
    if(typeof(config_fn) == "function") {
      config_fn(this);
    }
  },

  option(name) {
    const value = this.options[name];
    if(typeof(value) == "undefined") {
      throw "Task " + this.id + " does not define option '" + name + "'";
    }
    return value;
  },

  numberOption(name) {
    const value = this.option(name);
    if(typeof(value) != "number") {
      throw "Task " + this.id + " option '" + name + "' is not a number (" + typeof(value) + ")";
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

  execute(wmem) {
    // By definition this is a function of two attributes
    // (task, wmem)
    const handler = this.getAttributes("execute");
    return handler(this, wmem);
  },

  instantiate(options, children = []) {
    const task = this.copyWithAutoId();
    task.options = options;
    task.children = children;
    task.configure();
    return task;
  }
};

window.RezTask = RezTask;
