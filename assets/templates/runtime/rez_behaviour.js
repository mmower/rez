//-----------------------------------------------------------------------------
// Behaviour
//-----------------------------------------------------------------------------

class RezBehaviour extends RezBasicObject {
  #options;
  #children;

  constructor(id, attributes) {
    super("behaviour", id, attributes);

    this.#options = {};
    this.#children = [];
  }

  get firstChild() {
    return this.#children[0];
  }

  get secondChild() {
    return this.#children[1];
  }

  get childCount() {
    return this.#children.length;
  }

  configure() {
    const config_fn = this.getAttribute("configure");
    if(typeof(config_fn) === "function") {
      config_fn(this);
    }
  }

  option(name) {
    const value = this.#options[name];
    if(typeof(value) === "undefined") {
      throw new Error(`Behaviour ${this.id} does not define option '${name}'!`);
    }
    return value;
  }

  numberOption(name) {
    const value = this.option(name);
    if(typeof(value) !== "number") {
      throw new Error(`Behaviour ${this.id} option '${name}' is not a number (${typeof(value)})!`);
    }
    return value;
  }

  intOption(name) {
    return Math.floor(this.numberOption(name));
  }

  setOption(name, value) {
    this.#options[name] = value;
  }

  getChildAt(idx) {
    return this.#children[idx];
  }

  result(wmem, success) {
    return {
      id: this.id,
      wmem: wmem,
      success: success
    };
  }

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
