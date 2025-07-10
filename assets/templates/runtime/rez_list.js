//-----------------------------------------------------------------------------
// List
//-----------------------------------------------------------------------------

class RezList extends RezBasicObject {
  constructor(id, attributes) {
    super("list", id, attributes);
  }

  // No need to define values accessor as it's defined by default for @list

  get length() {
    return this.values.length;
  }

  // Indexed access

  at(idx) {
    return this.values.at(idx);
  }

  lookup(value) {
    return this.values.indexOf(value);
  }

  /*
   *  Returns a random element of the list with replacement.
   */
  randomElement() {
    return this.values.randomElement();
  }

  //---------------------------------------------------------------------------
  // Random without starvation (as per jkj yuio from intfiction.org)
  //---------------------------------------------------------------------------

  warmStarvationPool(poolId = "$default") {
    const warming_count = 2*this.list_length;
    for(let i = 0; i<warming_count; i++ ) {
      this.randomWithoutStarvation(poolId);
    }
  }

  randomWithoutStarvation(poolId = "$default") {
    let stats = this.getAttributeValue(`$pool_${poolId}`, Array.nOf(this.list_length, 0));
    const len = stats.length;
    const max = Math.floor(len + (len+2)/3);
    let choice = stats.findIndex((element) => element+1 >= max);
    if(choice == -1) {
      choice = stats.randomIndex();
    }

    stats = stats.map((element) => element+1);
    stats[choice] = 0;

    this.setAttribute(`$pool_${poolId}`, stats);
    return this.values[choice];
  }

  //---------------------------------------------------------------------------
  // Cycle
  //---------------------------------------------------------------------------

  /*
   * Treat the list as a repeating cycle. Each cycle identified by an id
   * is separate.
   */
  nextForCycle(cycleId) {
    const cycleIdx = this.getAttributeValue(`cycle_${cycleId}`, 0);
    const values = this.getAttribute("values");
    const value = values.at(cycle_idx);
    cycleIdx = (cycleIdx + 1) % values.length;
    this.setAttribute(`cycle_${cycleId}`, cycleIdx);
    return value;
  }

  //---------------------------------------------------------------------------
  // Bag
  //---------------------------------------------------------------------------

  randomFromBag(bagId = "$default") {
    const item = this.randomRemaining(bagId);
    this.takeFrom(bagId, item);
    return item;
  }

  // Low-level interface, you should not need to call these directly

  /*
   * Returns a random element from among those left in the bag. If the bag
   * is empty, returns undefined.
   */
  randomRemaining(bagId) {
    let bag = this.getBag(bagId);
    if(bag.length === 0) {
      return undefined;
    } else {
      return bag.randomElement();
    }
  }

  /*
   * Removes the specified value from those in the bag
   */
  takeFrom(bagId, value) {
    let bag = this.getBag(bagId);
    bag = bag.filter((elem) => elem != value);
    this.setBag(bagId, bag);
  }

  getBag(bagId) {
    const attrName = `bag_${bagId}`;
    if(!this.hasAttribute(attrName)) {
      this.createBag(bagId);
    }
    return this.getAttributeValue(attrName);
  }

  setBag(bagId, bag) {
    const attrName = `bag_${bagId}`;
    this.setAttribute(attrName, bag);
  }

  createBag(bagId) {
    const values = this.getAttribute("values");
    const bag = Array.from(values);
    this.setBag(bagId, bag);
    return bag;
  }

  //---------------------------------------------------------------------------
  // Walk
  //---------------------------------------------------------------------------

  /*
   * Returns a random element of the list without replacement, i.e. no item
   * will be returned twice in any given walk. At the end of a walk (i.e. all items
   * have been returned), a new walk is automatically begun.
   */
  randomWalk(walkId) {
    let walk = this.getWalk(walkId);
    if (walk.length == 0) {
      walk = this.resetWalk(walkId);
    } else {
      const idx = walk.shift();
      const values = this.getAttribute("values");
      return values.at(idx);
    }
  }

  getWalk(walkId) {
    let walk = this.getAttributeValue(`walk_${walkId}`);
    if(typeof(walk) === "undefined") {
      return this.resetWalk();
    } else {
      return walk;
    }
  }

  resetWalk(walkId) {
    const values = this.getAttribute("values");
    const walk = Array.from(values.keys()).fy_shuffle();
    this.setAttribute(`walk_${walkId}`, walk);
    return walk;
  }
}

window.Rez.RezList = RezList;
