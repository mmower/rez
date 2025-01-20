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

class RezBlock {
  #parentBlock;
  #blockType;
  #source;
  #flipped;
  #params;

  constructor(blockType, source, params = {}) {
    this.#parentBlock = null;
    this.#blockType = blockType;
    this.#source = source;
    this.#flipped = false;
    this.#params = params;
  }

  get parentBlock() {
    return this.#parentBlock;
  }

  set parentBlock(block) {
    this.#parentBlock = block;
  }

  get blockType() {
    return this.#blockType;
  }

  get source() {
    return this.#source;
  }

  get flipped() {
    return this.#flipped;
  }

  set flipped(is_flipped) {
    this.#flipped = is_flipped;
  }

  get params() {
    return this.#params;
  }

  set params(params) {
    this.#params = params;
  }

  instantiateIdBinding(id) {
    return $(id);
  }

  instantiatPropertyBinding(ref) {
    const target = $(ref.elem_id);
    return target[ref.attr_name];
  }

  instantiateFunctionBinding(bindings, f) {
    if (this.parentBlock) {
      return f(this, this.parentBlock.source, bindings);
    } else {
      return f(this, null, bindings);
    }
  }

  instantiateBindingPath(p) {
    return p(this.source);
  }

  instantiatePathBinding(path_fn, bindings) {
    return path_fn(bindings);
  }

  resolveBindingValue(bindings, bindingObject) {
    const { source, literal, deref } = bindingObject;

    // Handle literal values first
    if (literal !== undefined) {
      return literal;
    }

    // Validate source
    if (source === undefined || source === null) {
      throw new Error('Binding source is undefined or null');
    }

    // Resolve binding based on source type
    return this.extractBindingValue(bindings, source, deref);
  }

  extractBindingValue(bindings, source, deref = false) {
    let value;
    if (typeof source === "string") {
      value = this.instantiateIdBinding(source);
    } else if (typeof source === "function") {
      value = this.instantiateFunctionBinding(bindings, source);
    } else if (source && typeof source.binding === "function") {
      value = this.instantiatePathBinding(source.binding, bindings);
      
      // Apply dereferencing only for path bindings when deref is true
      if (deref) {
        value = this.dereferenceBoundValue(value);
      }
    } else {
      // Detailed error for unrecognized source type
      throw new Error(`Invalid binding source type: ${typeof source}. 
        Expected string, function, or object with binding function.`);
    }

    return value;
  }

  dereferenceBoundValue(value) {
    if (Array.isArray(value)) {
      return value.map(id => $(id));
    }

    return $(value);
  }

  getBindings(initialBindings) {
    const sourceBindings = this.source.getAttributeValue("bindings", []);

    if(this.source.getAttributeValue("$debug_bindings", false)) {
      console.log(`Binding source: ${this.source.id}`);
      console.log("Inital Bindings");
      console.dir(initialBindings);

      console.log("Bindings");
      console.dir(sourceBindings);
    }

    return sourceBindings.reduce((bindings, bindingObject) => {
      const prefix = bindingObject["prefix"];
      const value = this.resolveBindingValue(bindings, bindingObject);

      bindings[prefix] = value;
      return bindings;
    }, initialBindings);
  }

  bindValues() {
    const initialBindings = {
      block: this,
      params: this.params,
      source: this.source,
      [this.source.bindAs()]: this.source
    };

    return this.getBindings(initialBindings);
  }

  // blocks are a list of id's of other card elements that we
  // want to sub-render and make available to the template of this
  // card. The result is a map of key pairs {block_id, block_render}
  getBlocks() {
    const blocks = this.source.getAttributeValue("blocks", []);
    return blocks.reduce((blockMappings, blockId) => {
      const blockSource = $(blockId);
      blockSource.$parent = this.source;
      const block = new RezBlock("block", blockSource);
      block.parentBlock = this;
      blockMappings[blockId] = block;
      return blockMappings;
    }, {});
  }

  bindBlocks() {
    return this.getBlocks().obj_map((block) => block.html());
  }

  getViewTemplate() {
    return this.source.getViewTemplate(this.flipped);
  }

  parentBindings() {
    if (this.parentBlock) {
      return this.parentBlock.bindValues();
    } else {
      return {};
    }
  }

  bindings() {
    const bindings = {
      ...this.parentBindings(),
      ...this.bindValues(),
      ...this.bindBlocks(),
    };

    return bindings;
  }

  renderBlock() {
    const template = this.getViewTemplate();
    const bindings = this.bindings();
    return template(bindings);
  }

  css_classes() {
    if (this.blockType == "block") {
      return "rez-block";
    } else if (this.blockType == "card") {
      if (this.flipped) {
        return "rez-card rez-flipped-card";
      } else {
        return "rez-card rez-active-card";
      }
    } else {
      throw new Error("This shouldn't happen, right?");
    }
  }

  html() {
    const blockContent = this.renderBlock();

    if(this.source.$suppress_wrapper) {
      return blockContent;
    } else {
      return `<div class="${this.css_classes()}">${blockContent}</div>`;
    }
  }
};

window.Rez.RezBlock = RezBlock;

//-----------------------------------------------------------------------------
// Layout
//-----------------------------------------------------------------------------

class RezLayout extends RezBlock {
  constructor(blockType, source) {
    super(blockType, source);
  }

  addContent(block) {
    throw new Error("Must implement addContent(block)");
  }

  renderContents() {
    throw new Error("Must implement renderContents()");
  }

  bindAs() {
    throw new Error("Must implement bindAs()");
  }

  html() {
    const renderedContent = this.renderContents();
    const templateFn = this.getViewTemplate();
    const boundValues = this.bindValues();
    const boundBlocks = this.bindBlocks();
    return templateFn({
      content: renderedContent,
      ...boundValues,
      ...boundBlocks,
    });
  }
}

//-----------------------------------------------------------------------------
// Single Layout
//
// This Layout holds a single block as it's content
//-----------------------------------------------------------------------------

class RezSingleLayout extends RezLayout {
  #content;
  #sourceName;

  constructor(sourceName, source) {
    super(sourceName, source);
    this.#sourceName = sourceName;
    this.#content = null;
  }

  get content() {
    return this.#content;
  }

  set content(content) {
    this.#content = content;
  }

  bindAs() {
    return this.sourceName;
  }

  addContent(block) {
    block.parentBlock = this;
    this.content = block;
  }

  renderContents() {
    return this.content.html();
  }
}

window.Rez.RezSingleLayout = RezSingleLayout;

//-----------------------------------------------------------------------------
// Stack Layout
//
// This layout holds a list of blocks that are composed to form its content
//-----------------------------------------------------------------------------

class RezStackLayout extends RezLayout {
  #sourceName;
  #contents;

  constructor(sourceName, source) {
    super("scene", source);
    this.#sourceName = sourceName;
    this.#contents = [];
  }

  get contents() {
    return this.#contents;
  }

  // get sourceName() {
  //   return this.#sourceName;
  // }

  bindAs() {
    return this.sourceName;
  }

  get reversed() {
    return this.source.layout_reverse;
  }

  addContent(block) {
    block.parentBlock = this;

    if (this.reversed) {
      this.contents.unshift(block);
    } else {
      this.contents.push(block);
    }
  }

  renderContents() {
    let separator = "";
    if (this.source.layout_separator) {
      separator = this.source.layout_separator;
    }

    return this.contents.map((block) => block.html()).join(separator);
  }
};

window.Rez.RezStackLayout = RezStackLayout;

//-----------------------------------------------------------------------------
// Transformers
//
// A transformer uses a CSS selector to find certain elements in the rendered
// content and do something with them.
//
// The getSelector() method returns a CSS selector that defines which elements
// are to be transformed.
//
// The transformeElement() method should overridden and will get passed each
// matching element and should transform it.
//-----------------------------------------------------------------------------

class RezTransformer {
  #selector;
  #eventName;
  #receiver;

  constructor(selector, eventName = null, receiver = null) {
    if (typeof selector === "undefined") {
      throw "Undefined selector!";
    }
    if (typeof eventName === "undefined") {
      throw "Undefined eventName!";
    }
    if (typeof receiver === "undefined") {
      throw "Undefined receiver!";
    }

    this.#selector = selector;
    this.#eventName = eventName;
    this.#receiver = receiver;
  }

  get selector() {
    return this.#selector;
  }

  get eventName() {
    return this.#eventName;
  }

  get receiver() {
    return this.#receiver;
  }

  get elements() {
    return document.querySelectorAll(this.#selector);
  }

  transformElements(view) {
    this.elements.forEach((elem) => {
      this.transformElement(elem, view);
    });
  }

  transformElement(elem, view) {
    throw "Transformers must implement transformElement(elem, view)!";
  }
}

//-----------------------------------------------------------------------------
// Event Transformers
//
// An Event Transformer is used to add an event handler listener to the
// matching elements.
//
// It expects a receiver property that defines the object which handles
// events raised and an event property that specifies the name of the event
// to be registered.
//
// The receiver is expected to define two methods:
//    handleBrowserEvent
//    dispatchResponse
// the collective define the response to the event.
//-----------------------------------------------------------------------------

class RezEventTransformer extends RezTransformer {
  constructor(selector, event, receiver) {
    super(selector, event, receiver);
  }

  addEventListener(elem) {
    const transformer = this;
    elem.addEventListener(this.eventName, function (evt) {
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
      const receiver = transformer.receiver;
      receiver.dispatchResponse(receiver.handleBrowserEvent(evt));
    });
  }

  transformElement(elem, view) {
    this.addEventListener(elem);
  }
}

//-----------------------------------------------------------------------------
// Block Transformer
//
// A Block Transformer operates on a <div class="card" data-card="...">
// blocks.
//-----------------------------------------------------------------------------
class RezBlockTransformer extends RezTransformer {
  constructor() {
    super("div.rez-card");
  }

  transformElement(elem, view) {
    const elem_id = elem.dataset.card;
    elem.rez_card = $(elem_id);
  }

}

window.Rez.RezBlockTransformer = RezBlockTransformer;

//-----------------------------------------------------------------------------
// Link Transformers
//
// Link Transformers operate on <a data-event="..."> tags within a
// <div class="card">.
//-----------------------------------------------------------------------------

class RezEventLinkTransformer extends RezEventTransformer {
  constructor(receiver) {
    super("div.rez-front-face a[data-event]", "click", receiver);
  }
}

window.Rez.RezEventLinkTransformer = RezEventLinkTransformer;

//-----------------------------------------------------------------------------
// Button Transformer
//-----------------------------------------------------------------------------

class RezButtonTransformer extends RezEventTransformer {
  constructor(receiver) {
    super("div.rez-front-face button[data-event]:not(.inactive)", "click", receiver);
  }
}

window.Rez.RezButtonTransformer = RezButtonTransformer;

//-----------------------------------------------------------------------------
// FormTransformer
//-----------------------------------------------------------------------------

class RezFormTransformer extends RezEventTransformer {
  constructor(receiver) {
    super("div.rez-front-face form[rez-live]", "submit", receiver);
  }
}

window.Rez.RezFormTransformer = RezFormTransformer;

//-----------------------------------------------------------------------------
// InputTransformer
//-----------------------------------------------------------------------------

class RezInputTransformer extends RezEventTransformer {
  constructor(receiver) {
    super("div.rez-front-face input[rez-live]", "input", receiver);
  }
}

window.Rez.RezInputTransformer = RezInputTransformer;

//-----------------------------------------------------------------------------
// BindingTransformer
//-----------------------------------------------------------------------------

class RezBindingTransformer extends RezTransformer {
  constructor(receiver) {
    super("div.rez-front-face input[rez-bind], select[rez-bind], textarea[rez-bind]");
  }

  decodeBinding(binding_expr) {
    const [binding_id, binding_attr] = binding_expr.split(".");
    if (
      typeof binding_id === "undefined" ||
      typeof binding_attr === "undefined"
    ) {
      throw `Unable to parse binding: ${binding_expr}`;
    }

    return [binding_id, binding_attr];
  }

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
  }

  getBoundValue(input, binding_id, binding_attr) {
    return this.getBoundElem(input, binding_id).getAttribute(binding_attr)
  }

  setBoundValue(input, binding_id, binding_attr, value) {
    this.getBoundElem(input, binding_id).setAttribute(binding_attr, value);
  }

  transformTextInput(view, input, binding_id, binding_attr) {
    const transformer = this;

    view.registerBinding(binding_id, binding_attr, function (value) {
      input.value = value;
    });

    input.value = this.getBoundValue(input, binding_id, binding_attr);
    input.addEventListener("input", function (evt) {
      transformer.setBoundValue(input, binding_id, binding_attr, evt.target.value);
    });
  }

  transformCheckboxInput(view, input, binding_id, binding_attr) {
    const transformer = this;

    view.registerBinding(binding_id, binding_attr, function (value) {
      input.checked = value;
    });
    input.checked = this.getBoundValue(input, binding_id, binding_attr);
    input.addEventListener("change", function (evt) {
      transformer.setBoundValue(input, binding_id, binding_attr, evt.target.checked);
    });
  }

  setRadioGroupValue(group_name, value) {
    const radios = document.getElementsByName(group_name);
    for (let radio of radios) {
      if (radio.value == value) {
        radio.checked = true;
      }
    }
  }

  trackRadioGroupChange(group_name, callback) {
    const radios = document.getElementsByName(group_name);
    for (let radio of radios) {
      radio.addEventListener("change", callback);
    }
  }

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
  }

  transformSelect(view, select, binding_id, binding_attr) {
    const transformer = this;

    view.registerBinding(binding_id, binding_attr, function (value) {
      select.value = value;
    });
    select.value = this.getBoundValue(select, binding_id, binding_attr);
    select.addEventListener("change", function (evt) {
      transformer.setBoundValue(select, binding_id, binding_attr, evt.target.value);
    });
  }

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
      throw new Error(`Unsupported input type: ${input.type}`);
    }
  }
}

window.Rez.RezBindingTransformer = RezBindingTransformer;

//-----------------------------------------------------------------------------
// View
//-----------------------------------------------------------------------------

class RezView {
  #container;
  #layout;
  #layoutStack;
  #bindings;
  #receiver;
  #transformers;

  constructor(container_id, receiver, layout, transformers) {
    const container = document.getElementById(container_id);
    if(typeof(container) === "undefined") {
      throw Error(`Cannot get container |${container_id}|`);
    }

    this.#container = document.getElementById(container_id);
    this.#layout = layout;
    this.#layoutStack = [];
    this.#bindings = new Map();
    this.#receiver = receiver;
    this.#transformers = transformers ?? this.defaultTransformers();
  }

  get container() {
    return this.#container;
  }

  get layout() {
    return this.#layout;
  }

  set layout(layout) {
    this.#layout = layout;
  }

  get layoutStack() {
    return this.#layoutStack;
  }

  pushLayout(layout) {
    this.layoutStack.push(this.layout);
    this.layout = layout;
  }

  popLayout() {
    this.layout = this.layoutStack.pop();
  }

  addLayoutContent(content) {
    this.layout.addContent(content);
  }

  get bindings() {
    return this.#bindings;
  }

  get receiver() {
    return this.#receiver;
  }

  get transformers() {
    return this.#transformers;
  }

  render() {
    const html = this.layout.html();
    this.container.innerHTML = html;
  }

  defaultTransformers() {
    return [
      new RezEventLinkTransformer(this.receiver),
      new RezBlockTransformer(),
      new RezButtonTransformer(this.receiver),
      new RezFormTransformer(this.receiver),
      new RezInputTransformer(this.receiver),
      new RezBindingTransformer(this.receiver)
    ];
  }

  transform() {
    this.transformers.forEach((transformer) =>
      transformer.transformElements(this)
    );
  }

  hasBinding(binding_id, binding_attr) {
    return this.bindings.has(`${binding_id}.${binding_attr}`);
  }

  registerBinding(binding_id, binding_attr, callback) {
    this.bindings.set(`${binding_id}.${binding_attr}`, callback);
  }

  updateBoundControls(binding_id, binding_attr, value) {
    const callback = this.bindings.get(`${binding_id}.${binding_attr}`);
    if (typeof callback == "function") {
      callback(value);
    }
  }

  clearBindings() {
    this.bindings.clear();
  }

  update() {
    this.clearBindings();
    this.render();
    this.transform();
  }
}

window.Rez.RezView = RezView;
