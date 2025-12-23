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
// Block
//
// Special $ attributes recognized by RezBlock:
//   $debug_bindings  - When true, logs binding information to console during render
//   $suppress_wrapper - When true, omits the wrapper <div> around block content
//   $parent          - Reference to the parent source element in the hierarchy
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

  set blockType(type) {
    this.#blockType = type;
  }

  get source() {
    return this.#source;
  }

  set source(source) {
    this.#source = source;
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

  instantiatePropertyBinding(ref) {
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
    } else if(Rez.isElementRef(source)) {
      value = this.instantiateIdBinding(source.$ref);
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
      return value.map(ref => $(ref));  // $(ref) now handles both string and {$ref: "id"} formats
    }

    return $(value);  // $(value) now handles both string and {$ref: "id"} formats
  }

  getBindings(initialBindings) {
    const sourceBindings = this.source.getAttributeValue("bindings", []);

    if(this.source.getAttributeValue("$debug_bindings", false)) {
      console.log(`Binding source: ${this.source.id}`);
      console.log("Initial Bindings");
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
      ...this.parentBindings(),
      block: this,
      params: this.params,
      source: this.source,
      [this.source.bindAs()]: this.source
    };

    return this.getBindings(initialBindings);
  }

  // blocks are a binding list of other card elements that we
  // want to sub-render and make available to the template of this
  // card. The result is a map of key pairs {binding_name, block_render}
  getBlocks() {
    const blocks = this.source.getAttributeValue("blocks", []);
    return blocks.reduce((blockMappings, item) => {
      // Binding: {prefix: "name", source: {$ref: "card_id"}}
      const bindingName = item.prefix;
      const blockSource = $(item.source);
      blockSource.$parent = this.source;
      const block = new RezBlock("block", blockSource);
      block.parentBlock = this;
      blockMappings[bindingName] = block;
      return blockMappings;
    }, {});
  }

  bindBlocks() {
    return this.getBlocks().objMap((block) => block.html());
  }

  getViewTemplate() {
    return this.source.getViewTemplate(this.flipped);
  }

  parentBindings() {
    if (this.parentBlock) {
      return this.parentBlock.bindings();
    } else {
      return {};
    }
  }

  bindings() {
    const bindings = {
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
      throw new Error(`Attempt to get css_classes for unexpected block type: '${this.blockType}'`);
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

  copy() {
    const copy = new RezBlock(this.blockType, this.source, this.params);
    copy.parentBlock = this.parentBlock;
    copy.flipped = this.flipped;
    return copy;
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
      ...this.parentBindings(),
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

  constructor(sourceName, source) {
    super(sourceName, source);
    this.#content = null;
  }

  bindAs() {
    return this.blockType;
  }

  addContent(block) {
    block.parentBlock = this;
    this.#content = block;
  }

  renderContents() {
    return this.#content.html();
  }

  copy() {
    const copy = new RezSingleLayout(this.blockType, this.source);
    copy.parentBlock = this.parentBlock;
    copy.flipped = this.flipped;
    copy.params = this.params;
    if (this.#content) {
      copy.addContent(this.#content.copy());
    }
    return copy;
  }
}

window.Rez.RezSingleLayout = RezSingleLayout;

//-----------------------------------------------------------------------------
// Stack Layout
//
// This layout holds a list of blocks that are composed to form its content
//-----------------------------------------------------------------------------

class RezStackLayout extends RezLayout {
  #contents;

  constructor(sourceName, source) {
    super(sourceName, source);
    this.#contents = [];
  }

  bindAs() {
    return this.blockType;
  }

  get reversed() {
    return this.source.layout_reverse;
  }

  addContent(block) {
    block.parentBlock = this;

    if (this.reversed) {
      this.#contents.unshift(block);
    } else {
      this.#contents.push(block);
    }
  }

  renderContents() {
    let separator = "";
    if (this.source.layout_separator) {
      separator = this.source.layout_separator;
    }

    return this.#contents.map((block) => block.html()).join(separator);
  }

  copy() {
    const copy = new RezStackLayout(this.blockType, this.source);
    copy.parentBlock = this.parentBlock;
    copy.flipped = this.flipped;
    copy.params = this.params;
    for (const block of this.#contents) {
      copy.addContent(block.copy());
    }
    return copy;
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
// The transformElement() method should overridden and will get passed each
// matching element and should transform it.
//-----------------------------------------------------------------------------

class RezTransformer {
  #selector;
  #eventName;
  #receiver;

  constructor(selector, eventName = null, receiver = null) {
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
    throw new Error("Transformers must implement transformElement(elem, view)!");
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
    super("div.rez-card div[data-card]");
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
    super("div.rez-front-face a[data-event], div.rez-active-card a[data-event]", "click", receiver);
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
    super("div.rez-front-face input[rez-live], div.rez-front-face select[rez-live], div.rez-front-face textarea[rez-live]", "input", receiver);
  }
}

window.Rez.RezInputTransformer = RezInputTransformer;

//-----------------------------------------------------------------------------
// EnterKeyTransformer
//-----------------------------------------------------------------------------

class RezEnterKeyTransformer extends RezEventTransformer {
  constructor(receiver) {
    super("div.rez-front-face form[rez-live] input[type='text'], div.rez-front-face form[rez-live] input[type='email'], div.rez-front-face form[rez-live] input[type='password'], div.rez-front-face form[rez-live] input[type='search'], div.rez-front-face form[rez-live] input[type='url'], div.rez-front-face form[rez-live] input[type='tel'], div.rez-front-face form[rez-live] input[type='number'], div.rez-front-face form[rez-live] input:not([type])", "keydown", receiver);
  }

  addEventListener(elem) {
    const transformer = this;
    elem.addEventListener(this.eventName, function (evt) {
      if(evt.key === "Enter") {
        evt.preventDefault();

        // Find the parent form
        const form = evt.target.closest("form[rez-live]");

        if(form) {
          const formName = form.getAttribute("name");

          if(!formName) {
            console.error("RezEnterKeyTransformer: Form has no name attribute!");
            return;
          }

          // Create a synthetic submit event with correct target and type
          const submitEvent = new Event("submit", { bubbles: true, cancelable: true });
          Object.defineProperty(submitEvent, 'target', { value: form, enumerable: true });
          Object.defineProperty(submitEvent, 'type', { value: 'submit', enumerable: true });

          // Use the receiver's handleBrowserEvent method (which routes to handleBrowserSubmitEvent)
          transformer.receiver.dispatchResponse(
            transformer.receiver.handleBrowserEvent(submitEvent)
          );
        } else {
          console.error("RezEnterKeyTransformer: No rez-live form found!");
        }
      }
    });
  }
}

window.Rez.RezEnterKeyTransformer = RezEnterKeyTransformer;

//-----------------------------------------------------------------------------
// BindingTransformer
//-----------------------------------------------------------------------------

class RezBindingTransformer extends RezTransformer {
  constructor(receiver) {
    super("div.rez-front-face input[rez-bind], div.rez-front-face select[rez-bind], div.rez-front-face textarea[rez-bind], div.rez-active-card input[rez-bind], div.rez-active-card select[rez-bind], div.rez-active-card textarea[rez-bind]");
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
      if(!card_el) {
        throw new Error(`Unable to find nearest @card to input`);
      }
      return card_el.rez_card;
    } else {
      return $(binding_id);
    };
  }

  getBoundValue(input, boundRezElementId, boundAttrName) {
    const elem = this.getBoundElem(input, boundRezElementId);
    if(elem === undefined) {
      throw new Error(`Failed to find game element for attribute binding: ${boundRezElementId}`);
    }
    return elem.getAttribute(boundAttrName)
  }

  setBoundValue(input, boundRezElementId, boundAttrName, value) {
    const elem = this.getBoundElem(input, boundRezElementId);
    if(typeof(elem) === "undefined") {
      throw new Error(`Failed to find game element for attribute binding: ${boundRezElementId}`);
    }
    elem.setAttribute(boundAttrName, value);
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
    input.addEventListener("input", function (evt) {
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
      radio.addEventListener("input", callback);
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
    select.addEventListener("input", function (evt) {
      transformer.setBoundValue(select, binding_id, binding_attr, evt.target.value);
    });
  }

  transformElement(input, view) {
    const [binding_id, binding_attr] = this.decodeBinding(
      input.getAttribute("rez-bind")
    );

    if (input.type === "text" || input.tagName.toLowerCase() === "textarea") {
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
    if(!container) {
      throw Error(`Cannot get container |${container_id}|`);
    }

    this.#container = container;
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

  // Note: Event listeners added by transformers are automatically cleaned up when
  // innerHTML is replaced - no explicit cleanup needed. The DOM elements holding
  // the listeners are destroyed, allowing garbage collection of the closures.
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
      new RezBindingTransformer(this.receiver),
      new RezInputTransformer(this.receiver),
      new RezEnterKeyTransformer(this.receiver)
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
    if (typeof callback === "function") {
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

  copy() {
    const copy = new RezView(
      this.container.id,
      this.receiver,
      this.layout.copy(),
      this.transformers
    );
    for (const layout of this.#layoutStack) {
      copy.#layoutStack.push(layout.copy());
    }
    // bindings are cleared on each render, no need to copy
    return copy;
  }
}

window.Rez.RezView = RezView;
