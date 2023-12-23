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

let block_proto = {
  instantiateIdBinding(id) {
    return this.source.$(id);
  },

  instantiatPropertyBinding(ref) {
    const target = $(ref.elem_id);
    return target[ref.attr_name];
  },

  instantiateFunctionBinding(f) {
    if (this.parent_block) {
      return f(this, this.parent_block.source);
    } else {
      return f(this);
    }
  },

  instantiateBindingPath(p) {
    return p(this.source);
  },

  // bindings are key-value pairs of the form {name, expr}
  // where an expression is either the id of an element
  // or a function. The result of instantiation is either
  // {name, element_ref} or {name, func_result}
  getBindings() {
    const source_bindings = this.source.getAttributeValue("bindings", {});
    return source_bindings.obj_map((query) => {
      if (typeof query === "string") {
        return this.instantiateIdBinding(query);
      } else if (typeof query === "function") {
        return this.instantiateFunctionBinding(query);
      } else if (typeof query === "object") {
        if (typeof query.attr_ref === "object") {
          return this.instantiatPropertyBinding(query.attr_ref);
        } else if (typeof query.binding === "function") {
          return this.instantiateBindingPath(query.binding);
        } else {
          throw "Invalid binding type: " + typeof query + "!";
        }
      } else {
        throw "Invalid binding type: " + typeof query + "!";
      }
    });
  },

  bindValues() {
    const bindings = {
      $block: this,
      [this.source.bindAs()]: this.source,
      ...this.getBindings(),
    };

    return bindings;
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
        return "card flipped_card";
      } else {
        return "card active_card";
      }
    } else {
      throw "This shouldn't happen, right?";
    }
  },

  assignParams(params) {
    for(const [param, value] of Object.entries(params)) {
      this[param] = value;
    }
  },

  html() {
    return (
      `<div class='${this.css_classes()}'>` + this.renderBlock() + "</div>"
    );
  },
};

function RezBlock(block_type, source, params = {}) {
  this.parent_block = null;
  this.block_type = block_type;
  this.source = source;
  this.flipped = false;
  this.assignParams(params);
}

RezBlock.prototype = block_proto;
RezBlock.prototype.constructor = RezBlock;
window.Rez.block = RezBlock;

// //-----------------------------------------------------------------------------
// // Synthetic Source
// //-----------------------------------------------------------------------------

// let synthetic_source_proto = {
//   __proto__: window.Rez.basic_object,

//   get viewTemplate() {
//     return this.getAttribute("template");
//   },
// };

// function RezSyntheticSource(template) {
//   this.id = String.randomId();
//   this.game_object_type = "synthetic_source";
//   this.attributes = {
//     template: template,
//   };
// }

// RezSyntheticSource.prototype = synthetic_source_proto;
// RezSyntheticSource.prototype.constructor = RezSyntheticSource;
// window.Rez.synthetic_source = RezSyntheticSource;

//-----------------------------------------------------------------------------
// Layout
//-----------------------------------------------------------------------------

let layout_proto = {
  __proto__: block_proto,

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

let single_layout_proto = {
  __proto__: layout_proto,

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

function RezSingleLayout(source_name, source) {
  RezBlock.call(this, "scene", source);
  this.source_name = source_name;
  this.content = null;
}

RezSingleLayout.prototype = single_layout_proto;
RezSingleLayout.prototype.constructor = RezSingleLayout;
window.Rez.single_layout = RezSingleLayout;

//-----------------------------------------------------------------------------
// Stack Layout
//
// This layout holds a list of blocks that are composed to form its content
//-----------------------------------------------------------------------------

let stack_layout_proto = {
  __proto__: layout_proto,

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

function RezStackLayout(source_name, source) {
  RezBlock.call(this, "scene", source);
  this.source_name = source_name;
  this.contents = [];
}

RezStackLayout.prototype = stack_layout_proto;
RezStackLayout.prototype.constructor = RezStackLayout;
window.Rez.stack_layout = RezStackLayout;

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

  dispatchResponse(response) {
    if (typeof response == "object") {
      if (response.scene) {
        this.receiver.startSceneWithId(response.scene);
      }

      if (response.card) {
        this.receiver.playCard(response.card);
      }

      if (response.flash) {
        this.receiver.addFlashMessage(response.flash);
      }

      if (response.render) {
        this.receiver.updateView();
      }

      if (response.error) {
        console.log(`Error: ${response.error}`);
      }
    } else if (typeof response == "undefined") {
      throw "Event handlers must return an object with at least one key from: [scene, card, flash, render, error, nop]!";
    }
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
      transformer.dispatchResponse(receiver.handleBrowserEvent(evt));
    });
  },

  transformElement(elem) {
    this.addEventListener(elem, this.getEventName());
  },
};

//-----------------------------------------------------------------------------
// Link Transformers
//-----------------------------------------------------------------------------

let event_link_transformer_proto = {
  __proto__: event_transformer_proto,

  transformElement(elem) {
    this.addEventListener(elem, this.getEventName());
  },
};

function RezEventLinkTransformer(receiver) {
  this.selector = "div.card a:not(.inactive)";
  this.event = "click";
  this.receiver = receiver;
}

RezEventLinkTransformer.prototype = event_link_transformer_proto;

//-----------------------------------------------------------------------------
// Button Transformer
//-----------------------------------------------------------------------------

const button_transformer_proto = {
  __proto__: event_transformer_proto,

  transformElement(elem) {
    this.addEventListener(elem, this.getEventName());
  },
};

function RezButtonTransformer(receiver) {
  this.selector = "div.card button[data-event]:not(.inactive)";
  this.event = "click";
  this.receiver = receiver;
}

RezButtonTransformer.prototype = button_transformer_proto;

//-----------------------------------------------------------------------------
// FormTransformer
//-----------------------------------------------------------------------------

function RezFormTransformer(receiver) {
  this.selector = "div.card form[rez-live]";
  this.event = "submit";
  this.receiver = receiver;
}

RezFormTransformer.prototype = event_transformer_proto;

//-----------------------------------------------------------------------------
// InputTransformer
//-----------------------------------------------------------------------------

function RezInputTransformer(receiver) {
  this.selector = "div.card input[rez-live]";
  this.event = "input";
  this.receiver = receiver;
}

RezInputTransformer.prototype = event_transformer_proto;

//-----------------------------------------------------------------------------
// BindingTransformer
//-----------------------------------------------------------------------------

const binding_transformer_proto = {
  __proto__: event_transformer_proto,

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

  transformTextInput(view, input, binding_id, binding_attr) {
    view.registerBinding(binding_id, binding_attr, function (value) {
      input.value = value;
    });
    input.value = $(binding_id)[binding_attr];
    input.addEventListener("input", function (evt) {
      $(binding_id).setAttribute(binding_attr, evt.target.value);
    });
  },

  transformCheckboxInput(view, input, binding_id, binding_attr) {
    view.registerBinding(binding_id, binding_attr, function (value) {
      input.checked = value;
    });
    input.checked = $(binding_id)[binding_attr];
    input.addEventListener("change", function (evt) {
      $(binding_id).setAttribute(binding_attr, evt.target.checked);
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

    this.setRadioGroupValue(input.name, $(binding_id)[binding_attr]);

    this.trackRadioGroupChange(input.name, function (evt) {
      $(binding_id).setAttribute(binding_attr, evt.target.value);
    });
  },

  transformSelect(view, select, binding_id, binding_attr) {
    view.registerBinding(binding_id, binding_attr, function (value) {
      select.value = value;
    });
    select.value = $(binding_id)[binding_attr];
    select.addEventListener("change", function (evt) {
      $(binding_id).setAttribute(binding_attr, evt.target.value);
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

function RezBindingTransformer(receiver) {
  this.selector =
    "div.card input[rez-bind], select[rez-bind], textarea[rez-bind]";
  this.receiver = receiver;
}

RezBindingTransformer.prototype = binding_transformer_proto;

//-----------------------------------------------------------------------------
// View
//-----------------------------------------------------------------------------

let view_proto = {
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
      new RezButtonTransformer(this.receiver),
      new RezFormTransformer(this.receiver),
      new RezInputTransformer(this.receiver),
      new RezBindingTransformer(this.receiver),
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

RezView.prototype = view_proto;
RezView.prototype.constructor = RezView;
