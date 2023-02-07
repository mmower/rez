//-----------------------------------------------------------------------------
// List
//-----------------------------------------------------------------------------

let list_proto = {
  __proto__: basic_object,

  //---------------------------------------------------------------------------
  // List
  //---------------------------------------------------------------------------

  /*
   *  Returns a random element of the list with replacement.
  */
  randomElement() {
    return this.values().randomElement();
  },

  //---------------------------------------------------------------------------
  // Cycle
  //---------------------------------------------------------------------------

  /*
   * Treat the list as a repeating cycle. Each cycle identified by an id
   * is separate.
  */
  nextForCycle(cycle_id) {
    let cycle = this.cycles[cycle_id];
    if(typeof(cycle) == "undefined") {
      cycle = 0;
    }

    const value = this.values().at(cycle);

    cycle += 1;
    this.cycles[cycle_id] = cycle;

    return value;
  },

  //---------------------------------------------------------------------------
  // Bag
  //---------------------------------------------------------------------------

  /*
   * Returns a random element from among those left in the bag. If the bag
   * is empty, returns nil.
  */
  randomRemaining(bag_id) {
    let bag = this.getBag(bag_id);
    if(bag.length == 0) {
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
    const bag = Array.from(this.values());
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
    if(walk.length == 0) {
      walk = this.resetWalk(walk_id);
    } else {
      const idx = walk.shift();
      return this.values().at(idx);
    }
  },

  getWalk(walk_id) {
    let walk = this.walks[walk_id];
    if(typeof(walk) == "undefined") {
      walk = this.resetWalk(walk_id);
    }
    return walk;
  },

  resetWalk(walk_id) {
    const walk = Array.from(this.values().keys()).fy_shuffle();
    this.walks[walk_id] = walk;
    return walk;
  },

  values() {
    return this.attributes["values"];
  }
};

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

RezList.prototype = list_proto;
RezList.prototype.constructor = RezList;
window.Rez.List = RezList;
