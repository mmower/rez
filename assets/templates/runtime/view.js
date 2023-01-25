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
      if(typeof(query) == "string") {
        return this.instantiateIdBinding(query);
      } else if(typeof(query) == "function") {
        return this.instantiateFunctionBinding(query);
      } else {
        throw "Invalid binding type: " + typeof(query) + "!";
      }
    });
  },

  bindValues() {
    this.bound_values = this.bound_values ?? this.getBindings();
    return this.bound_values;
  },

  // blocks are a list of id's of other card elements that we
  // want to sub-render and make available to the template of this
  // card. The result is a map of key pairs {block_id, block_render}
  getBlocks() {
    const blocks = this.source.getAttributeValue("blocks", []);
    return blocks.reduce((block_mappings, block_id) => {
      const block = this.source.$(block_id);
      block_mappings[block_id] = new RezBlock(block);
      return block_mappings;
    }, {});
  },

  bindBlocks(active) {
    if(!this.bound_blocks) {
      const blocks = this.getBlocks();
      this.bound_blocks = blocks.obj_map((block) => block.html("block", active));
    }

    return this.bound_blocks;
  },

  validate_block_type(t) {
    if(!(t == "block" || t == "card")) {
      throw "Invalid card render type: |" + t + "|!";
    }
  },

  getTemplate() {
    return this.source.template;
  },

  renderBlock(block_type, active) {
    return this.getTemplate()({
      [block_type]: this.source,
      ...this.bindValues(),
      ...this.bindBlocks(active)
    });
  },

  getCSSClasses(block_type, active) {
    const prefix = active ? "active_" : "inactive_";
    return ["card_wrapper", block_type, prefix + block_type].join(" ");
  },

  html(block_type, active) {
    this.validate_block_type(block_type);
    return "<div class='" + this.getCSSClasses(block_type, active) + "'>" + this.renderBlock(block_type, active) + "</div>";
  }
};

function RezBlock(source) {
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

  html() {
    const content = this.renderContents();
    const template_fn = this.getTemplate();
    const bound_values = this.bindValues();
    const bound_blocks = this.bindBlocks(true);
    return template_fn({
      content: content,
      ...bound_values,
      ...bound_blocks
    });
  }
};

//-----------------------------------------------------------------------------
// Single Layout
//
// This Layout holds a single block as it's content
//-----------------------------------------------------------------------------

let single_layout_proto = {
  __proto__: layout_proto,

  addContent(block) {
    this.content = block;
  },

  renderContents() {
    return this.content.html("card", true);
  }
}

function RezSingleLayout(source) {
  this.source = source;
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
    this.contents.push(block);
  },

  renderContents() {
    const last_index = this.contents.length - 1;
    return this.contents.map((block, idx) => {
      return block.html("card", idx == last_index);
    }).join("");
  }
}

function RezStackLayout(source) {
  this.source = source;
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
    if(typeof(this.selector) == "undefined") {
      throw "Undefined selector!";
    }
    return this.selector;
  },

  getElements() {
    return document.querySelectorAll(this.getSelector());
  },

  transformElements() {
    this.getElements().forEach(function(elem) {
      this.transformElement(elem);
    }, this);
  },

  transformElement(elem) {
    throw "Transformers must implement transformElement(e)!";
  }
};

//-----------------------------------------------------------------------------
// Event Transformers
//-----------------------------------------------------------------------------

let event_transformer_proto = {
  __proto__: transformer_proto,

  getReceiver() {
    if(typeof(this.receiver) == "undefined") {
      throw "Undefined receiver!";
    }
    return this.receiver;
  },

  getEventName() {
    if(typeof(this.event) == "undefined") {
      throw "Undefined event!";
    }
    return this.event;
  },

  addEventListener(elem, event) {
    const receiver = this.getReceiver();
    elem.addEventListener(event, function(evt) {
      evt.preventDefault();
      if(!receiver.handleBrowserEvent(evt)) {
        throw "Unhandled " + event + " event!";
      }
    });
  },

  transformElement(elem) {
    this.addEventListener(elem, this.getEventName());
  }
}

//-----------------------------------------------------------------------------
// Link Transformers
//-----------------------------------------------------------------------------

let deactivate_link_transformer_proto = {
  __proto__: transformer_proto,

  transformElement(elem) {
    elem.classList.add("inactive");
  }
};

function RezDeactivateLinkTransformer() {
  this.selector = "a";
}

RezDeactivateLinkTransformer.prototype = deactivate_link_transformer_proto;

let event_link_transformer_proto = {
  __proto__: event_transformer_proto,

  transformElement(elem) {
    elem.classList.remove("inactive");
    elem.classList.add("active");
    this.addEventListener(elem, this.getEventName());
  }
};

function RezEventLinkTransformer(receiver) {
  this.selector = "div.active_card a, div.active_block a";
  this.event = "click";
  this.receiver = receiver;
}

RezEventLinkTransformer.prototype = event_link_transformer_proto;

//-----------------------------------------------------------------------------
// FormTransformer
//-----------------------------------------------------------------------------

function RezFormTransformer(receiver) {
  this.selector = "div.active_card form[rez-live], div.active_block form[rez-live]";
  this.event = "submit";
  this.receiver = receiver;
}

RezFormTransformer.prototype = event_transformer_proto;

//-----------------------------------------------------------------------------
// InputTransformer
//-----------------------------------------------------------------------------

function RezInputTransformer(receiver) {
  this.selector = "div.active_card input[rez-live], div.active_block input[rez-live]";
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
      new RezDeactivateLinkTransformer(),
      new RezEventLinkTransformer(this.receiver),
      new RezFormTransformer(this.receiver),
      new RezInputTransformer(this.receiver)
    ];
  },

  transform() {
    this.transformers.forEach((transformer) => transformer.transformElements());
  },

  update() {
    this.render();
    this.transform();
  }
};

function RezView(container_id, receiver, layout, transformers) {
  this.container = document.getElementById(container_id);
  if(!this.container) {
    throw "Cannot get container |"+container_id+"|";
  }

  this.layout = layout;
  this.layout_stack = [];
  this.receiver = receiver;
  this.transformers = transformers ?? this.defaultTransformers();
}

RezView.prototype = view_proto;
RezView.prototype.constructor = RezView;
