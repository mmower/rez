//-----------------------------------------------------------------------------
// Inventory
//-----------------------------------------------------------------------------

/**
 * @class RezInventory
 * @extends RezBasicObject
 * @category Elements
 * @description Holds items in named positions.
 *
 * An inventory is made up of *positions*, each declared by a nested `@contains`
 * block. The block's id is the position's name and its `slot_id` names the
 * `@slot` that decides what the position accepts. Several positions, in the same
 * inventory or in different ones, can use the same `@slot`.
 *
 * Key features:
 * - **Typed positions**: a position only accepts items whose `type` is (or derives
 *   from) what its slot `accepts`
 * - **Capacity**: a slot with `has_capacity: true` limits the total `size` of the
 *   items in each position that uses it
 * - **Weight**: an inventory can have a `max_weight`, checked against the total
 *   `weight` of everything it holds
 * - **Exclusion**: a slot can `exclude` other slots, so filling one position
 *   blocks another
 * - **Enabled state**: positions can be disabled (locked) and enabled at runtime
 * - **Single location**: an item is in at most one position at a time. The item
 *   records where it is in its `inventory_id` and `position` attributes. Use
 *   `move()` to move an item from wherever it is.
 * - **Effects**: items can apply effects to the inventory's owner while they are
 *   in it
 * - **Events**: adding and removing items runs `insert` and `remove` events on the
 *   inventory, the slot, and the item
 *
 * All position state lives in the `positions` attribute, compiled from the
 * `@contains` blocks:
 *
 * <pre><code>
 * positions: {
 *   left_ring: {slot_id: "ring_slot", enabled: true, contents: ["silver_ring"]}
 * }
 * </code></pre>
 *
 * Don't change `positions` directly; use the methods of this class. They replace
 * the whole record on every change, so the change is saved and observers (such as
 * views) are told about it, and `on_positions_changed` runs.
 *
 * **Define in Rez:**
 * <pre><code>
 * &#64;inventory player_inv {
 *   &#64;contains weapon {
 *     slot_id: #s_weapon
 *     contents: [#item_sword]
 *   }
 *   &#64;contains left_ring {
 *     slot_id: #s_ring
 *   }
 *   &#64;contains right_ring {
 *     slot_id: #s_ring
 *     enabled: false
 *   }
 * }
 * </code></pre>
 *
 * @example <caption>Add an item at runtime</caption>
 * const inv = $("player_inv");
 * const decision = inv.add("left_ring", "item_gold_ring");
 * if(decision.wasNo) {
 *   console.log(decision.reason);
 * }
 * @example <caption>Move an item from wherever it is</caption>
 * $("player_inv").move("weapon", "item_axe");
 */
class RezInventory extends RezBasicObject {
  constructor(id, attributes) {
    super("inventory", id, attributes);
  }

  /**
   * @function elementInitializer
   * @memberof RezInventory
   * @description Called during the init process. Resolves the owner, then empties
   * each position and adds its starting `contents` back through the add path, so
   * that starting items fire `insert` events and apply effects like any other.
   * Starting items are placed even in positions that begin disabled.
   * @throws {Error} if a starting item can't be placed
   */
  elementInitializer() {
    this.resolveOwner();

    const positions = this.getAttributeValue("positions");
    const startingContents = Object.entries(positions).map(([name, pos]) => [name, pos.contents]);

    this.#writePositions(Object.fromEntries(
      Object.entries(positions).map(([name, pos]) => [name, {...pos, contents: []}])
    ));

    for(const [name, itemIds] of startingContents) {
      for(const itemId of itemIds) {
        const decision = this.#checkAdd(name, itemId, {initializing: true});
        if(!decision.result) {
          throw new Error(`Inventory |${this.id}|: cannot place starting item |${itemId}| in position |${name}|: ${decision.reason}`);
        }
        this.#insertItem(name, itemId);
      }
    }
  }

  /**
   * @function resolveOwner
   * @memberof RezInventory
   * @description If `owner_id` was not authored directly, find the actor that
   * declares this inventory as its `container_id` and record it as `owner_id`,
   * so that `inventory.owner` is reliably available (for the actor veto, effect
   * application, and insert/remove event handlers). Author ownership in a single
   * place (`actor.container_id`); an explicitly authored `owner_id` still wins.
   * Safe at init time because all game objects are registered before any object
   * is initialised.
   */
  resolveOwner() {
    if(this.hasValue("owner_id")) return;

    const owner = this.game.filterObjects(
      (o) => o.element === "actor" && o.getAttributeValue("container_id", null) === this.id
    )[0];

    if(owner) {
      this.setAttribute("owner_id", owner.id);
    }
  }

  //---------------------------------------------------------------------------
  // Position state
  //---------------------------------------------------------------------------

  #positions() {
    return this.getAttributeValue("positions");
  }

  #position(name) {
    const pos = this.#positions()[name];
    if(!pos) {
      throw new Error(`Inventory |${this.id}| does not have a position |${name}|!`);
    }
    return pos;
  }

  #writePositions(positions) {
    this.setAttribute("positions", positions);
  }

  // Replaces the record for one position with the result of fn(record). The
  // record is never changed in place, which is what makes the change visible to
  // saving and observers, and lets copies of an inventory share a record safely.
  #updatePosition(name, fn) {
    const positions = this.#positions();
    this.#writePositions({...positions, [name]: fn(this.#position(name))});
  }

  /**
   * @function locationOf
   * @memberof RezInventory
   * @static
   * @param {string} itemId
   * @returns {object|null} `{inventory, position}` for the inventory and position
   * the item is in, or `null` if it isn't in any inventory
   * @example
   * const where = RezInventory.locationOf("item_gold_ring");
   * if(where) console.log(`In ${where.inventory.id}/${where.position}`);
   */
  static locationOf(itemId) {
    // An item that isn't anywhere has a null inventory_id, or a placeholder if
    // it has never been placed.
    const item = $(itemId);
    const inventoryId = item.getAttributeValue("inventory_id", null);
    if(inventoryId == null || Rez.isPlaceholder(inventoryId)) return null;
    return {inventory: $(inventoryId), position: item.getAttributeValue("position")};
  }

  #ownerParams() {
    const owner = this.owner ?? null;
    return {owner_id: owner?.id ?? null, owner};
  }

  /**
   * @function hasPosition
   * @memberof RezInventory
   * @param {string} name name of a position
   * @returns {boolean} true if this inventory has a position with the given name
   */
  hasPosition(name) {
    return Object.hasOwn(this.#positions(), name);
  }

  /**
   * @function getPositionNames
   * @memberof RezInventory
   * @returns {string[]} the names of this inventory's positions
   */
  getPositionNames() {
    return Object.keys(this.#positions());
  }

  /**
   * @function getPositions
   * @memberof RezInventory
   * @returns {object[]} a `{name, slot, enabled, contents}` description of each
   * position, where `slot` is the RezSlot and `contents` is an array of item ids
   * @example
   * for(const {name, slot, enabled, contents} of inv.getPositions()) {
   *   const available = inv.isAvailable(name);
   *   // enabled=false → locked; available=false → excluded by another position
   * }
   */
  getPositions() {
    return Object.entries(this.#positions()).map(([name, pos]) => ({
      name,
      slot: $t(pos.slot_id, "slot", true),
      enabled: pos.enabled,
      contents: [...pos.contents]
    }));
  }

  /**
   * @function getSlot
   * @memberof RezInventory
   * @param {string} name name of a position
   * @returns {RezSlot} the slot that the position uses
   * @throws {Error} if there is no such position
   */
  getSlot(name) {
    return $t(this.#position(name).slot_id, "slot", true);
  }

  /**
   * @function addPosition
   * @memberof RezInventory
   * @param {string} name name of the new position
   * @param {string} slotId id of the `@slot` the position uses
   * @param {boolean} [enabled=true] whether the position starts enabled
   * @description Adds a new, empty position to the inventory at runtime.
   * @throws {Error} if the position already exists
   */
  addPosition(name, slotId, enabled = true) {
    if(this.hasPosition(name)) {
      throw new Error(`Inventory |${this.id}| already has a position |${name}|!`);
    }
    $t(slotId, "slot", true);
    this.#writePositions({...this.#positions(), [name]: {slot_id: slotId, enabled, contents: []}});
  }

  //---------------------------------------------------------------------------
  // Contents
  //---------------------------------------------------------------------------

  /**
   * @function itemsIn
   * @memberof RezInventory
   * @param {string} name name of a position
   * @returns {string[]} a copy of the ids of the items in the position
   */
  itemsIn(name) {
    return [...this.#position(name).contents];
  }

  /**
   * @function firstItemIn
   * @memberof RezInventory
   * @param {string} name name of a position
   * @returns {string|undefined} id of the first item in the position
   */
  firstItemIn(name) {
    return this.#position(name).contents[0];
  }

  /**
   * @function countItemsIn
   * @memberof RezInventory
   * @param {string} name name of a position
   * @returns {number} number of items in the position
   */
  countItemsIn(name) {
    return this.#position(name).contents.length;
  }

  /**
   * @function isOccupied
   * @memberof RezInventory
   * @param {string} name name of a position
   * @returns {boolean} true if there is at least one item in the position
   */
  isOccupied(name) {
    return this.countItemsIn(name) > 0;
  }

  /**
   * @function allItems
   * @memberof RezInventory
   * @returns {string[]} ids of every item in every position
   */
  allItems() {
    return Object.values(this.#positions()).flatMap((pos) => pos.contents);
  }

  /**
   * @function positionOf
   * @memberof RezInventory
   * @param {string} itemId
   * @returns {string|undefined} name of the position holding the item, or undefined
   * if it isn't in this inventory
   */
  positionOf(itemId) {
    return Object.entries(this.#positions()).find(([, pos]) => pos.contents.includes(itemId))?.[0];
  }

  /**
   * @function hasItem
   * @memberof RezInventory
   * @param {string} itemId
   * @returns {boolean} true if the item is in any position of this inventory
   */
  hasItem(itemId) {
    return this.positionOf(itemId) !== undefined;
  }

  //---------------------------------------------------------------------------
  // Enabled & available
  //---------------------------------------------------------------------------

  /**
   * @function isEnabled
   * @memberof RezInventory
   * @param {string} name name of a position
   * @returns {boolean} true if the position is enabled
   * @description Positions start enabled unless their `@contains` block says
   * `enabled: false`. Use `enable()` at runtime when the player unlocks one.
   * @example <caption>Define a locked position in Rez</caption>
   * // @inventory player_equip {
   * //   @contains ring1 {slot_id: #s_ring}
   * //   @contains ring2 {slot_id: #s_ring enabled: false}
   * // }
   * @example <caption>Unlock it at runtime</caption>
   * if(player.level >= 5) {
   *   $("player_equip").enable("ring2");
   * }
   */
  isEnabled(name) {
    return this.#position(name).enabled;
  }

  /**
   * @function enable
   * @memberof RezInventory
   * @param {string} name name of a position
   * @description Enables the position so items can be added to it.
   */
  enable(name) {
    this.#updatePosition(name, (pos) => ({...pos, enabled: true}));
  }

  /**
   * @function disable
   * @memberof RezInventory
   * @param {string} name name of a position
   * @description Disables the position so no further items can be added to it.
   * Items already in it stay there.
   */
  disable(name) {
    this.#updatePosition(name, (pos) => ({...pos, enabled: false}));
  }

  /**
   * @function isAvailable
   * @memberof RezInventory
   * @param {string} name name of a position
   * @returns {boolean} true if the position is not blocked by an exclusion
   * @description Useful for greying out positions in an inventory UI.
   */
  isAvailable(name) {
    return !this.isBlockedByExclusion(name);
  }

  /**
   * @function isBlockedByExclusion
   * @memberof RezInventory
   * @param {string} name name of a position
   * @returns {boolean} true if another occupied position's slot excludes this
   * position's slot, or this position's slot excludes the slot of another occupied
   * position
   */
  isBlockedByExclusion(name) {
    // `excludes` holds slot ids; accept {$ref} objects too in case a ref has
    // not been resolved.
    const excludedBy = (slotId) => new Set(
      [...$t(slotId, "slot", true).getAttributeValue("excludes", new Set())].map((ref) => ref?.$ref ?? ref)
    );

    const targetSlotId = this.#position(name).slot_id;
    const targetExcludes = excludedBy(targetSlotId);

    for(const [otherName, other] of Object.entries(this.#positions())) {
      if(otherName === name || other.contents.length === 0) continue;
      if(targetExcludes.has(other.slot_id) || excludedBy(other.slot_id).has(targetSlotId)) {
        return true;
      }
    }

    return false;
  }

  //---------------------------------------------------------------------------
  // Fit
  //---------------------------------------------------------------------------

  /**
   * @function positionAccepts
   * @memberof RezInventory
   * @param {string} name name of a position
   * @param {string} itemId
   * @returns {boolean} true if the item's type is one that the position's slot accepts
   */
  positionAccepts(name, itemId) {
    const accepts = this.getSlot(name).getAttributeValue("accepts");
    return Rez.isTypeOf($(itemId).getAttributeValue("type"), accepts);
  }

  /**
   * @function itemFits
   * @memberof RezInventory
   * @param {string} name name of a position
   * @param {string} itemId
   * @returns {boolean} true if the item fits alongside the position's other contents
   * @description If the position's slot has `has_capacity: true`, items count
   * towards `slot.capacity` using their `size` attribute, defaulting to `1` if
   * unset. This means `capacity: 1` naturally limits a position to a single item
   * unless an item explicitly opts out with `size: 0` or takes up more room with
   * `size: 2+`. Slots without `has_capacity: true` accept any number of items.
   */
  itemFits(name, itemId) {
    const slot = this.getSlot(name);
    if(!slot.has_capacity) return true;

    const sizeOf = (id) => $(id).getAttributeValue("size", 1);
    const used = this.#position(name).contents
      .filter((id) => id !== itemId)
      .reduce((amount, id) => amount + sizeOf(id), 0);
    return used + sizeOf(itemId) <= slot.capacity;
  }

  /**
   * @function totalWeight
   * @memberof RezInventory
   * @returns {number} sum of the `weight` attribute of every item in every position
   */
  totalWeight() {
    return this.allItems().reduce((total, itemId) => {
      return total + $(itemId).getAttributeValue("weight", 0);
    }, 0);
  }

  /**
   * @function maxWeight
   * @memberof RezInventory
   * @returns {number} the `max_weight` attribute, or `Infinity` if not set
   */
  maxWeight() {
    return this.getAttributeValue("max_weight", Infinity);
  }

  /**
   * @function remainingWeight
   * @memberof RezInventory
   * @returns {number} how much more weight this inventory can carry before reaching `max_weight`
   */
  remainingWeight() {
    return this.maxWeight() - this.totalWeight();
  }

  /**
   * @function isOverweight
   * @memberof RezInventory
   * @returns {boolean} true if the inventory's total weight exceeds `max_weight`
   */
  isOverweight() {
    return this.totalWeight() > this.maxWeight();
  }

  /**
   * @function itemFitsWeight
   * @memberof RezInventory
   * @param {string} itemId
   * @returns {boolean} true if this inventory can hold the item without exceeding
   * `max_weight`. An item already in this inventory is only counted once.
   */
  itemFitsWeight(itemId) {
    const alreadyHere = this.hasItem(itemId) ? $(itemId).getAttributeValue("weight", 0) : 0;
    return this.totalWeight() - alreadyHere + $(itemId).getAttributeValue("weight", 0) <= this.maxWeight();
  }

  //---------------------------------------------------------------------------
  // Adding, removing & moving
  //---------------------------------------------------------------------------

  /**
   * @function canAdd
   * @memberof RezInventory
   * @param {string} name name of a position
   * @param {string} itemId
   * @returns {RezDecision} whether the item can be added to the position
   * @description Checks, in order: the position is enabled; the item isn't
   * already somewhere (`failed_on: "located"`, use `move()` instead); the slot
   * accepts the item's type; the position isn't blocked by an exclusion; the item
   * fits the slot's capacity; the item fits the inventory's `max_weight`; and
   * finally the owner's `on_accept_item` handler. When the decision is no, its
   * `failed_on` data says which check failed.
   */
  canAdd(name, itemId) {
    return this.#checkAdd(name, itemId);
  }

  #checkAdd(name, itemId, {initializing = false, moving = false} = {}) {
    const decision = new RezDecision("canAdd");
    decision.setData("inventory_id", this.id);
    decision.setData("position", name);
    decision.setData("item_id", itemId);

    const item = $(itemId);

    if(!initializing && !this.isEnabled(name)) {
      decision.no("position is not enabled").setData("failed_on", "enabled");
    } else if(!moving && RezInventory.locationOf(itemId)) {
      const {inventory, position} = RezInventory.locationOf(itemId);
      decision
        .no(`item is already in |${inventory.id}/${position}|`)
        .setData("failed_on", "located");
    } else if(!this.positionAccepts(name, itemId)) {
      decision.no("position doesn't take this kind of item").setData("failed_on", "accepts");
    } else if(this.isBlockedByExclusion(name)) {
      decision.no("position is blocked by exclusion").setData("failed_on", "excludes");
    } else if(!this.itemFits(name, itemId)) {
      decision.no("does not fit").setData("failed_on", "capacity");
    } else if(!this.itemFitsWeight(itemId)) {
      decision.no("too heavy").setData("failed_on", "weight");
    } else if(this.owner != null) {
      const actorDecision = this.owner.checkItem(this.id, this.getSlot(name).id, name, itemId);
      if(actorDecision.result) {
        decision.yes();
      } else {
        decision.no(actorDecision.reason).setData("failed_on", "actor");
      }
    } else {
      decision.yes();
    }

    return decision;
  }

  /**
   * @function add
   * @memberof RezInventory
   * @param {string} name name of a position
   * @param {string} itemId
   * @returns {RezDecision} the decision from `canAdd`. When it is yes the item has
   * been added; otherwise nothing has changed and the decision says why.
   * @description Adds an item, that isn't already somewhere, to the position. Runs
   * `insert` events on the inventory, the slot, and the item (in that order), and
   * applies the item's effects to the owner.
   * @example
   * const d = inv.add("weapon", "item_axe");
   * if(d.wasNo) showMessage(d.reason);
   */
  add(name, itemId) {
    const decision = this.canAdd(name, itemId);
    if(decision.result) {
      this.#insertItem(name, itemId);
    }
    return decision;
  }

  /**
   * @function canRemove
   * @memberof RezInventory
   * @param {string} name name of a position
   * @param {string} itemId
   * @returns {RezDecision} whether the item can be removed from the position. The
   * decision is no (`failed_on: "missing"`) if the item isn't in it.
   */
  canRemove(name, itemId) {
    const decision = new RezDecision("canRemove");
    decision.setData("inventory_id", this.id);
    decision.setData("position", name);
    decision.setData("item_id", itemId);

    if(!this.#position(name).contents.includes(itemId)) {
      return decision
        .no(`No item |${itemId}| in position |${name}| of inventory |${this.id}|!`)
        .setData("failed_on", "missing");
    }

    decision.defaultYes();
    return decision;
  }

  /**
   * @function remove
   * @memberof RezInventory
   * @param {string} name name of a position
   * @param {string} itemId
   * @returns {RezDecision} the decision from `canRemove`. When it is yes the item has
   * been removed; otherwise nothing has changed and the decision says why.
   * @description Removes the item from the position. Runs `remove` events on the
   * slot, the item, and the inventory (in that order), and removes the item's
   * effects from the owner.
   */
  remove(name, itemId) {
    const decision = this.canRemove(name, itemId);
    if(decision.result) {
      this.#removeItem(name, itemId);
    }
    return decision;
  }

  /**
   * @function clear
   * @memberof RezInventory
   * @param {string} name name of a position
   * @description Removes every item from the position.
   */
  clear(name) {
    for(const itemId of this.itemsIn(name)) {
      this.remove(name, itemId);
    }
  }

  /**
   * @function setContents
   * @memberof RezInventory
   * @param {string} name name of a position
   * @param {string|string[]} itemIds the item or items the position should hold
   * @returns {RezDecision[]} a decision for each item added, in order
   * @description Empties the position, then adds each item. An item that can't
   * be added is left where it was and its decision says why.
   */
  setContents(name, itemIds) {
    this.clear(name);
    return ensureArray(itemIds).map((itemId) => this.add(name, itemId));
  }

  /**
   * @function canMove
   * @memberof RezInventory
   * @param {string} name name of a position in this inventory
   * @param {string} itemId
   * @returns {RezDecision} whether the item can be moved from wherever it is now
   * into the position. Combines `canRemove` at its current position (if it has one)
   * with the checks of `canAdd`.
   */
  canMove(name, itemId) {
    const location = RezInventory.locationOf(itemId);
    if(location) {
      if(location.inventory === this && location.position === name) {
        const decision = new RezDecision("canMove");
        decision.yes();
        return decision;
      }
      const removal = location.inventory.canRemove(location.position, itemId);
      if(!removal.result) {
        return removal;
      }
    }
    return this.#checkAdd(name, itemId, {moving: true});
  }

  /**
   * @function move
   * @memberof RezInventory
   * @param {string} name name of a position in this inventory
   * @param {string} itemId
   * @returns {RezDecision} the decision from `canMove`. When it is yes the item has
   * been removed from where it was (if anywhere) and added to the position.
   * @description Moves an item into the position from wherever it is, which may be
   * another position of this inventory, another inventory, or nowhere.
   * @example
   * $("chest").move("contents", "item_gold_ring");
   */
  move(name, itemId) {
    const decision = this.canMove(name, itemId);
    if(!decision.result) {
      return decision;
    }

    const location = RezInventory.locationOf(itemId);
    if(location?.inventory === this && location.position === name) {
      return decision;
    }
    if(location) {
      location.inventory.#removeItem(location.position, itemId);
    }
    this.#insertItem(name, itemId);
    return decision;
  }

  #insertItem(name, itemId) {
    const item = $(itemId);
    if(!item.hasAttribute("type")) {
      throw new Error(`Attempt to add |${itemId}| to inventory |${this.id}|, but it does not define a 'type'!`);
    }

    this.#updatePosition(name, (pos) => ({...pos, contents: [...pos.contents, itemId]}));
    item.setAttribute("inventory_id", this.id);
    item.setAttribute("position", name);

    const slot = this.getSlot(name);
    const params = {inventory_id: this.id, slot_id: slot.id, position: name, item_id: itemId, ...this.#ownerParams()};

    this.runEvent("insert", params);
    slot.runEvent("insert", params);
    item.runEvent("insert", params);

    this.applyEffects(name, itemId);
  }

  #removeItem(name, itemId) {
    const item = $(itemId);

    this.#updatePosition(name, (pos) => ({...pos, contents: pos.contents.filter((id) => id !== itemId)}));
    item.setAttribute("inventory_id", null);
    item.setAttribute("position", null);

    const slot = this.getSlot(name);
    const params = {inventory_id: this.id, slot_id: slot.id, position: name, item_id: itemId, ...this.#ownerParams()};

    slot.runEvent("remove", params);
    item.runEvent("remove", params);
    this.runEvent("remove", params);

    this.removeEffects(name, itemId);
  }

  //---------------------------------------------------------------------------
  // Effects
  //---------------------------------------------------------------------------

  /**
   * @function shouldApplyEffects
   * @memberof RezInventory
   * @param {string} name name of a position
   * @returns {boolean} true if items in the position apply their effects: the
   * inventory has an owner and both the inventory and the position's slot have
   * `apply_effects: true`
   */
  shouldApplyEffects(name) {
    return this.owner != null && this.apply_effects && this.getSlot(name).apply_effects;
  }

  /**
   * @function applyEffects
   * @memberof RezInventory
   * @param {string} name name of a position
   * @param {string} itemId
   * @returns {boolean} whether any effects were applied
   */
  applyEffects(name, itemId) {
    if(!this.shouldApplyEffects(name)) return false;

    const effectIds = $(itemId).getAttributeValue("effect_ids", null);
    if(!effectIds) return false;

    const location = {inventory_id: this.id, slot_id: this.getSlot(name).id, position: name};

    for(const effectId of effectIds) {
      $t(effectId, "effect").apply(this.owner_id, itemId, location);
    }
    return true;
  }

  /**
   * @function removeEffects
   * @memberof RezInventory
   * @param {string} name name of a position
   * @param {string} itemId
   * @returns {boolean} whether any effects were removed
   */
  removeEffects(name, itemId) {
    if(!this.shouldApplyEffects(name)) return false;

    const effectIds = $(itemId).getAttributeValue("effect_ids", null);
    if(!effectIds) return false;

    const location = {inventory_id: this.id, slot_id: this.getSlot(name).id, position: name};

    for(const effectId of effectIds) {
      $t(effectId, "effect").remove(this.owner_id, itemId, location);
    }
    return true;
  }
}

window.Rez.RezInventory = RezInventory;
