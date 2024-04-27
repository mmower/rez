//-----------------------------------------------------------------------------
// List
//-----------------------------------------------------------------------------

function RezList(id, attributes) {
  this.id = id;
  this.game_object_type = "list";
  this.attributes = attributes;
  this.cycles = {};
  this.walks = {};
  this.bags = {};
  this.properties_to_archive = ["cycles", "walks"];
  this.changed_attributes = [];
}

RezList.prototype = {
  __proto__: basic_object,
  constructor: RezList,

  get length() {
    return this.getAttribute("values").lengh;
  },

  //---------------------------------------------------------------------------
  // List
  //---------------------------------------------------------------------------

  /*
   * Indexed access
   */

  at: function (idx) {
    const values = this.getAttribute("values");
    return values.at(idx);
  },

  lookup: function (value) {
    const values = this.getAttribute("values");
    return values.indexOf(value);
  },

  /*
   *  Returns a random element of the list with replacement.
   */
  randomElement() {
    const values = this.getAttribute("values");
    return values.randomElement();
  },

  //---------------------------------------------------------------------------
  // Random without starvation (as per jkj yuio from intfiction.org)
  //---------------------------------------------------------------------------

  warmStarvationPool(pool_id = "$default") {
    const warming_count = 2*this.values.length;
    for(let i = 0; i<warming_count; i++ ) {
      this.randomWithoutStarvation(pool_id);
    }
  },

  randomWithoutStarvation(pool_id = "$default") {
    let stats = this.getAttributeValue(`$pool_${pool_id}`, Array.n_of(this.values.length, 0));
    const len = stats.length;
    const max = Math.floor(len + (len+2)/3);
    let choice = stats.findIndex((element) => element+1 >= max);
    if(choice == -1) {
      choice = stats.randomIndex();
    }

    stats = stats.map((element) => element+1);
    stats[choice] = 0;

    this.setAttribute(`$pool_${pool_id}`, stats);
    return this.values[choice];
  },

  //---------------------------------------------------------------------------
  // Cycle
  //---------------------------------------------------------------------------

  /*
   * Treat the list as a repeating cycle. Each cycle identified by an id
   * is separate.
   */
  nextForCycle(cycle_id) {
    const cycles = this.getAttribute("$cycles");
    const cycle_idx = cycles[cycle_id] ?? 0;
    const values = this.getAttribute("values");
    const value = values.at(cycle_idx);
    cycles[cycle_id] = (cycle+1) % values.length;
    this.setAttribute("$cycles", cycles);
    return value;
  },

  //---------------------------------------------------------------------------
  // Bag
  //---------------------------------------------------------------------------

  randomFromBag(bag_id = "default_bag") {
    const item = this.randomRemaining(bag_id);
    this.take_from(bag_id, item);
    return item;
  },

  // Low-level interface, you should need to call these directly

  /*
   * Returns a random element from among those left in the bag. If the bag
   * is empty, returns nil.
   */
  randomRemaining(bag_id) {
    let bag = this.getBag(bag_id);
    if (bag.length == 0) {
      return null;
    } else {
      return bag.randomElement();
    }
  },

  /*
   * Removes the specified value from those in the bag
   */
  take_from(bag_id, value) {
    let bag = this.getBag(bag_id);
    bag = bag.filter((elem) => elem != value);
    this.setBag(bag_id, bag);
  },

  getBag(bag_id) {
    return this.bags[bag_id] ?? this.create_bag(bag_id);
  },

  setBag(bag_id, bag) {
    this.bags[bag_id] = bag;
  },

  create_bag(bag_id) {
    const values = this.getAttribute("values");
    const bag = Array.from(values);
    this.bags[bag_id] = bag;
    return bag;
  },

  //---------------------------------------------------------------------------
  // Walk
  //---------------------------------------------------------------------------

  /*
   * Returns a random element of the list without replacement, i.e. no item
   * will be returned twice in any given walk. At the end of a walk (i.e. all items
   * have been returned), a new walk is automatically begun.
   */
  randomWalk(walk_id) {
    let walk = this.getWalk(walk_id);
    if (walk.length == 0) {
      walk = this.resetWalk(walk_id);
    } else {
      const idx = walk.shift();
      const values = this.getAttribute("values");
      return values.at(idx);
    }
  },

  getWalk(walk_id) {
    let walk = this.walks[walk_id];
    if (typeof walk == "undefined") {
      walk = this.resetWalk(walk_id);
    }
    return walk;
  },

  resetWalk(walk_id) {
    const values = this.getAttribute("values");
    const walk = Array.from(values.keys()).fy_shuffle();
    this.walks[walk_id] = walk;
    return walk;
  },


};
