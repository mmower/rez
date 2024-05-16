//-----------------------------------------------------------------------------
// Templates use this for conditionals
//-----------------------------------------------------------------------------

function evaluateExpression(expression, bindings, rval = true) {
  const proxy = new Proxy(
    {},
    {
      get: (target, property) => {
        if (bindings.hasOwnProperty(property)) {
          return bindings[property];
        }
        return undefined;
      },
    }
  );

  const argNames = Object.keys(bindings);
  const argValues = argNames.map((name) => proxy[name]);

  // Create a new function with bindings as arguments and the expression as the body
  let func;
  if(rval) {
    func = new Function(...argNames, `return ${expression};`);
  } else {
    func = new Function(...argNames, `${expression}`);
  }

  // Invoke the function with the values from the bindings
  return func(...argValues);
}

//-----------------------------------------------------------------------------
// View
//-----------------------------------------------------------------------------

/*
block_type: ?
source: an element with attributes
params: ?

 */

function RezBlock(block_type, source, params = {}) {
  this.parent_block = null;
  this.block_type = block_type;
  this.source = source;
  this.flipped = false;
  this.params = params;
}

RezBlock.prototype = {
  constructor: RezBlock,

  instantiateIdBinding(id) {
    return $(id);
  },

  instantiatPropertyBinding(ref) {
    const target = $(ref.elem_id);
    return target[ref.attr_name];
  },

  instantiateFunctionBinding(bindings, f) {
    if (this.parent_block) {
      return f(this, this.parent_block.source, bindings);
    } else {
      return f(this, null, bindings);
    }
  },

  instantiateBindingPath(p) {
    return p(this.source);
  },

  instantiatePathBinding(path_fn, bindings) {
    return path_fn(bindings);
  },

  // bindings are key-value pairs of the form {name, expr}
  // where an expression is either the id of an element
  // or a function. The result of instantiation is either
  // {name, element_ref} or {name, func_result}
  getBindings(initial_bindings) {
    const source_bindings = this.source.getAttributeValue("bindings", []);

    if(this.source.getAttributeValue("$debug_bindings", false)) {
      console.log(`Binding source: ${this.source.id}`);
      console.log("Inital Bindings");
      console.dir(initial_bindings);

      console.log("Bindings");
      console.dir(source_bindings);
    }

    return source_bindings.reduce((bindings, binding_object) => {
      const prefix = binding_object["prefix"];
      const source = binding_object["source"];
      const literal = binding_object["literal"];
      const deref = binding_object["deref"];

      let value;

      if(typeof(literal) !== "undefined") {
        value = literal
      } else {
        if(typeof(source) === "string") {
          value = this.instantiateIdBinding(source);
        } else if(typeof(source) === "function") {
          value = this.instantiateFunctionBinding(bindings, source);
        } else if(typeof(source.binding) === "function") {
          value = this.instantiatePathBinding(source.binding, bindings);
          if(deref) {
            if(Array.isArray(value)) {
              value = value.map((id) => $(id));
            } else {
              value = $(value)
            }
          }
        } else {
          console.log("Binding prefix: " + prefix);
          console.dir(value);
          throw `Invalid binding type: ${typeof(value)}!`;
        }
      }

      bindings[prefix] = value;
      return bindings;
    }, initial_bindings);
  },

  bindValues() {
    const initial_bindings = {
      block: this,
      params: this.params,
      source: this.source,
      [this.source.bindAs()]: this.source
    };

    return this.getBindings(initial_bindings);
  },

  // blocks are a list of id's of other card elements that we
  // want to sub-render and make available to the template of this
  // card. The result is a map of key pairs {block_id, block_render}
  getBlocks() {
    const blocks = this.source.getAttributeValue("blocks", []);
    return blocks.reduce((block_mappings, block_id) => {
      const block_source = $(block_id);
      block_source.$parent = this.source;
      const block = new RezBlock("block", block_source);
      block.parent_block = this;
      block_mappings[block_id] = block;
      return block_mappings;
    }, {});
  },

  bindBlocks() {
    return this.getBlocks().obj_map((block) => block.html());
  },

  getViewTemplate() {
    return this.source.getViewTemplate(this.flipped);
  },

  parentBindings() {
    if (this.parent_block) {
      return this.parent_block.bindValues();
    } else {
      return {};
    }
  },

  bindings() {
    const bindings = {
      ...this.parentBindings(),
      ...this.bindValues(),
      ...this.bindBlocks(),
    };

    return bindings;
  },

  renderBlock() {
    const template = this.getViewTemplate();
    const bindings = this.bindings();
    return template(bindings);
  },

  css_classes() {
    if (this.block_type == "block") {
      return "block";
    } else if (this.block_type == "card") {
      if (this.flipped) {
        return "flipped_card";
      } else {
        return "active_card";
      }
    } else {
      throw "This shouldn't happen, right?";
    }
  },

  html() {
    if(this.source.$suppress_wrapper) {
      return this.renderBlock();
    } else {
      return `<div class="${this.css_classes()}">${this.renderBlock()}</div>`;
    }
  },
};

window.Rez.RezBlock = RezBlock;

//-----------------------------------------------------------------------------
// Layout
//-----------------------------------------------------------------------------

let layout_proto = {
  __proto__: RezBlock.prototype,

  addContent(block) {
    throw "Must implement addContent(block)";
  },

  renderContents() {
    throw "Must implement renderContents()";
  },

  bindAs() {
    throw "Must implement bindAs()";
  },

  html() {
    const content = this.renderContents();
    const template_fn = this.getViewTemplate();
    const bound_values = this.bindValues();
    const bound_blocks = this.bindBlocks();
    return template_fn({
      content: content,
      ...bound_values,
      ...bound_blocks,
    });
  },
};

//-----------------------------------------------------------------------------
// Single Layout
//
// This Layout holds a single block as it's content
//-----------------------------------------------------------------------------

function RezSingleLayout(source_name, source) {
  RezBlock.call(this, "scene", source);
  this.source_name = source_name;
  this.content = null;
}

RezSingleLayout.prototype = {
  __proto__: layout_proto,
  constructor: RezSingleLayout,

  addContent(block) {
    block.parent_block = this;
    this.content = block;
  },

  bindAs() {
    return this.source_name;
  },

  renderContents() {
    return this.content.html();
  },
};

window.Rez.RezSingleLayout = RezSingleLayout;

//-----------------------------------------------------------------------------
// Stack Layout
//
// This layout holds a list of blocks that are composed to form its content
//-----------------------------------------------------------------------------

function RezStackLayout(source_name, source) {
  RezBlock.call(this, "scene", source);
  this.source_name = source_name;
  this.contents = [];
}

RezStackLayout.prototype = {
  __proto__: layout_proto,
  constructor: RezStackLayout,

  get reversed() {
    return this.source.layout_reverse;
  },

  addContent(block) {
    block.parent_block = this;

    if (this.reversed) {
      this.contents.unshift(block);
    } else {
      this.contents.push(block);
    }
  },

  bindAs() {
    return this.source_name;
  },

  renderContents() {
    let separator = "";
    if (this.source.layout_separator) {
      separator = this.source.layout_separator;
    }

    return this.contents.map((block) => block.html()).join(separator);
  },
};

window.Rez.RezStackLayout = RezStackLayout;

//-----------------------------------------------------------------------------
// Transformers
//-----------------------------------------------------------------------------

let transformer_proto = {
  getSelector() {
    if (typeof this.selector == "undefined") {
      throw "Undefined selector!";
    }
    return this.selector;
  },

  getElements() {
    return document.querySelectorAll(this.getSelector());
  },

  transformElements(view) {
    this.getElements().forEach(function (elem) {
      this.transformElement(elem, view);
    }, this);
  },

  transformElement(elem) {
    throw "Transformers must implement transformElement(e)!";
  },
};

//-----------------------------------------------------------------------------
// Event Transformers
//-----------------------------------------------------------------------------

let event_transformer_proto = {
  __proto__: transformer_proto,

  getReceiver() {
    if (typeof this.receiver == "undefined") {
      throw "Undefined receiver!";
    }
    return this.receiver;
  },

  getEventName() {
    if (typeof this.event == "undefined") {
      throw "Undefined event!";
    }
    return this.event;
  },

  addEventListener(elem, event) {
    const transformer = this;
    const receiver = this.getReceiver();
    elem.addEventListener(event, function (evt) {
      evt.preventDefault();

      // A handler should return an object with keys representing the side-
      // effects of an event.
      // {scene: "scene_id"}
      // Load a new scene
      // {card: "card_id"}
      // Play a card into the current scene
      // {flash: "flash message"}
      // Update the current flash
      // {render: true}
      // Trigger a re-render of the view
      // {error: "Error Message"}
      // Log an error message
      receiver.dispatchResponse(receiver.handleBrowserEvent(evt));
    });
  },

  transformElement(elem) {
    this.addEventListener(elem, this.getEventName());
  },
};


//-----------------------------------------------------------------------------
// Block Transformer
//-----------------------------------------------------------------------------

function RezBlockTransformer() {
  this.selector = "div.card[data-card]";
}

RezBlockTransformer.prototype = {
  __proto__: transformer_proto,
  constructor: RezBlockTransformer,

  transformElement(elem) {
    const elem_id = elem.dataset.card;
    elem.rez_card = $(elem_id);
  }
}

window.Rez.RezBlockTransformer = RezBlockTransformer;

//-----------------------------------------------------------------------------
// Link Transformers
//-----------------------------------------------------------------------------

function RezEventLinkTransformer(receiver) {
  this.selector = "div.card a[data-event]";
  this.event = "click";
  this.receiver = receiver;
}

RezEventLinkTransformer.prototype = {
  __proto__: event_transformer_proto,
  constructor: RezEventLinkTransformer,

  transformElement(elem) {
    this.addEventListener(elem, this.getEventName());
  },
};

window.Rez.RezEventLinkTransformer = RezEventLinkTransformer;

//-----------------------------------------------------------------------------
// Button Transformer
//-----------------------------------------------------------------------------

function RezButtonTransformer(receiver) {
  this.selector = "div.card button[data-event]:not(.inactive)";
  this.event = "click";
  this.receiver = receiver;
}

RezButtonTransformer.prototype = {
  __proto__: event_transformer_proto,
  constructor: RezButtonTransformer,

  transformElement(elem) {
    this.addEventListener(elem, this.getEventName());
  },
};

window.Rez.RezButtonTransformer = RezButtonTransformer;

//-----------------------------------------------------------------------------
// FormTransformer
//-----------------------------------------------------------------------------

function RezFormTransformer(receiver) {
  this.selector = "div.card form[rez-live]";
  this.event = "submit";
  this.receiver = receiver;
}

RezFormTransformer.prototype = {
  __proto__: event_transformer_proto,
  constructor: RezFormTransformer
};

window.Rez.RezFormTransformer = RezFormTransformer;

//-----------------------------------------------------------------------------
// InputTransformer
//-----------------------------------------------------------------------------

function RezInputTransformer(receiver) {
  this.selector = "div.card input[rez-live]";
  this.event = "input";
  this.receiver = receiver;
}

RezInputTransformer.prototype = event_transformer_proto;

window.Rez.RezInputTransformer = RezInputTransformer;

//-----------------------------------------------------------------------------
// BindingTransformer
//-----------------------------------------------------------------------------

function RezBindingTransformer(receiver) {
  this.selector =
    "div.card input[rez-bind], select[rez-bind], textarea[rez-bind]";
  this.receiver = receiver;
}

RezBindingTransformer.prototype = {
  __proto__: event_transformer_proto,
  constructor: RezBindingTransformer,

  decodeBinding(binding_expr) {
    const [binding_id, binding_attr] = binding_expr.split(".");
    if (
      typeof binding_id === "undefined" ||
      typeof binding_attr === "undefined"
    ) {
      throw `Unable to parse binding: ${binding_expr}`;
    }

    return [binding_id, binding_attr];
  },

  getBoundElem(input, binding_id) {
    if(binding_id === "game") {
      return $game;
    } else if(binding_id === "scene") {
      return $game.current_scene;
    } else if(binding_id === "card") {
      const card_el = input.closest("div.card");
      return card_el.rez_card;
    } else {
      return $(binding_id);
    };
  },

  getBoundValue(input, binding_id, binding_attr) {
    return this.getBoundElem(input, binding_id).getAttribute(binding_attr)
  },

  setBoundValue(input, binding_id, binding_attr, value) {
    this.getBoundElem(input, binding_id).setAttribute(binding_attr, value);
  },

  transformTextInput(view, input, binding_id, binding_attr) {
    const transformer = this;

    view.registerBinding(binding_id, binding_attr, function (value) {
      input.value = value;
    });

    input.value = this.getBoundValue(input, binding_id, binding_attr);
    input.addEventListener("input", function (evt) {
      transformer.setBoundValue(input, binding_id, binding_attr, evt.target.value);
    });
  },

  transformCheckboxInput(view, input, binding_id, binding_attr) {
    const transformer = this;

    view.registerBinding(binding_id, binding_attr, function (value) {
      input.checked = value;
    });
    input.checked = this.getBoundValue(input, binding_id, binding_attr);
    input.addEventListener("change", function (evt) {
      transformer.setBoundValue(input, binding_id, binding_attr, evt.target.checked);
    });
  },

  setRadioGroupValue(group_name, value) {
    const radios = document.getElementsByName(group_name);
    for (let radio of radios) {
      if (radio.value == value) {
        radio.checked = true;
      }
    }
  },

  trackRadioGroupChange(group_name, callback) {
    const radios = document.getElementsByName(group_name);
    for (let radio of radios) {
      radio.addEventListener("change", callback);
    }
  },

  transformRadioInput(view, input, binding_id, binding_attr) {
    const transformer = this;
    if (!view.hasBinding(binding_id, binding_attr)) {
      // We only need to bind the first radio in the group
      view.registerBinding(binding_id, binding_attr, function (value) {
        transformer.setRadioGroupValue(input.name, value);
      });
    }

    this.setRadioGroupValue(input.name, this.getBoundValue(input, binding_id, binding_attr));

    this.trackRadioGroupChange(input.name, function (evt) {
      transformer.setBoundValue(input, binding_id, binding_attr, evt.target.value);
    });
  },

  transformSelect(view, select, binding_id, binding_attr) {
    const transformer = this;

    view.registerBinding(binding_id, binding_attr, function (value) {
      select.value = value;
    });
    select.value = this.getBoundValue(select, binding_id, binding_attr);
    select.addEventListener("change", function (evt) {
      transformer.setBoundValue(select, binding_id, binding_attr, evt.target.value);
    });
  },

  transformElement(input, view) {
    const [binding_id, binding_attr] = this.decodeBinding(
      input.getAttribute("rez-bind")
    );

    if (input.type === "text" || input.type == "textarea") {
      this.transformTextInput(view, input, binding_id, binding_attr);
    } else if (input.type === "checkbox") {
      this.transformCheckboxInput(view, input, binding_id, binding_attr);
    } else if (input.type === "radio") {
      this.transformRadioInput(view, input, binding_id, binding_attr);
    } else if (
      input.type === "select-one" ||
      input.type === "select-multiple"
    ) {
      this.transformSelect(view, input, binding_id, binding_attr);
    } else {
      console.log(`Unsupported input type: ${input.type}`);
    }
  },
};

window.Rez.RezBindingTransformer = RezBindingTransformer;

//-----------------------------------------------------------------------------
// View
//-----------------------------------------------------------------------------

function RezView(container_id, receiver, layout, transformers) {
  this.container = document.getElementById(container_id);
  if (!this.container) {
    throw "Cannot get container |" + container_id + "|";
  }

  this.layout = layout;
  this.layout_stack = [];
  this.bindings = new Map();
  this.receiver = receiver;
  this.transformers = transformers ?? this.defaultTransformers();
}

RezView.prototype = {
  constructor: RezView,

  getLayout() {
    return this.layout;
  },

  setLayout(layout) {
    this.layout = layout;
  },

  pushLayout(layout) {
    this.layout_stack.push(this.layout);
    this.layout = layout;
  },

  popLayout() {
    this.layout = this.layout_stack.pop();
  },

  render() {
    const html = this.layout.html();
    this.container.innerHTML = html;
  },

  defaultTransformers() {
    return [
      new RezEventLinkTransformer(this.receiver),
      new RezBlockTransformer(),
      new RezButtonTransformer(this.receiver),
      new RezFormTransformer(this.receiver),
      new RezInputTransformer(this.receiver),
      new RezBindingTransformer(this.receiver)
    ];
  },

  transform() {
    this.transformers.forEach((transformer) =>
      transformer.transformElements(this)
    );
  },

  hasBinding(binding_id, binding_attr) {
    return this.bindings.has(`${binding_id}.${binding_attr}`);
  },

  registerBinding(binding_id, binding_attr, callback) {
    this.bindings.set(`${binding_id}.${binding_attr}`, callback);
  },

  updateBoundControls(binding_id, binding_attr, value) {
    const callback = this.bindings.get(`${binding_id}.${binding_attr}`);
    if (typeof callback == "function") {
      callback(value);
    }
  },

  clearBindings() {
    this.bindings.clear();
  },

  update() {
    this.clearBindings();
    this.render();
    this.transform();
  },
};

window.Rez.RezView = RezView;
