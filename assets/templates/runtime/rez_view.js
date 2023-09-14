//-----------------------------------------------------------------------------
// Templates use this for conditionals
//-----------------------------------------------------------------------------

function evaluateExpression(expression, bindings) {
  const proxy = new Proxy(
    {},
    {
      get: (target, property) => {
        if (bindings.hasOwnProperty(property)) {
          return bindings[property];
        }
        return undefined; // Or return some default value if you prefer.
      },
    }
  );

  const argNames = Object.keys(bindings);
  const argValues = argNames.map((name) => proxy[name]);

  // Create a new function with bindings as arguments and the expression as the body
  const func = new Function(...argNames, `return ${expression};`);

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

  instantiateFunctionBinding(f) {
    return f(this);
  },

  // bindings are key-value pairs of the form {name, expr}
  // where an expression is either the id of an element
  // or a function. The result of instantiation is either
  // {name, element_ref} or {name, func_result}
  getBindings() {
    return this.source.getAttributeValue("bindings", {}).obj_map((query) => {
      if (typeof query == "string") {
        return this.instantiateIdBinding(query);
      } else if (typeof query == "function") {
        return this.instantiateFunctionBinding(query);
      } else {
        throw "Invalid binding type: " + typeof query + "!";
      }
    });
  },

  bindAs() {
    return "card";
  },

  bindValues() {
    return {
      [this.bindAs()]: this.source,
      ...this.getBindings(),
    };
  },

  // blocks are a list of id's of other card elements that we
  // want to sub-render and make available to the template of this
  // card. The result is a map of key pairs {block_id, block_render}
  getBlocks() {
    const blocks = this.source.getAttributeValue("blocks", []);
    return blocks.reduce((block_mappings, block_id) => {
      const block_card = this.source.$(block_id);
      const block = new RezBlock("block", block_card);
      block.parent_block = this;
      block_mappings[block_id] = block;
      return block_mappings;
    }, {});
  },

  bindBlocks() {
    return this.getBlocks().obj_map((block) => block.html());
  },

  getViewTemplate() {
    return this.source.viewTemplate;
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

  getCSSClasses(block_type) {
    if (block_type === "card") {
    }

    return ["card_wrapper", block_type, prefix + block_type].join(" ");
  },

  css_classes() {
    if (this.block_type == "block") {
      return "block";
    } else if (this.block_type == "card") {
      if (this.source.$flipped) {
        return "card flipped_card";
      } else {
        return "card active_card";
      }
    } else {
      throw "This shouldn't happen, right?";
    }
  },

  html() {
    return (
      `<div class='${this.css_classes()}'>` + this.renderBlock() + "</div>"
    );
  },
};

function RezBlock(block_type, source) {
  this.parent_block = null;
  this.block_type = block_type;
  this.source = source;
}

RezBlock.prototype = block_proto;
RezBlock.prototype.constructor = RezBlock;
window.Rez.block = RezBlock;

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

  addContent(block) {
    block.parent_block = this;
    this.contents.push(block);
  },

  bindAs() {
    return this.source_name;
  },

  renderContents() {
    return this.contents.map((block) => block.html()).join("");
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

  transformElements() {
    this.getElements().forEach(function (elem) {
      this.transformElement(elem);
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
    const receiver = this.getReceiver();
    elem.addEventListener(event, function (evt) {
      evt.preventDefault();

      // A handler can return an object with keys representing actions to
      // be taken after the handler is complete. For example {scene: "xxx"}
      // would then set the current scene to "xxx".
      //
      // Why is this better than the handler doing this and returning?
      //
      // Potentially it could mean that we require a return to validate that
      // the handler has completed properly.
      //
      // It also means we can circumscribe the final action of any given
      // handler.
      //
      // 1) We know that a handler has taken a correct action
      // 2) Potentially different handlers can interact

      const response = receiver.handleBrowserEvent(evt);
      if (typeof response == "object") {
        if (response.scene) {
          receiver.startSceneWithId(response.scene);
        }

        if (response.card) {
          receiver.playCard(response.card);
        }

        if (response.flash) {
          receiver.addFlashMessage(response.flash);
        }

        if (response.render) {
          receiver.updateView();
        }

        if (response.error) {
          console.log("Error: " + response.error);
        }
      } else if (typeof response == "undefined") {
        throw "Event handlers must return a value, preferably an exec-object!";
      }
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
      new RezFormTransformer(this.receiver),
      new RezInputTransformer(this.receiver),
    ];
  },

  transform() {
    this.transformers.forEach((transformer) => transformer.transformElements());
  },

  update() {
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
  this.receiver = receiver;
  this.transformers = transformers ?? this.defaultTransformers();
}

RezView.prototype = view_proto;
RezView.prototype.constructor = RezView;
