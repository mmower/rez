//-----------------------------------------------------------------------------
// Expression Evaluation
//-----------------------------------------------------------------------------

/**
 * @function evaluateExpression
 * @description Evaluates a JavaScript expression string with access to provided bindings.
 *
 * Creates a sandboxed function that can access binding values by name,
 * then executes it with those values. Used by templates for conditionals
 * and dynamic expressions.
 *
 * @param {string} expression - The JavaScript expression to evaluate
 * @param {Object} bindings - Object mapping variable names to their values
 * @param {boolean} [rval=true] - If true, wraps expression in return statement
 * @returns {*} The result of evaluating the expression
 *
 * @example
 * // Evaluate a conditional
 * evaluateExpression("score > 10", { score: 15 }); // returns true
 *
 * @example
 * // Evaluate without return value (for side effects)
 * evaluateExpression("console.log(name)", { name: "Player" }, false);
 */
function evaluateExpression(expression, bindings, rval = true) {
  const proxy = new Proxy(
    {},
    {
      // We ignore the target ({} above) its just there to act
      // as a blank canvas for the proxy which will route everything
      // to bindings.
      get: (_target, property) => {
        if(Object.hasOwn(bindings, property)) {
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

// Expose globally so functions restored from saves (via new Function()) can access it
window.evaluateExpression = evaluateExpression;

//-----------------------------------------------------------------------------
// Block
//-----------------------------------------------------------------------------

/**
 * @class RezBlock
 * @category Internal
 * @description Represents a renderable block of content within the view hierarchy.
 *
 * A block wraps a source element (typically a card or other game element)
 * and handles:
 * - Resolving data bindings from the source element
 * - Rendering the source's template with bound values
 * - Managing nested blocks
 * - Generating HTML output with appropriate CSS classes
 *
 * Blocks can be nested within layouts to create complex view hierarchies.
 * Each block maintains a reference to its parent block, enabling bindings
 * to flow down through the hierarchy.
 *
 * Special $ attributes recognized by RezBlock:
 * - `$debug_bindings` - When true, logs binding information to console during render
 * - `$suppress_wrapper` - When true, omits the wrapper `<div>` around block content
 * - `$parent` - Reference to the parent source element in the hierarchy
 */
class RezBlock {
  /** @type {RezBlock|null} */
  #parentBlock;
  /** @type {string} */
  #blockType;
  /** @type {Object} */
  #source;
  /** @type {boolean} */
  #flipped;
  /** @type {Object} */
  #params;

  /**
   * @function constructor
   * @memberof RezBlock
   * @description Creates a new RezBlock.
   *
   * @param {string} blockType - The type of block ("block" or "card")
   * @param {Object} source - The source element to render (e.g., a RezCard)
   * @param {Object} [params={}] - Additional parameters passed to the template
   */
  constructor(blockType, source, params = {}) {
    this.#parentBlock = null;
    this.#blockType = blockType;
    this.#source = source;
    this.#flipped = false;
    this.#params = params;
  }

  /**
   * The parent block in the view hierarchy.
   * @type {RezBlock|null}
   */
  get parentBlock() {
    return this.#parentBlock;
  }

  set parentBlock(block) {
    this.#parentBlock = block;
  }

  /**
   * The type of this block ("block" or "card").
   * @type {string}
   */
  get blockType() {
    return this.#blockType;
  }

  set blockType(type) {
    this.#blockType = type;
  }

  /**
   * The source element being rendered.
   * @type {Object}
   */
  get source() {
    return this.#source;
  }

  set source(source) {
    this.#source = source;
  }

  /**
   * Whether this block is showing its flipped (back) side.
   * @type {boolean}
   */
  get flipped() {
    return this.#flipped;
  }

  set flipped(is_flipped) {
    this.#flipped = is_flipped;
  }

  /**
   * Additional parameters passed to the template.
   * @type {Object}
   */
  get params() {
    return this.#params;
  }

  set params(params) {
    this.#params = params;
  }

  /**
   * Resolves an element ID to its corresponding game element.
   *
   * @param {string} id - The element ID to resolve
   * @returns {Object} The resolved game element
   */
  instantiateIdBinding(id) {
    return $(id);
  }

  /**
   * Resolves a property reference to its value.
   *
   * @param {Object} ref - Property reference with elem_id and attr_name
   * @param {string} ref.elem_id - The element ID
   * @param {string} ref.attr_name - The attribute name to read
   * @returns {*} The attribute value
   */
  instantiatePropertyBinding(ref) {
    const target = $(ref.elem_id);
    return target[ref.attr_name];
  }

  /**
   * Invokes a function binding with the current context.
   *
   * @param {Object} bindings - Current bindings object
   * @param {Function} f - The function to invoke
   * @returns {*} The function's return value
   */
  instantiateFunctionBinding(bindings, f) {
    if(this.parentBlock) {
      return f(this, this.parentBlock.source, bindings);
    } else {
      return f(this, null, bindings);
    }
  }

  /**
   * Resolves a binding path function against the source.
   *
   * @param {Function} p - Path function to invoke
   * @returns {*} The resolved value
   */
  instantiateBindingPath(p) {
    return p(this.source);
  }

  /**
   * Resolves a path binding function with current bindings.
   *
   * @param {Function} path_fn - Path function to invoke
   * @param {Object} bindings - Current bindings object
   * @returns {*} The resolved value
   */
  instantiatePathBinding(path_fn, bindings) {
    return path_fn(bindings);
  }

  /**
   * Resolves a binding object to its actual value.
   *
   * Handles literal values directly, otherwise delegates to extractBindingValue
   * for source-based resolution.
   *
   * @param {Object} bindings - Current bindings object
   * @param {Object} bindingObject - The binding specification
   * @param {*} [bindingObject.literal] - A literal value (used directly if present)
   * @param {*} [bindingObject.source] - Source for value resolution
   * @param {boolean} [bindingObject.deref] - Whether to dereference the result
   * @returns {*} The resolved binding value
   * @throws {Error} If source is undefined or null when no literal is provided
   */
  resolveBindingValue(bindings, bindingObject) {
    const { source, literal, deref } = bindingObject;

    // Handle literal values first
    if(literal !== undefined) {
      return literal;
    }

    // Validate source
    if(source === undefined || source === null) {
      throw new Error('Binding source is undefined or null');
    }

    // Resolve binding based on source type
    return this.extractBindingValue(bindings, source, deref);
  }

  /**
   * Extracts a value from a binding source.
   *
   * Supports multiple source types:
   * - String: Treated as an element ID
   * - Element reference ({$ref: "id"}): Resolved to the element
   * - Function: Invoked with block context
   * - Object with binding function: Path-based resolution
   *
   * @param {Object} bindings - Current bindings object
   * @param {string|Function|Object} source - The binding source
   * @param {boolean} [deref=false] - Whether to dereference the result
   * @returns {*} The extracted value
   * @throws {Error} If source type is not recognized
   */
  extractBindingValue(bindings, source, deref = false) {
    let value;
    if(typeof source === "string") {
      value = this.instantiateIdBinding(source);
    } else if(Rez.isElementRef(source)) {
      value = this.instantiateIdBinding(source.$ref);
    } else if(typeof source === "function") {
      value = this.instantiateFunctionBinding(bindings, source);
    } else if(source && typeof source.binding === "function") {
      value = this.instantiatePathBinding(source.binding, bindings);

      // Apply dereferencing only for path bindings when deref is true
      if(deref) {
        value = this.dereferenceBoundValue(value);
      }
    } else {
      // Detailed error for unrecognized source type
      throw new Error(`Invalid binding source type: ${typeof source}.
        Expected string, function, or object with binding function.`);
    }

    return value;
  }

  /**
   * Dereferences element references to their actual elements.
   *
   * Handles both single values and arrays of values.
   *
   * @param {string|Object|Array} value - Value(s) to dereference
   * @returns {Object|Array<Object>} The dereferenced element(s)
   */
  dereferenceBoundValue(value) {
    if(Array.isArray(value)) {
      return value.map(ref => $(ref));  // $(ref) now handles both string and {$ref: "id"} formats
    }

    return $(value);  // $(value) now handles both string and {$ref: "id"} formats
  }

  /**
   * Builds the bindings object from the source element's bindings attribute.
   *
   * Processes each binding specification, resolving sources to values and
   * adding them to the bindings object with their specified prefixes.
   *
   * @param {Object} initialBindings - Initial bindings to extend
   * @returns {Object} The complete bindings object
   */
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
      const prefix = bindingObject.prefix;
      const value = this.resolveBindingValue(bindings, bindingObject);

      bindings[prefix] = value;
      return bindings;
    }, initialBindings);
  }

  /**
   * Creates the complete value bindings for template rendering.
   *
   * Combines parent bindings with this block's bindings, adding:
   * - `block`: Reference to this block
   * - `params`: The params object
   * - `source`: The source element
   * - Source's bindAs name: The source element (aliased)
   *
   * @returns {Object} Complete bindings object for template rendering
   */
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

  /**
   * Retrieves and instantiates nested blocks from the source's blocks attribute.
   *
   * Each block specification defines a binding name and source element.
   * The blocks are instantiated as RezBlock instances with this block as parent.
   *
   * @returns {Object} Map of binding names to RezBlock instances
   */
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

  /**
   * Renders all nested blocks to HTML.
   *
   * @returns {Object} Map of binding names to rendered HTML strings
   */
  bindBlocks() {
    return this.getBlocks().objMap((block) => block.html());
  }

  /**
   * Gets the view template function for this block.
   *
   * @returns {Function} Template function that accepts bindings and returns HTML
   */
  getViewTemplate() {
    return this.source.getViewTemplate(this.flipped);
  }

  /**
   * Gets bindings from the parent block, if any.
   *
   * @returns {Object} Parent bindings or empty object
   */
  parentBindings() {
    if(this.parentBlock) {
      return this.parentBlock.bindValues();
    } else {
      return {};
    }
  }

  /**
   * Computes complete bindings including values and rendered blocks.
   *
   * @returns {Object} Complete bindings object
   */
  bindings() {
    const bindings = {
      ...this.bindValues(),
      ...this.bindBlocks(),
    };

    return bindings;
  }

  /**
   * Renders the block content using its template and bindings.
   *
   * @returns {string} Rendered HTML content
   */
  renderBlock() {
    const template = this.getViewTemplate();
    const bindings = this.bindings();
    return template(bindings);
  }

  /**
   * Gets the CSS classes for this block's wrapper element.
   *
   * @returns {string} Space-separated CSS class names
   * @throws {Error} If block type is not recognized
   */
  css_classes() {
    if(this.blockType === "block") {
      return "rez-block";
    } else if(this.blockType === "card") {
      if(this.flipped) {
        return "rez-card rez-flipped-card";
      } else {
        return "rez-card rez-active-card";
      }
    } else {
      throw new Error(`Attempt to get css_classes for unexpected block type: '${this.blockType}'`);
    }
  }

  /**
   * Renders this block to HTML with its wrapper div.
   *
   * If the source has `$suppress_wrapper` set, returns content without wrapper.
   *
   * @returns {string} Complete HTML for this block
   */
  html() {
    const blockContent = this.renderBlock();

    if(this.source.$suppress_wrapper) {
      return blockContent;
    } else {
      return `<div class="${this.css_classes()}">${blockContent}</div>`;
    }
  }

  /**
   * Creates a copy of this block.
   *
   * @returns {RezBlock} A new block with the same properties
   */
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

/**
 * @class RezLayout
 * @extends RezBlock
 * @abstract
 * @category Internal
 * @description Abstract base class for layout blocks.
 *
 * A layout is a special type of block that can contain other blocks as content.
 * Layouts have their own template that wraps the rendered content of their
 * child blocks.
 *
 * Subclasses must implement:
 * - `addContent(block)`: Add a content block
 * - `renderContents()`: Render all content blocks to HTML
 * - `bindAs()`: Return the binding name for this layout
 */
class RezLayout extends RezBlock {
  /**
   * Adds a content block to this layout.
   *
   * @abstract
   * @param {RezBlock} block - The block to add
   * @throws {Error} Must be implemented by subclass
   */
  addContent(_block) {
    throw new Error("Must implement addContent(block)");
  }

  /**
   * Renders all content blocks to HTML.
   *
   * @abstract
   * @returns {string} Rendered content HTML
   * @throws {Error} Must be implemented by subclass
   */
  renderContents() {
    throw new Error("Must implement renderContents()");
  }

  /**
   * Returns the binding name for this layout type.
   *
   * @abstract
   * @returns {string} The binding name
   * @throws {Error} Must be implemented by subclass
   */
  bindAs() {
    throw new Error("Must implement bindAs()");
  }

  /**
   * Renders this layout to HTML.
   *
   * Renders content first, then applies the layout's template with
   * the content and all bindings.
   *
   * @returns {string} Complete HTML for this layout
   */
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
//-----------------------------------------------------------------------------

/**
 * @class RezSingleLayout
 * @extends RezLayout
 * @category Internal
 * @description A layout that holds exactly one content block.
 *
 * Use this layout when you need to wrap a single piece of content
 * with a layout template.
 */
class RezSingleLayout extends RezLayout {
  /** @type {RezBlock|null} */
  #content;

  /**
   * @function constructor
   * @memberof RezSingleLayout
   * @description Creates a new RezSingleLayout.
   *
   * @param {string} sourceName - The block type name
   * @param {Object} source - The source element for this layout
   */
  constructor(sourceName, source) {
    super(sourceName, source);
    this.#content = null;
  }

  /**
   * Returns the binding name for this layout.
   *
   * @returns {string} The block type as binding name
   */
  bindAs() {
    return this.blockType;
  }

  /**
   * Sets the single content block for this layout.
   *
   * @param {RezBlock} block - The content block
   */
  addContent(block) {
    block.parentBlock = this;
    this.#content = block;
  }

  /**
   * Renders the content block to HTML.
   *
   * @returns {string} Rendered content HTML
   */
  renderContents() {
    return this.#content.html();
  }

  /**
   * Creates a copy of this layout including its content.
   *
   * @returns {RezSingleLayout} A new layout with copied content
   */
  copy() {
    const copy = new RezSingleLayout(this.blockType, this.source);
    copy.parentBlock = this.parentBlock;
    copy.flipped = this.flipped;
    copy.params = this.params;
    if(this.#content) {
      copy.addContent(this.#content.copy());
    }
    return copy;
  }
}

window.Rez.RezSingleLayout = RezSingleLayout;

//-----------------------------------------------------------------------------
// Stack Layout
//-----------------------------------------------------------------------------

/**
 * @class RezStackLayout
 * @extends RezLayout
 * @category Internal
 * @description A layout that holds a list of content blocks rendered in sequence.
 *
 * Content blocks are rendered in order (or reversed order if `layout_reverse`
 * is set on the source) and joined with an optional separator.
 *
 * Source element attributes:
 * - `layout_reverse`: If true, new content is added to the front
 * - `layout_separator`: HTML string inserted between content blocks
 */
class RezStackLayout extends RezLayout {
  /** @type {RezBlock[]} */
  #contents;

  /**
   * @function constructor
   * @memberof RezStackLayout
   * @description Creates a new RezStackLayout.
   *
   * @param {string} sourceName - The block type name
   * @param {Object} source - The source element for this layout
   */
  constructor(sourceName, source) {
    super(sourceName, source);
    this.#contents = [];
  }

  /**
   * Returns the binding name for this layout.
   *
   * @returns {string} The block type as binding name
   */
  bindAs() {
    return this.blockType;
  }

  /**
   * Whether content should be added in reverse order.
   *
   * @type {boolean}
   */
  get reversed() {
    return this.source.layout_reverse;
  }

  /**
   * Adds a content block to the layout.
   *
   * If reversed, adds to the front; otherwise adds to the back.
   *
   * @param {RezBlock} block - The content block to add
   */
  addContent(block) {
    block.parentBlock = this;

    if(this.reversed) {
      this.#contents.unshift(block);
    } else {
      this.#contents.push(block);
    }
  }

  /**
   * Renders all content blocks to HTML.
   *
   * Blocks are joined with the layout_separator if specified.
   *
   * @returns {string} Rendered content HTML
   */
  renderContents() {
    let separator = "";
    if(this.source.layout_separator) {
      separator = this.source.layout_separator;
    }

    return this.#contents.map((block) => block.html()).join(separator);
  }

  /**
   * Creates a copy of this layout including all content blocks.
   *
   * @returns {RezStackLayout} A new layout with copied content
   */
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
//-----------------------------------------------------------------------------

/**
 * @class RezTransformer
 * @abstract
 * @category Internal
 * @description Base class for DOM transformers.
 *
 * A transformer uses a CSS selector to find certain elements in the rendered
 * content and performs operations on them (typically adding event handlers
 * or modifying properties).
 *
 * Subclasses must implement `transformElement(elem, view)` to define the
 * transformation applied to each matching element.
 */
class RezTransformer {
  /** @type {string} */
  #selector;
  /** @type {string|null} */
  #eventName;
  /** @type {Object|null} */
  #receiver;

  /**
   * @function constructor
   * @memberof RezTransformer
   * @description Creates a new RezTransformer.
   *
   * @param {string} selector - CSS selector for elements to transform
   * @param {string|null} [eventName=null] - Event name for event-based transformers
   * @param {Object|null} [receiver=null] - Event receiver object
   */
  constructor(selector, eventName = null, receiver = null) {
    this.#selector = selector;
    this.#eventName = eventName;
    this.#receiver = receiver;
  }

  /**
   * The CSS selector used to find elements.
   * @type {string}
   */
  get selector() {
    return this.#selector;
  }

  /**
   * The event name for event-based transformers.
   * @type {string|null}
   */
  get eventName() {
    return this.#eventName;
  }

  /**
   * The receiver object for event handling.
   * @type {Object|null}
   */
  get receiver() {
    return this.#receiver;
  }

  /**
   * All DOM elements matching this transformer's selector.
   * @type {NodeList}
   */
  get elements() {
    return document.querySelectorAll(this.#selector);
  }

  /**
   * Transforms all matching elements in the document.
   *
   * @param {RezView} view - The view being transformed
   */
  transformElements(view) {
    this.elements.forEach((elem) => {
      this.transformElement(elem, view);
    });
  }

  /**
   * Transforms a single element.
   *
   * @abstract
   * @param {Element} elem - The DOM element to transform
   * @param {RezView} view - The view being transformed
   * @throws {Error} Must be implemented by subclass
   */
  transformElement(_elem, _view) {
    throw new Error("Transformers must implement transformElement(elem, view)!");
  }
}

//-----------------------------------------------------------------------------
// Event Transformers
//-----------------------------------------------------------------------------

/**
 * @class RezEventTransformer
 * @extends RezTransformer
 * @category Internal
 * @description A transformer that adds event listeners to matching elements.
 *
 * The receiver is expected to implement:
 * - `handleBrowserEvent(evt)`: Process the event and return a response object
 * - `dispatchResponse(response)`: Handle the response (e.g., scene changes)
 *
 * Response object keys:
 * - `scene`: Load a new scene by ID
 * - `card`: Play a card into the current scene
 * - `flash`: Update the flash message
 * - `render`: Trigger a view re-render
 * - `error`: Log an error message
 */
class RezEventTransformer extends RezTransformer {
  /**
   * Adds the event listener to an element.
   *
   * The listener prevents default behavior and routes the event through
   * the receiver's handleBrowserEvent and dispatchResponse methods.
   *
   * @param {Element} elem - The DOM element
   */
  addEventListener(elem) {
    if(RezBasicObject.game.$debug_events) {
      console.log(`Attach event handler for ${this.eventName} to elem ${elem}`);
    }

    const receiver = this.receiver;
    elem.addEventListener(this.eventName, (evt) => {
      evt.preventDefault();
      receiver.dispatchResponse(this.receiver.handleBrowserEvent(evt));
    });
  }

  /**
   * Transforms an element by adding an event listener.
   *
   * @param {Element} elem - The DOM element
   * @param {RezView} view - The view being transformed
   */
  transformElement(elem, _view) {
    this.addEventListener(elem);
  }
}

//-----------------------------------------------------------------------------
// Block Transformer
//-----------------------------------------------------------------------------

/**
 * @class RezBlockTransformer
 * @extends RezTransformer
 * @category Internal
 * @description Transformer that links DOM elements to their corresponding card objects.
 *
 * Operates on `<div class="card" data-card="...">` elements, adding a
 * `rez_card` property that references the actual card object.
 */
class RezBlockTransformer extends RezTransformer {
  /**
   * @function constructor
   * @memberof RezBlockTransformer
   * @description Creates a new RezBlockTransformer.
   */
  constructor() {
    super("div.rez-card div[data-card]");
  }

  /**
   * Links the element to its card object.
   *
   * @param {Element} elem - The DOM element with data-card attribute
   * @param {RezView} view - The view being transformed
   */
  transformElement(elem, _view) {
    const elem_id = elem.dataset.card;
    elem.rez_card = $(elem_id);
  }

}

window.Rez.RezBlockTransformer = RezBlockTransformer;

//-----------------------------------------------------------------------------
// Click Transformer
//-----------------------------------------------------------------------------

/**
 * @class RezClickTransformer
 * @extends RezEventTransformer
 * @category Internal
 * @description Transformer for click events on any element with a `data-event`
 * attribute in cards.
 *
 * Adds click handlers to elements within active or front-facing cards that
 * have a `data-event` attribute and are not marked as inactive. When clicked,
 * the event is routed through the receiver's event handling system.
 */
class RezClickTransformer extends RezEventTransformer {
  /**
   * @function constructor
   * @memberof RezClickTransformer
   * @description Creates a new RezClickTransformer.
   *
   * @param {Object} receiver - Object that handles click events
   */
  constructor(receiver) {
    super("div.rez-evented [data-event]:not(.inactive), div.rez-active-card [data-event]:not(.inactive)", "click", receiver);
  }
}

window.Rez.RezClickTransformer = RezClickTransformer;

//-----------------------------------------------------------------------------
// FormTransformer
//-----------------------------------------------------------------------------

/**
 * @class RezFormTransformer
 * @extends RezEventTransformer
 * @category Internal
 * @description Transformer for live forms (`<form rez-live>`) in cards.
 *
 * Adds submit handlers to forms with the `rez-live` attribute. Form
 * submissions are prevented and routed through the receiver instead.
 */
class RezFormTransformer extends RezEventTransformer {
  /**
   * @function constructor
   * @memberof RezFormTransformer
   * @description Creates a new RezFormTransformer.
   *
   * @param {Object} receiver - Object that handles form submissions
   */
  constructor(receiver) {
    super("div.rez-evented form[rez-live]", "submit", receiver);
  }
}

window.Rez.RezFormTransformer = RezFormTransformer;

//-----------------------------------------------------------------------------
// InputTransformer
//-----------------------------------------------------------------------------

/**
 * @class RezInputTransformer
 * @extends RezEventTransformer
 * @category Internal
 * @description Transformer for live input elements in cards.
 *
 * Adds input event handlers to form elements (input, select, textarea)
 * with the `rez-live` attribute for real-time value updates.
 */
class RezInputTransformer extends RezEventTransformer {
  /**
   * @function constructor
   * @memberof RezInputTransformer
   * @description Creates a new RezInputTransformer.
   *
   * @param {Object} receiver - Object that handles input events
   */
  constructor(receiver) {
    super("div.rez-evented input[rez-live], div.rez-evented select[rez-live], div.rez-evented textarea[rez-live]", "input", receiver);
  }
}

window.Rez.RezInputTransformer = RezInputTransformer;

//-----------------------------------------------------------------------------
// EnterKeyTransformer
//-----------------------------------------------------------------------------

/**
 * @class RezEnterKeyTransformer
 * @extends RezEventTransformer
 * @category Internal
 * @description Transformer that handles Enter key presses in form inputs.
 *
 * Listens for keydown events on text-like inputs within `rez-live` forms.
 * When Enter is pressed, synthesizes a form submit event and routes it
 * through the receiver.
 *
 * Supported input types: text, email, password, search, url, tel, number,
 * and inputs without a type attribute.
 */
class RezEnterKeyTransformer extends RezEventTransformer {
  /**
   * @function constructor
   * @memberof RezEnterKeyTransformer
   * @description Creates a new RezEnterKeyTransformer.
   *
   * @param {Object} receiver - Object that handles submit events
   */
  constructor(receiver) {
    super("div.rez-evented form[rez-live] input[type='text'], div.rez-evented form[rez-live] input[type='email'], div.rez-evented form[rez-live] input[type='password'], div.rez-evented form[rez-live] input[type='search'], div.rez-evented form[rez-live] input[type='url'], div.rez-evented form[rez-live] input[type='tel'], div.rez-evented form[rez-live] input[type='number'], div.rez-evented form[rez-live] input:not([type])", "keydown", receiver);
  }

  /**
   * Adds a keydown listener that synthesizes submit events on Enter.
   *
   * @param {Element} elem - The input element
   */
  addEventListener(elem) {
    elem.addEventListener(this.eventName, (evt) => {
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
          this.receiver.dispatchResponse(
            this.receiver.handleBrowserEvent(submitEvent)
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

/**
 * @class RezBindingTransformer
 * @extends RezTransformer
 * @category Internal
 * @description Transformer that creates two-way data bindings between form elements and game state.
 *
 * Operates on form elements (input, select, textarea) with the `rez-bind`
 * attribute. The attribute value specifies the binding target in the format
 * `element_id.attribute_name`.
 *
 * Special binding IDs:
 * - `game`: Binds to the $game object
 * - `scene`: Binds to the current scene
 * - `card`: Binds to the nearest card in the DOM hierarchy
 *
 * Supports input types: text, textarea, checkbox, radio, select.
 *
 * @example
 * <!-- Bind to game.player_name -->
 * <input type="text" rez-bind="game.player_name">
 *
 * <!-- Bind to current scene's difficulty -->
 * <select rez-bind="scene.difficulty">
 */
class RezBindingTransformer extends RezTransformer {
  /**
   * @function constructor
   * @memberof RezBindingTransformer
   * @description Creates a new RezBindingTransformer.
   *
   * @param {Object} receiver - Event receiver (unused, for API compatibility)
   */
  constructor(_receiver) {
    super("div.rez-evented input[rez-bind], div.rez-evented select[rez-bind], div.rez-evented textarea[rez-bind]");
  }

  /**
   * Parses a binding expression into element ID and attribute name.
   *
   * @param {string} binding_expr - Binding expression (e.g., "game.score")
   * @returns {Array<string>} Array of [element_id, attribute_name]
   * @throws {string} If binding expression is invalid
   */
  decodeBinding(binding_expr) {
    const [binding_id, binding_attr] = binding_expr.split(".");
    if(
      typeof binding_id === "undefined" ||
      typeof binding_attr === "undefined"
    ) {
      throw `Unable to parse binding: ${binding_expr}`;
    }

    return [binding_id, binding_attr];
  }

  /**
   * Resolves a binding ID to its corresponding game element.
   *
   * @param {Element} input - The form input element
   * @param {string} binding_id - The binding target ID
   * @returns {Object} The resolved game element
   * @throws {Error} If card binding used outside a card context
   */
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
    }
  }

  /**
   * Gets the current value of a bound attribute.
   *
   * @param {Element} input - The form input element
   * @param {string} boundRezElementId - The binding target ID
   * @param {string} boundAttrName - The attribute name
   * @returns {*} The attribute value
   * @throws {Error} If element not found
   */
  getBoundValue(input, boundRezElementId, boundAttrName) {
    const elem = this.getBoundElem(input, boundRezElementId);
    if(elem === undefined) {
      throw new Error(`Failed to find game element for attribute binding: ${boundRezElementId}`);
    }
    return elem.getAttribute(boundAttrName)
  }

  /**
   * Sets the value of a bound attribute.
   *
   * @param {Element} input - The form input element
   * @param {string} boundRezElementId - The binding target ID
   * @param {string} boundAttrName - The attribute name
   * @param {*} value - The new value
   * @throws {Error} If element not found
   */
  setBoundValue(input, boundRezElementId, boundAttrName, value) {
    const elem = this.getBoundElem(input, boundRezElementId);
    if(typeof(elem) === "undefined") {
      throw new Error(`Failed to find game element for attribute binding: ${boundRezElementId}`);
    }

    // Coerce string values back to the attribute's original type
    if(typeof value === "string") {
      const currentValue = elem.getAttribute(boundAttrName);
      if(typeof currentValue === "number") {
        const num = Number(value);
        if(!Number.isNaN(num)) {
          value = num;
        }
      } else if(typeof currentValue === "boolean") {
        value = value === "true";
      }
    }

    elem.setAttribute(boundAttrName, value);
  }

  /**
   * Sets up two-way binding for a text input or textarea.
   *
   * @param {RezView} view - The view for binding registration
   * @param {Element} input - The input element
   * @param {string} binding_id - The binding target ID
   * @param {string} binding_attr - The attribute name
   */
  transformTextInput(view, input, binding_id, binding_attr) {
    view.registerBinding(binding_id, binding_attr, (value) => {
      input.value = value;
    });

    input.value = this.getBoundValue(input, binding_id, binding_attr);
    input.addEventListener("input", (evt) => {
      this.setBoundValue(input, binding_id, binding_attr, evt.target.value);
    });
  }

  /**
   * Sets up two-way binding for a checkbox input.
   *
   * @param {RezView} view - The view for binding registration
   * @param {Element} input - The checkbox element
   * @param {string} binding_id - The binding target ID
   * @param {string} binding_attr - The attribute name
   */
  transformCheckboxInput(view, input, binding_id, binding_attr) {
    view.registerBinding(binding_id, binding_attr, (value) => {
      input.checked = value;
    });
    input.checked = this.getBoundValue(input, binding_id, binding_attr);
    input.addEventListener("input", (evt) => {
      this.setBoundValue(input, binding_id, binding_attr, evt.target.checked);
    });
  }

  /**
   * Sets the selected radio button in a group.
   *
   * @param {string} group_name - The radio group name
   * @param {string} value - The value to select
   */
  setRadioGroupValue(group_name, value) {
    const radios = document.getElementsByName(group_name);
    for(const radio of radios) {
      if(radio.value === String(value)) {
        radio.checked = true;
      }
    }
  }

  /**
   * Adds change tracking to all radios in a group.
   *
   * @param {string} group_name - The radio group name
   * @param {Function} callback - Callback for input events
   */
  trackRadioGroupChange(group_name, callback) {
    const radios = document.getElementsByName(group_name);
    for(const radio of radios) {
      radio.addEventListener("input", callback);
    }
  }

  /**
   * Sets up two-way binding for a radio button group.
   *
   * Only the first radio in a group needs to register the binding.
   *
   * @param {RezView} view - The view for binding registration
   * @param {Element} input - A radio button in the group
   * @param {string} binding_id - The binding target ID
   * @param {string} binding_attr - The attribute name
   */
  transformRadioInput(view, input, binding_id, binding_attr) {
    if(!view.hasBinding(binding_id, binding_attr)) {
      // We only need to bind the first radio in the group
      view.registerBinding(binding_id, binding_attr, (value) => {
        this.setRadioGroupValue(input.name, value);
      });
    }

    this.setRadioGroupValue(input.name, this.getBoundValue(input, binding_id, binding_attr));

    this.trackRadioGroupChange(input.name, (evt) => {
      this.setBoundValue(input, binding_id, binding_attr, evt.target.value);
    });
  }

  /**
   * Sets up two-way binding for a select element.
   *
   * @param {RezView} view - The view for binding registration
   * @param {Element} select - The select element
   * @param {string} binding_id - The binding target ID
   * @param {string} binding_attr - The attribute name
   */
  transformNumberInput(view, input, binding_id, binding_attr) {
    view.registerBinding(binding_id, binding_attr, (value) => {
      input.value = value;
    });
    input.value = this.getBoundValue(input, binding_id, binding_attr);
    input.addEventListener("input", (evt) => {
      const raw = evt.target.value;
      const value = raw.includes(".") ? parseFloat(raw) : parseInt(raw, 10);
      this.setBoundValue(input, binding_id, binding_attr, isNaN(value) ? raw : value);
    });
  }

  transformSelect(view, select, binding_id, binding_attr) {
    view.registerBinding(binding_id, binding_attr, (value) => {
      select.value = value;
    });
    select.value = this.getBoundValue(select, binding_id, binding_attr);
    select.addEventListener("input", (evt) => {
      this.setBoundValue(select, binding_id, binding_attr, evt.target.value);
    });
  }

  /**
   * Transforms a form element by setting up two-way data binding.
   *
   * Delegates to type-specific methods based on input type.
   *
   * @param {Element} input - The form element to transform
   * @param {RezView} view - The view for binding registration
   * @throws {Error} If input type is not supported
   */
  transformElement(input, view) {
    const [binding_id, binding_attr] = this.decodeBinding(
      input.getAttribute("rez-bind")
    );

    if(input.type === "text" || input.tagName.toLowerCase() === "textarea") {
      this.transformTextInput(view, input, binding_id, binding_attr);
    } else if(input.type === "number") {
      this.transformNumberInput(view, input, binding_id, binding_attr);
    } else if(input.type === "checkbox") {
      this.transformCheckboxInput(view, input, binding_id, binding_attr);
    } else if(input.type === "radio") {
      this.transformRadioInput(view, input, binding_id, binding_attr);
    } else if(
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

/**
 * @class RezView
 * @category Internal
 * @description The main view controller that manages rendering and DOM transformations.
 *
 * RezView is responsible for:
 * - Managing the layout hierarchy and content blocks
 * - Rendering HTML into the container element
 * - Applying transformers to set up event handlers and bindings
 * - Tracking two-way data bindings between form elements and game state
 *
 * The view uses a layout stack to support nested layouts during complex
 * rendering scenarios. Bindings are cleared and re-established on each
 * render cycle.
 *
 * @example
 * // Create a view with a stack layout
 * const layout = new RezStackLayout("scene", sceneElement);
 * const view = new RezView("game-container", eventReceiver, layout);
 *
 * // Add content and render
 * view.addLayoutContent(new RezBlock("card", cardElement));
 * view.update();
 */
class RezView {
  /** @type {Element} */
  #container;
  /** @type {RezLayout} */
  #layout;
  /** @type {RezLayout[]} */
  #layoutStack;
  /** @type {Map<string, Function>} */
  #bindings;
  /** @type {Object} */
  #receiver;
  /** @type {RezTransformer[]} */
  #transformers;

  /**
   * @function constructor
   * @memberof RezView
   * @description Creates a new RezView.
   * @param {string} container_id - ID of the DOM container element
   * @param {Object} receiver - Event receiver for handling user interactions
   * @param {RezLayout} layout - The root layout for the view
   * @param {RezTransformer[]} [transformers] - Custom transformers (uses defaults if not provided)
   * @throws {Error} If container element not found
   */
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

  /**
   * The DOM container element for this view.
   * @type {Element}
   */
  get container() {
    return this.#container;
  }

  /**
   * The current root layout.
   * @type {RezLayout}
   */
  get layout() {
    return this.#layout;
  }

  set layout(layout) {
    this.#layout = layout;
  }

  /**
   * The stack of pushed layouts.
   * @type {RezLayout[]}
   */
  get layoutStack() {
    return this.#layoutStack;
  }

  /**
   * Pushes a new layout onto the stack, making it the current layout.
   *
   * Use this when entering a nested layout context. Pop when exiting.
   *
   * @param {RezLayout} layout - The layout to push
   */
  pushLayout(layout) {
    this.layoutStack.push(this.layout);
    this.layout = layout;
  }

  /**
   * Pops the current layout and restores the previous one.
   */
  popLayout() {
    this.layout = this.layoutStack.pop();
  }

  /**
   * Adds content to the current layout.
   *
   * @param {RezBlock} content - The content block to add
   */
  addLayoutContent(content) {
    this.layout.addContent(content);
  }

  /**
   * Map of registered bindings (keyed by "id.attr").
   * @type {Map<string, Function>}
   */
  get bindings() {
    return this.#bindings;
  }

  /**
   * The event receiver for this view.
   * @type {Object}
   */
  get receiver() {
    return this.#receiver;
  }

  /**
   * The transformers applied after each render.
   * @type {RezTransformer[]}
   */
  get transformers() {
    return this.#transformers;
  }

  /**
   * Renders the layout HTML into the container.
   *
   * Note: Event listeners added by transformers are automatically cleaned up
   * when innerHTML is replaced - no explicit cleanup needed. The DOM elements
   * holding the listeners are destroyed, allowing garbage collection.
   */
  render() {
    const html = this.layout.html();
    this.container.innerHTML = html;
  }

  /**
   * Creates the default set of transformers.
   *
   * Default transformers handle:
   * - Click events (`[data-event]`)
   * - Card block references
   * - Form submissions
   * - Data bindings (`rez-bind`)
   * - Live inputs (`rez-live`)
   * - Enter key handling
   *
   * @returns {RezTransformer[]} Array of default transformers
   */
  defaultTransformers() {
    return [
      new RezClickTransformer(this.receiver),
      new RezBlockTransformer(),
      new RezFormTransformer(this.receiver),
      new RezBindingTransformer(this.receiver),
      new RezInputTransformer(this.receiver),
      new RezEnterKeyTransformer(this.receiver)
    ];
  }

  /**
   * Applies all transformers to the rendered DOM.
   */
  transform() {
    this.transformers.forEach((transformer) => {
      transformer.transformElements(this);
    });
  }

  /**
   * Checks if a binding is registered for a given element and attribute.
   *
   * @param {string} binding_id - The element ID
   * @param {string} binding_attr - The attribute name
   * @returns {boolean} True if binding exists
   */
  hasBinding(binding_id, binding_attr) {
    return this.bindings.has(`${binding_id}.${binding_attr}`);
  }

  /**
   * Registers a callback for updating a bound control when data changes.
   *
   * @param {string} binding_id - The element ID
   * @param {string} binding_attr - The attribute name
   * @param {Function} callback - Function called with new value when data changes
   */
  registerBinding(binding_id, binding_attr, callback) {
    this.bindings.set(`${binding_id}.${binding_attr}`, callback);
  }

  /**
   * Updates bound form controls when the underlying data changes.
   *
   * Called by game elements when their attributes change to keep
   * the UI in sync.
   *
   * @param {string} binding_id - The element ID
   * @param {string} binding_attr - The attribute name
   * @param {*} value - The new value
   */
  updateBoundControls(binding_id, binding_attr, value) {
    const callback = this.bindings.get(`${binding_id}.${binding_attr}`);
    if(typeof callback === "function") {
      callback(value);
    }
  }

  /**
   * Clears all registered bindings.
   *
   * Called at the start of each render cycle since bindings are
   * re-established by transformers.
   */
  clearBindings() {
    this.bindings.clear();
  }

  /**
   * Performs a complete view update: clear bindings, render, and transform.
   *
   * This is the main method to call when the view needs to refresh.
   */
  update() {
    this.clearBindings();
    this.render();
    this.transform();
  }

  /**
   * Creates a copy of this view with copied layouts.
   *
   * Bindings are not copied as they are cleared on each render.
   *
   * @returns {RezView} A new view with copied state
   */
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
