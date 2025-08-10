//-----------------------------------------------------------------------------
// Decision
//-----------------------------------------------------------------------------

/**
 * @class RezDecision
 * @description Represents a decision that can be made by user-written filters in the Rez game engine.
 * This is a simplified abstraction of RezDynamicLink that allows code to make yes/no decisions
 * with optional reasons and data. Decisions can be made explicitly or use default values.
 * 
 * @example
 * // Create a decision and make a choice
 * const decision = new RezDecision("Filter Item");
 * if(item.isAllowed) {
 *   decision.yes();
 * } else {
 *   decision.no("Item not permitted");
 * }
 */
class RezDecision {
  #purpose;
  #made;
  #result;
  #hidden;
  #reason;
  #data;
  #used_default;

  /**
   * @function constructor
   * @memberof RezDecision
   * @param {string} purpose - description of what this decision is for
   * @param {object} data - optional data object to associate with this decision
   * @description Creates a new decision with the specified purpose and optional data
   */
  constructor(purpose, data = {}) {
    this.#purpose = purpose;
    this.#made = false;
    this.#result = false;
    this.#hidden = false;
    this.#reason = "";
    this.#data = data;
    this.#used_default = false;
  }

  /**
   * @function purpose
   * @memberof RezDecision
   * @returns {string} the purpose or description of this decision
   * @description Returns the purpose string that describes what this decision is about
   */
  get purpose() {
    return this.#purpose;
  }

  /**
   * @function wasMade
   * @memberof RezDecision
   * @returns {boolean} true if a decision has been made
   * @description Indicates whether any decision method (yes, no, hide, or default variants) has been called
   */
  get wasMade() {
    return this.#made;
  }

  /**
   * @function result
   * @memberof RezDecision
   * @returns {boolean} the boolean result of the decision
   * @description Returns true for yes decisions, false for no decisions
   */
  get result() {
    return this.#result;
  }

  /**
   * @function wasYes
   * @memberof RezDecision
   * @returns {boolean} true if the decision was yes
   * @description Convenience method that returns true if the decision result was positive
   */
  get wasYes() {
    return this.#result;
  }

  /**
   * @function wasNo
   * @memberof RezDecision
   * @returns {boolean} true if the decision was no
   * @description Convenience method that returns true if the decision result was negative
   */
  get wasNo() {
    return !this.wasYes;
  }

  /**
   * @function isHidden
   * @memberof RezDecision
   * @returns {boolean} true if this decision should be hidden from the user
   * @description Indicates whether this decision was made with the hide() method
   */
  get isHidden() {
    return this.#hidden;
  }

  /**
   * @function reason
   * @memberof RezDecision
   * @returns {string} the reason provided for negative decisions
   * @description Returns the reason string provided when making a no decision
   */
  get reason() {
    return this.#reason;
  }

  /**
   * @function data
   * @memberof RezDecision
   * @returns {object} the data object associated with this decision
   * @description Returns the data object that was passed to the constructor or added via setData
   */
  get data() {
    return this.#data;
  }

  /**
   * @function usedDefault
   * @memberof RezDecision
   * @returns {boolean} true if a default decision method was used
   * @description Indicates whether this decision was made using defaultYes() or defaultNo()
   */
  get usedDefault() {
    return this.#used_default;
  }

  /**
   * @function yes
   * @memberof RezDecision
   * @returns {RezDecision} this decision instance for method chaining
   * @description Makes a positive decision explicitly
   */
  yes() {
    this.#made = true;
    this.#result = true;
    this.#used_default = false;
    return this;
  }

  /**
   * @function defaultYes
   * @memberof RezDecision
   * @returns {RezDecision} this decision instance for method chaining
   * @description Makes a positive decision using the default value (indicates no explicit choice was made)
   */
  defaultYes() {
    this.#made = true;
    this.#result = true;
    this.#used_default = true;
    return this;
  }

  /**
   * @function no
   * @memberof RezDecision
   * @param {string} reason - optional reason for the negative decision
   * @returns {RezDecision} this decision instance for method chaining
   * @description Makes a negative decision explicitly with an optional reason
   */
  no(reason = "none given") {
    this.#made = true;
    this.#result = false;
    this.#reason = reason;
    this.#used_default = false;
    return this;
  }

  /**
   * @function hide
   * @memberof RezDecision
   * @description Makes a negative decision that should be hidden from the user.
   * Sets the decision as made, result to false, reason to "hidden", and marks it as hidden.
   */
  hide() {
    this.#made = true;
    this.#result = false;
    this.#reason = "hidden";
    this.#hidden = true;
    this.#used_default = false;
  }

  /**
   * @function defaultNo
   * @memberof RezDecision
   * @param {string} reason - optional reason for the negative decision
   * @returns {RezDecision} this decision instance for method chaining
   * @description Makes a negative decision using the default value with an optional reason
   */
  defaultNo(reason = "none given") {
    this.#made = true;
    this.#result = false;
    this.#reason = reason;
    this.#used_default = true;
    return this;
  }

  /**
   * @function setData
   * @memberof RezDecision
   * @param {string} key - the data key to set
   * @param {*} value - the value to associate with the key
   * @returns {RezDecision} this decision instance for method chaining
   * @description Sets a key-value pair in the decision's data object
   */
  setData(key, value) {
    this.#data[key] = value;
    return this;
  }

  /**
   * @function explain
   * @memberof RezDecision
   * @returns {string} a human-readable explanation of the decision
   * @description Returns a descriptive string explaining the decision result, reason, and visibility
   */
  explain() {
    if (this.result) {
      return `Result was yes`;
    } else {
      if (this.hidden) {
        return `Result was no (${this.reason}) and hide the decision`;
      } else {
        return `Result was no (${this.reason})`;
      }
    }
  }
}
