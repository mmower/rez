//-----------------------------------------------------------------------------
// Inventory
//-----------------------------------------------------------------------------

/**
 * @class RezInventory
 * @extends RezBasicObject
 * @category Elements
 * @description Manages a collection of slots that can hold items.
 *
 * An inventory is a container system that organizes items into typed slots.
 * Each slot can accept items of a specific type and may have capacity limits.
 * Inventories can be owned by actors, enabling equipment systems with effects.
 *
 * Key features:
 * - **Typed Slots**: Each slot accepts only items of a matching type
 * - **Capacity**: Slots can have size limits based on item sizes
 * - **Weight**: Inventories can have an overall `max_weight`, checked against
 *   the total `weight` of all items they contain
 * - **Effects**: Items can apply effects to the inventory's owner when inserted
 * - **Events**: Triggers events on insert/remove for items, slots, and inventory
 *
 * Slots are defined as a binding list on the `slots` attribute where each
 * binding key (prefix) is the slot position name and the value is a reference
 * to a `@slot` element that defines the slot's type configuration. Multiple
 * positions can share the same slot type definition.
 *
 * **Define in Rez:**
 * <pre><code>
 * &#64;inventory player_inv {
 *   slots: [weapon: #s_weapon, armor: #s_armor]
 *   initial_weapon: [#item_sword]
 * }
 * </code></pre>
 *
 * @example <caption>Add an item at runtime</caption>
 * const inv = $("player_inv");
 * if(inv.canAddItemForSlot("weapon", "item_axe").result) {
 *   inv.addItemToSlot("weapon", "item_axe");
 * }
 */
class RezInventory extends RezBasicObject {
  constructor(id, attributes) {
    super("inventory", id, attributes);
  }

  /**
   * @function elementInitializer
   * @memberof RezInventory
   * @description called as part of the init process this creates the initial inventory slots
   */
  elementInitializer() {
    this.resolveOwner();
    this.addInitialContents();
    this.addInitialEnabledStates();
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

  addInitialContents() {
    for(const prefix of Object.keys(this.getAttributeValue("slots"))) {
      const initialContents = this.getAttributeValue(`initial_${prefix}`, []);
      for(const contentId of initialContents) {
        const decision = this.addItemToSlot(prefix, contentId);
        if(!decision.result) {
          throw new Error(`Inventory |${this.id}|: cannot place initial item |${contentId}| in slot |${prefix}|: ${decision.reason}`);
        }
      }
    }
  }

  addInitialEnabledStates() {
    for(const prefix of Object.keys(this.getAttributeValue("slots"))) {
      const enabled = this.getAttributeValue(`initial_${prefix}_enabled`, true);
      this.setAttribute(`${prefix}_enabled`, enabled);
    }
  }

  /**
   * @function addSlot
   * @memberof RezInventory
   * @param {string} slotBinding - the binding prefix for the slot position
   * @param {string} slotId - the slot element id (unused but kept for API clarity)
   * @description add a new slot to the inventory
   */
  addSlot(slotBinding, _slotId) {
    const attrName = `${slotBinding}_contents`;
    if(!this.hasAttribute(attrName)) {
      this.setAttribute(attrName, []);
      this.createStaticProperty(attrName);
    }
  }

  /**
   * @function getSlots
   * @memberof RezInventory
   * @returns {array} array of {prefix, slot} objects for every slot position in this inventory
   * @example
   * for(const {prefix, slot} of inv.getSlots()) {
   *   const available = inv.isSlotAvailable(prefix);
   *   // render slot UI using prefix (binding name) and slot (RezSlot object with name, accepts, etc.)
   * }
   */
  getSlots() {
    return Object.entries(this.getAttributeValue("slots")).map(([prefix, slotId]) => ({
      prefix,
      slot: $t(slotId, "slot", true)
    }));
  }

  /**
   * @function getSlot
   * @memberof RezInventory
   * @param {string} name - the binding prefix identifying the slot position
   * @returns {object} reference to the slot element for this binding, or throws
   * if the binding does not exist in this inventory.
   */
  getSlot(name) {
    const slotId = this.getAttributeValue("slots")[name];
    if(!slotId) {
      throw new Error(`Inventory |${this.id}| does not have slot binding |${name}|!`);
    }
    return $t(slotId, "slot", true);
  }

  /**
   * @function getFirstItemForSlot
   * @memberof RezInventory
   * @param {string} slotBinding
   * @returns {string} id of first item in the slot
   */
  getFirstItemForSlot(slotBinding) {
    return this.getItemsForSlot(slotBinding)[0];
  }

  /**
   * @function getItemsForSlot
   * @memberof RezInventory
   * @param {string} slotBinding
   * @returns {array} contents of the specified slot
   */
  getItemsForSlot(slotBinding) {
    this.getSlot(slotBinding); // validates binding exists
    return this.getAttribute(`${slotBinding}_contents`);
  }

  /**
   * @function slotIsOccupied
   * @memberof RezInventory
   * @param {string} slotBinding
   * @returns {boolean} true if there is at least one item in the slot
   */
  slotIsOccupied(slotBinding) {
    return this.countItemsInSlot(slotBinding) > 0;
  }

  /**
   * @function isSlotAvailable
   * @memberof RezInventory
   * @param {string} slotBinding - the binding prefix identifying the slot position
   * @returns {boolean} true if the slot is not blocked by any exclusion rule
   * @description Useful for greying out slot categories in inventory UI.
   */
  isSlotAvailable(slotBinding) {
    return !this.isBlockedByExclusion(slotBinding);
  }

  /**
   * @function isSlotEnabled
   * @memberof RezInventory
   * @param {string} slotBinding - the binding prefix identifying the slot position
   * @returns {boolean} true if the slot has been enabled
   * @description Slots default to enabled. Use `initial_{prefix}_enabled: false` in the
   * inventory definition to start a slot disabled, then call `enableSlot()` at runtime
   * when the player unlocks it (e.g. on reaching a required level).
   * @example <caption>Define a locked slot in Rez</caption>
   * // @inventory player_equip {
   * //   slots: [ring1: #s_ring, ring2: #s_ring]
   * //   initial_ring2_enabled: false
   * // }
   * @example <caption>Unlock at runtime</caption>
   * if(player.level >= 5) {
   *   $("player_equip").enableSlot("ring2");
   * }
   * @example <caption>Check in UI</caption>
   * for(const {prefix, slot} of inv.getSlots()) {
   *   const enabled = inv.isSlotEnabled(prefix);
   *   const available = inv.isSlotAvailable(prefix);
   *   // enabled=false → locked; available=false → excluded by another equipped item
   * }
   */
  isSlotEnabled(slotBinding) {
    return this.getAttributeValue(`${slotBinding}_enabled`, true);
  }

  /**
   * @function enableSlot
   * @memberof RezInventory
   * @param {string} slotBinding - the binding prefix identifying the slot position
   * @description Enables the slot so items can be added to it.
   * @example
   * $("player_equip").enableSlot("ring2");
   */
  enableSlot(slotBinding) {
    this.getSlot(slotBinding); // validates binding exists
    this.setAttribute(`${slotBinding}_enabled`, true);
  }

  /**
   * @function disableSlot
   * @memberof RezInventory
   * @param {string} slotBinding - the binding prefix identifying the slot position
   * @description Disables the slot so no further items can be added to it.
   * @example
   * $("player_equip").disableSlot("ring2");
   */
  disableSlot(slotBinding) {
    this.getSlot(slotBinding); // validates binding exists
    this.setAttribute(`${slotBinding}_enabled`, false);
  }

  /**
   * @function _writeSlotContents
   * @memberof RezInventory
   * @private
   * @param {string} slotBinding
   * @param {array} itemIds array of item id's
   * @description Low-level, unguarded write of a slot's contents array. Does NOT
   * validate items, fire events, or reconcile effects. Internal use only; author
   * code should use setSlot/setItemsForSlot/addItemToSlot which go through validation.
   */
  _writeSlotContents(slotBinding, itemIds) {
    this.getSlot(slotBinding); // validates binding exists
    this.setAttribute(`${slotBinding}_contents`, itemIds);
  }

  /**
   * @function setSlot
   * @memberof RezInventory
   * @param {string} slotBinding
   * @param {array} itemIds array of item id's
   * @returns {RezDecision[]} a decision for each item added (see setItemsForSlot)
   * @description Replaces the slot's contents with the given items. Existing
   * occupants are removed (firing remove events and releasing their effects) and
   * each new item is added through the validated path. Alias for setItemsForSlot.
   */
  setSlot(slotBinding, itemIds) {
    return this.setItemsForSlot(slotBinding, itemIds);
  }

  /**
   * @function appendItemToSlot
   * @memberof RezInventory
   * @param {string} slotBinding
   * @param {string} itemId
   * @returns {RezDecision} the decision from addItemToSlot
   * @description Appends the given item to the given slot through the validated
   * add path (fires events, applies effects, and may refuse). Retained for API
   * compatibility; previously this was an unconditional raw push.
   */
  appendItemToSlot(slotBinding, itemId) {
    return this.addItemToSlot(slotBinding, itemId);
  }

  /**
   * @function appendToSlot
   * @memberof RezInventory
   * @param {string} slotBinding
   * @param {string|array} itemOrItems either an item_id or array of item_id's to append to the slot
   * @returns {RezDecision[]} a decision for each item, in order
   * @description add either a single item_id or an array of item_ids to the slot,
   * each through the validated add path.
   */
  appendToSlot(slotBinding, itemOrItems) {
    return ensureArray(itemOrItems).map((itemId) => {
      return this.addItemToSlot(slotBinding, itemId);
    });
  }

  /**
   * @function setItemForSlot
   * @memberof RezInventory
   * @param {string} slotBinding
   * @param {string} itemId
   * @returns {RezDecision[]} a decision for the added item (see setItemsForSlot)
   * @description replaces any existing item content for the slot with this item
   */
  setItemForSlot(slotBinding, itemId) {
    return this.setItemsForSlot(slotBinding, [itemId]);
  }

  /**
   * @function setItemsForSlot
   * @memberof RezInventory
   * @param {string} slotBinding
   * @param {array} items array of item ids
   * @returns {RezDecision[]} a decision for each item added, in order
   * @description Replaces any existing item content for the slot with these items.
   * Existing occupants are removed first (firing remove events and releasing their
   * effects), then each new item is added through the validated path, so an item
   * the slot can't accept is refused (and reflected in its decision) rather than
   * silently set.
   */
  setItemsForSlot(slotBinding, items) {
    const current = [...this.getItemsForSlot(slotBinding)];
    current.forEach((itemId) => this._removeItem(slotBinding, itemId));
    return ensureArray(items).map((itemId) => this.addItemToSlot(slotBinding, itemId));
  }

  /**
   * @function countItemsInSlot
   * @memberof RezInventory
   * @param {string} slotBinding
   * @returns {integer} number of items in the given slot
   */
  countItemsInSlot(slotBinding) {
    return this.getItemsForSlot(slotBinding).length;
  }

  /**
   * @function slotContainsItem
   * @memberof RezInventory
   * @param {string} slotBinding
   * @param {string} itemId
   * @returns {boolean} true if the item_id is in the slot
   */
  slotContainsItem(slotBinding, itemId) {
    return this.getItemsForSlot(slotBinding).some((anItemId) => itemId === anItemId);
  }

  /**
   * @function containsItem
   * @memberof RezInventory
   * @param {string} itemId
   * @returns {string|undefined} binding prefix of the slot containing the item, or undefined
   */
  containsItem(itemId) {
    for(const prefix of Object.keys(this.getAttributeValue("slots"))) {
      if(this.slotContainsItem(prefix, itemId)) return prefix;
    }
    return undefined;
  }

  /**
   * @function itemFitsInSlot
   * @memberof RezInventory
   * @param {string} slotBinding
   * @param {string} itemId
   * @returns {boolean} true if the item will fit with any other contents of the slot
   * @description If the slot has `has_capacity: true`, items count towards
   * `slot.capacity` using their `size` attribute, defaulting to `1` if unset.
   * This means `capacity: 1` naturally limits a slot to a single item unless
   * an item explicitly opts out with `size: 0` (e.g. a weightless item) or
   * takes up more room with `size: 2+`. Slots without `has_capacity: true`
   * accept any number of items.
   */
  itemFitsInSlot(slotBinding, itemId) {
    const slot = this.getSlot(slotBinding);
    if(!slot.has_capacity) return true;

    const itemSize = $(itemId).getAttributeValue("size", 1);
    const usedCapacity = this.getItemsForSlot(slotBinding).reduce((amount, id) => {
      return amount + $(id).getAttributeValue("size", 1);
    }, 0);
    return usedCapacity + itemSize <= slot.capacity;
  }

  /**
   * @function totalWeight
   * @memberof RezInventory
   * @returns {number} sum of the `weight` attribute of every item in every slot
   */
  totalWeight() {
    return Object.keys(this.getAttributeValue("slots")).reduce((total, prefix) => {
      return total + this.getItemsForSlot(prefix).reduce((amount, itemId) => {
        return amount + $(itemId).getAttributeValue("weight", 0);
      }, 0);
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
   * @returns {boolean} true if adding this item would not exceed `max_weight`
   */
  itemFitsWeight(itemId) {
    return this.totalWeight() + $(itemId).getAttributeValue("weight", 0) <= this.maxWeight();
  }

  /**
   * @function isBlockedByExclusion
   * @memberof RezInventory
   * @param {string} slotBinding
   * @returns {boolean} true if an occupied slot excludes this slot, or this slot excludes an occupied slot
   */
  isBlockedByExclusion(slotBinding) {
    const slots = this.getAttributeValue("slots");
    const targetSlotId = slots[slotBinding];
    const targetExcludes = this.getSlot(slotBinding).getAttributeValue("excludes", new Set());

    for(const [prefix, slotId] of Object.entries(slots)) {
      if(prefix === slotBinding) continue;
      if(!this.slotIsOccupied(prefix)) continue;

      // Direction 1: target slot excludes this occupied position's slot type
      if([...targetExcludes].some(ref => ref.$ref === slotId)) {
        return true;
      }

      // Direction 2: this occupied position's slot type excludes the target slot
      const otherExcludes = $t(slotId, "slot", true).getAttributeValue("excludes", new Set());
      if([...otherExcludes].some(ref => ref.$ref === targetSlotId)) {
        return true;
      }
    }

    return false;
  }

  /**
   * @function slotAcceptsItem
   * @memberof RezInventory
   * @param {string} slotBinding
   * @param {string} itemId
   * @returns {boolean} true if the given item has a type that this slot accepts
   */
  slotAcceptsItem(slotBinding, itemId) {
    const slot = this.getSlot(slotBinding);
    const accepts = slot.getAttributeValue("accepts");
    const item = $(itemId);
    const type = item.getAttributeValue("type");
    return Rez.isTypeOf(type, accepts);
  }

  /**
   * @function canAddItemForSlot
   * @memberof RezInventory
   * @param {string} slotBinding
   * @param {string} itemId
   * @returns {RezDecision} decision object with result
   */
  canAddItemForSlot(slotBinding, itemId) {
    const decision = new RezDecision("canItemForSlot");

    if(!this.isSlotEnabled(slotBinding)) {
      decision.no("slot is not enabled").setData("failed_on", "enabled");
    } else if(!this.slotAcceptsItem(slotBinding, itemId)) {
      decision
        .no("slot doesn't take this kind of item")
        .setData("failed_on", "accepts");
    } else if(this.isBlockedByExclusion(slotBinding)) {
      decision.no("slot is blocked by exclusion").setData("failed_on", "excludes");
    } else if(!this.itemFitsInSlot(slotBinding, itemId)) {
      decision.no("does not fit").setData("failed_on", "capacity");
    } else if(!this.itemFitsWeight(itemId)) {
      decision.no("too heavy").setData("failed_on", "weight");
    } else if(this.owner != null) {
      const actorDecision = this.owner.checkItem(this.id, slotBinding, itemId);
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
   * @function canRemoveItemFromSlot
   * @memberof RezInventory
   * @param {string} slotBinding
   * @param {string} itemId
   * @returns {RezDecision} decision object with result, defaulting to yes
   */
  canRemoveItemFromSlot(slotBinding, itemId) {
    const decision = new RezDecision("canRemoveItemFromSlot");
    decision.defaultYes();
    decision.setData("inventory_id", this.id);
    decision.setData("slot_id", slotBinding);
    decision.setData("item_id", itemId);
    return decision;
  }

  /**
   * @function addItemToSlot
   * @memberof RezInventory
   * @param {string} slotBinding
   * @param {string} itemId
   * @returns {RezDecision} the decision from canAddItemForSlot; when it is yes the
   * item has been inserted, otherwise the slot is unchanged and the decision carries
   * the reason and `failed_on` data.
   * @description Adds the given item to the given slot if `canAddItemForSlot` allows
   * it, notifying inventory, slot & item and applying effects. Callers may inspect
   * the returned decision; callers that ignore it simply get a no-op on refusal.
   * @example
   * const d = inv.addItemToSlot("weapon", "item_axe");
   * if(d.wasNo) showMessage(d.reason);
   */
  addItemToSlot(slotBinding, itemId) {
    const decision = this.canAddItemForSlot(slotBinding, itemId);
    if(decision.result) {
      this._insertItem(slotBinding, itemId);
    }
    return decision;
  }

  /**
   * @function _insertItem
   * @memberof RezInventory
   * @private
   * @param {string} slotBinding
   * @param {string} itemId
   * @description Low-level, unguarded insert. Appends the item, fires the insert
   * events on inventory, slot & item, and applies effects. Performs no acceptance
   * checks beyond requiring the item to define a `type`. Internal use only.
   */
  _insertItem(slotBinding, itemId) {
    const item = $(itemId);

    if(!item.hasAttribute("type")) {
      throw new Error(`Attempt to add ${itemId} to inventory, which does not define a 'type'!`);
    }

    this.getItemsForSlot(slotBinding).push(itemId);

    const ownerId = this.getAttributeValue("owner_id", null);
    const owner = ownerId ? this.owner : null;
    const slot = this.getSlot(slotBinding);

    this.runEvent("insert", { slot_id: slot.id, slot_binding: slotBinding, item_id: itemId, owner_id: ownerId, owner });
    slot.runEvent("insert", { inventory_id: this.id, item_id: itemId, owner_id: ownerId, owner });
    item.runEvent("insert", { inventory_id: this.id, slot_id: slot.id, slot_binding: slotBinding, owner_id: ownerId, owner });

    this.applyEffects(slotBinding, itemId);
  }

  /**
   * @function shouldApplyEffects
   * @memberof RezInventory
   * @param {string} slotBinding
   * @returns {boolean} whether effects should be applied for this slot
   */
  shouldApplyEffects(slotBinding) {
    if(this.owner) {
      if(this.apply_effects) {
        const slot = this.getSlot(slotBinding);
        return slot.apply_effects;
      }
      return false;
    }
    return false;
  }

  /**
   * @function applyEffects
   * @memberof RezInventory
   * @param {string} slotBinding
   * @param {string} itemId
   * @returns {boolean} whether the effect was applied
   */
  applyEffects(slotBinding, itemId) {
    if(!this.shouldApplyEffects(slotBinding)) {
      return false;
    }

    const item = $(itemId);
    if(!item.hasAttribute("effect_ids")) {
      return false;
    }

    for(const effectId of item.getAttributeValue("effect_ids")) {
      const effect = $t(effectId, "effect");
      effect.apply(this.owner_id, slotBinding, itemId);
    }

    return true;
  }

  /**
   * @function removeItemFromSlot
   * @memberof RezInventory
   * @param {string} slotBinding
   * @param {string} itemId
   * @returns {RezDecision} the decision from canRemoveItemFromSlot; when it is yes
   * the item has been removed (firing remove events and releasing effects), otherwise
   * the slot is unchanged and the decision carries the reason. An item that isn't in
   * the slot yields a `no` decision (`failed_on: "missing"`) rather than throwing.
   * @description removes the specified item from the specified inventory slot
   */
  removeItemFromSlot(slotBinding, itemId) {
    const decision = this.canRemoveItemFromSlot(slotBinding, itemId);

    if(!this.getItemsForSlot(slotBinding).includes(itemId)) {
      return decision
        .no(`No item |${itemId}| in slot binding |${slotBinding}| on inventory |${this.id}|!`)
        .setData("failed_on", "missing");
    }

    if(decision.result) {
      this._removeItem(slotBinding, itemId);
    }

    return decision;
  }

  /**
   * @function _removeItem
   * @memberof RezInventory
   * @private
   * @param {string} slotBinding
   * @param {string} itemId
   * @description Low-level, unguarded removal. Rewrites the slot contents without the
   * item, fires the remove events on slot, item & inventory, and removes effects.
   * Assumes the item is present. Internal use only.
   */
  _removeItem(slotBinding, itemId) {
    const contents = this.getItemsForSlot(slotBinding);
    this._writeSlotContents(slotBinding, contents.filter((id) => id !== itemId));

    const ownerId = this.getAttributeValue("owner_id", null);
    const owner = ownerId ? this.owner : null;

    const slot = this.getSlot(slotBinding);
    slot.runEvent("remove", { inventory_id: this.id, item_id: itemId, owner_id: ownerId, owner });

    const item = $(itemId);
    item.runEvent("remove", { inventory_id: this.id, slot_id: slotBinding, owner_id: ownerId, owner });

    this.runEvent("remove", { slot_id: slotBinding, item_id: itemId, owner_id: ownerId, owner });

    this.removeEffects(slotBinding, itemId);
  }

  /**
   * @function removeEffects
   * @memberof RezInventory
   * @param {string} slotBinding
   * @param {string} itemId
   */
  removeEffects(slotBinding, itemId) {
    if(!this.shouldApplyEffects(slotBinding)) {
      return false;
    }

    const item = $(itemId);
    if(!item.hasAttribute("effect_ids")) {
      return false;
    }

    for(const effectId of item.getAttributeValue("effect_ids")) {
      const effect = $t(effectId, "effect");
      effect.remove(this.owner_id, slotBinding, itemId);
    }
  }

  /**
   * @function clearSlot
   * @memberof RezInventory
   * @param {string} slotBinding
   * @description remove all items from the given slot, removing any effects granted by those items
   */
  clearSlot(slotBinding) {
    const items = this.getItemsForSlot(slotBinding);
    items.forEach((itemId) => {
      this.removeItemFromSlot(slotBinding, itemId);
    });
  }
}

window.Rez.RezInventory = RezInventory;
