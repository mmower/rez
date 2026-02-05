//-----------------------------------------------------------------------------
// List
//-----------------------------------------------------------------------------

/**
 * @class RezList
 * @extends RezBasicObject
 * @category Elements
 * @description Represents a list of values with multiple selection strategies. Lists provide
 * various ways to retrieve values - from simple indexed access to sophisticated random
 * selection algorithms that prevent repetition or starvation.
 *
 * ## Basic Access
 * - `values` - The underlying array of values
 * - `length` - Number of values in the list
 * - `at(idx)` - Get value at index (supports negative indices)
 * - `lookup(value)` - Find index of a value
 *
 * ## Selection Strategies
 * RezList provides multiple strategies for selecting values:
 *
 * ### Random with Replacement
 * - `randomElement()` - Simple random selection, same value can appear consecutively
 *
 * ### Random without Starvation
 * - `randomWithoutStarvation(poolId)` - Ensures all values appear with roughly equal frequency
 * - `warmStarvationPool(poolId)` - Pre-populates the pool to avoid initial bias
 *
 * ### Cycle
 * - `nextForCycle(cycleId)` - Returns values in sequence, wrapping at the end
 *
 * ### Bag (Random without Replacement)
 * - `randomFromBag(bagId)` - Removes and returns a random value; bag empties over time
 * - Useful when you want each value exactly once before any repeats
 *
 * ### Walk (Random without Replacement, Auto-Reset)
 * - `randomWalk(walkId)` - Like bag, but automatically refills when empty
 * - Guarantees all values appear once before any can repeat
 *
 * ## Multiple Named Instances
 * Cycle, bag, walk, and starvation pool methods accept an optional ID parameter,
 * allowing multiple independent instances of the same strategy on one list.
 *
 * ## List Includes
 * Lists can include values from other lists via the `includes` attribute.
 * Included values are prepended to the list's own values during initialization.
 */
class RezList extends RezBasicObject {
  /**
   * @function constructor
   * @memberof RezList#
   * @param {string} id - unique identifier for this list
   * @param {object} attributes - list attributes from Rez compilation
   * @description Creates a new list instance
   */
  constructor(id, attributes) {
    super("list", id, attributes);
  }

  /**
   * @function elementInitializer
   * @memberof RezList#
   * @description Called during initialization to merge values from included lists.
   * If the list has an `includes` attribute, collects values from all referenced
   * lists and prepends them to this list's own values.
   * @throws {Error} if an included list does not exist
   */
  elementInitializer() {
    const includes = this.getAttributeValue("includes", []);
    if (includes.length > 0) {
      // Get own values (may be empty array if only using includes)
      const ownValues = this.getAttributeValue("values", []);

      // Collect values from all included lists
      const includedValues = includes.flatMap(listId => {
        const list = $(listId);
        if (!list) {
          throw new Error(`List '${this.id}' includes non-existent list: '${listId}'`);
        }
        return list.values;
      });

      // Merge: included values first, then own values
      const mergedValues = [...includedValues, ...ownValues];
      this.setAttribute("values", mergedValues, false);
    }
  }

  /**
   * @function length
   * @memberof RezList#
   * @returns {number} the number of values in the list
   * @description Returns the count of values in this list
   */
  get length() {
    return this.values.length;
  }

  /**
   * @function at
   * @memberof RezList#
   * @param {number} idx - the index to retrieve (supports negative indices)
   * @returns {*} the value at the specified index
   * @description Gets the value at the specified index. Supports negative indices
   * where -1 is the last element, -2 is second-to-last, etc.
   */
  at(idx) {
    return this.values.at(idx);
  }

  /**
   * @function lookup
   * @memberof RezList#
   * @param {*} value - the value to find
   * @returns {number} the index of the value, or -1 if not found
   * @description Finds the index of the specified value in the list
   */
  lookup(value) {
    return this.values.indexOf(value);
  }

  /**
   * @function randomElement
   * @memberof RezList#
   * @returns {*} a randomly selected value from the list
   * @description Returns a random element of the list with replacement.
   * The same value can be returned on consecutive calls.
   */
  randomElement() {
    return this.values.randomElement();
  }

  //---------------------------------------------------------------------------
  // Random without starvation (as per jkj yuio from intfiction.org)
  //---------------------------------------------------------------------------

  /**
   * @function warmStarvationPool
   * @memberof RezList#
   * @param {string} [poolId="$default"] - identifier for the starvation pool
   * @description Pre-populates the starvation pool by running 2*length iterations.
   * This avoids initial bias where early selections might favor certain indices.
   * Call this once before using randomWithoutStarvation if you want more uniform
   * distribution from the start.
   */
  warmStarvationPool(poolId = "$default") {
    const warming_count = 2*this.length;
    for(let i = 0; i<warming_count; i++ ) {
      this.randomWithoutStarvation(poolId);
    }
  }

  /**
   * @function randomWithoutStarvation
   * @memberof RezList#
   * @param {string} [poolId="$default"] - identifier for the starvation pool
   * @returns {*} a randomly selected value that hasn't been "starving"
   * @description Returns a random element while ensuring no element goes too long
   * without being selected. Each element tracks how many selections have passed
   * since it was last chosen. When an element exceeds the starvation threshold
   * (approximately length + length/3), it becomes a priority candidate.
   * Algorithm credit: jkj yuio from intfiction.org
   */
  randomWithoutStarvation(poolId = "$default") {
    let stats = this.getAttributeValue(`$pool_${poolId}`, Array.nOf(this.length, 0));
    const len = stats.length;
    const max = Math.floor(len + (len+2)/3);

    // Increment all counters first
    stats = stats.map((element) => element+1);

    // Find elements that are now starving
    let starvingIndices = stats
      .map((el, idx) => el >= max ? idx : -1)
      .filter(idx => idx !== -1);

    // Choose: starving element if any exist, otherwise random
    let choice = starvingIndices.length > 0
      ? starvingIndices.randomElement()
      : stats.randomIndex();

    // Reset chosen element
    stats[choice] = 0;

    this.setAttribute(`$pool_${poolId}`, stats);
    return this.values[choice];
  }

  //---------------------------------------------------------------------------
  // Cycle
  //---------------------------------------------------------------------------

  /**
   * @function nextForCycle
   * @memberof RezList#
   * @param {string} [cycleId="$default"] - identifier for this cycle
   * @returns {*} the next value in the cycle
   * @description Treats the list as a repeating cycle, returning values in order
   * and wrapping back to the start after reaching the end. Each named cycle
   * maintains its own position, allowing multiple independent cycles on the
   * same list.
   */
  nextForCycle(cycleId = "$default") {
    let cycleIdx = this.getAttributeValue(`cycle_${cycleId}`, 0);
    const values = this.getAttribute("values");
    const value = values.at(cycleIdx);
    cycleIdx = (cycleIdx + 1) % values.length;
    this.setAttribute(`cycle_${cycleId}`, cycleIdx);
    return value;
  }

  //---------------------------------------------------------------------------
  // Bag
  //---------------------------------------------------------------------------

  /**
   * @function randomFromBag
   * @memberof RezList#
   * @param {string} [bagId="$default"] - identifier for this bag
   * @returns {*} a randomly selected value, removed from the bag
   * @description Removes and returns a random value from the bag. The bag starts
   * as a copy of the list's values and empties over time. Returns undefined when
   * the bag is empty. Use this when you want each value exactly once.
   */
  randomFromBag(bagId = "$default") {
    const item = this.randomRemaining(bagId);
    this.takeFrom(bagId, item);
    return item;
  }

  /**
   * @function randomRemaining
   * @memberof RezList#
   * @param {string} bagId - identifier for the bag
   * @returns {*} a random value from the bag without removing it, or undefined if empty
   * @description Low-level method that returns a random element from the bag without
   * removing it. Prefer using randomFromBag() for typical use cases.
   */
  randomRemaining(bagId) {
    let bag = this.getBag(bagId);
    if(bag.length === 0) {
      return undefined;
    } else {
      return bag.randomElement();
    }
  }

  /**
   * @function takeFrom
   * @memberof RezList#
   * @param {string} bagId - identifier for the bag
   * @param {*} value - the value to remove from the bag
   * @description Low-level method that removes the specified value from the bag.
   * Prefer using randomFromBag() for typical use cases.
   */
  takeFrom(bagId, value) {
    let bag = this.getBag(bagId);
    bag = bag.filter((elem) => elem != value);
    this.setBag(bagId, bag);
  }

  /**
   * @function getBag
   * @memberof RezList#
   * @param {string} bagId - identifier for the bag
   * @returns {Array} the current contents of the bag
   * @description Gets the bag's current contents, creating it if it doesn't exist.
   */
  getBag(bagId) {
    const attrName = `bag_${bagId}`;
    if(!this.hasAttribute(attrName)) {
      this.createBag(bagId);
    }
    return this.getAttributeValue(attrName);
  }

  /**
   * @function setBag
   * @memberof RezList#
   * @param {string} bagId - identifier for the bag
   * @param {Array} bag - the new bag contents
   * @description Sets the bag's contents directly.
   */
  setBag(bagId, bag) {
    const attrName = `bag_${bagId}`;
    this.setAttribute(attrName, bag);
  }

  /**
   * @function createBag
   * @memberof RezList#
   * @param {string} bagId - identifier for the bag
   * @returns {Array} the newly created bag
   * @description Creates a new bag as a copy of the list's values.
   */
  createBag(bagId) {
    const values = this.getAttribute("values");
    const bag = Array.from(values);
    this.setBag(bagId, bag);
    return bag;
  }

  //---------------------------------------------------------------------------
  // Walk
  //---------------------------------------------------------------------------

  /**
   * @function randomWalk
   * @memberof RezList#
   * @param {string} walkId - identifier for this walk
   * @returns {*} the next random value in the walk
   * @description Returns a random element without replacement. No item will be
   * returned twice in any given walk. When all items have been returned, a new
   * walk automatically begins with a fresh shuffle. Unlike bag, walk never returns
   * undefined - it automatically resets when exhausted.
   */
  randomWalk(walkId) {
    let walk = this.getWalk(walkId);
    if(walk.length == 0) {
      walk = this.resetWalk(walkId);
    }

    const idx = walk.shift();
    const values = this.getAttribute("values");
    return values.at(idx);
  }

  /**
   * @function getWalk
   * @memberof RezList#
   * @param {string} walkId - identifier for the walk
   * @returns {Array} array of remaining indices to visit
   * @description Gets the current walk state, creating it if it doesn't exist.
   */
  getWalk(walkId) {
    let walk = this.getAttributeValue(`walk_${walkId}`);
    if(typeof(walk) === "undefined") {
      return this.resetWalk(walkId);
    } else {
      return walk;
    }
  }

  /**
   * @function resetWalk
   * @memberof RezList#
   * @param {string} walkId - identifier for the walk
   * @returns {Array} the newly shuffled array of indices
   * @description Resets the walk to a fresh shuffled order of all indices.
   * Uses Fisher-Yates shuffle for unbiased randomization.
   */
  resetWalk(walkId) {
    const values = this.getAttribute("values");
    const walk = Array.from(values.keys()).fyShuffle();
    this.setAttribute(`walk_${walkId}`, walk);
    return walk;
  }
}

window.Rez.RezList = RezList;
