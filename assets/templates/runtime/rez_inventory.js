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
    this.addInitialContents();
  }

  addInitialContents() {
    for(const {prefix} of this.getAttributeValue("slots")) {
      const initialContents = this.getAttributeValue(`initial_${prefix}`, []);
      for(const contentId of initialContents) {
        this.addItemToSlot(prefix, contentId);
      }
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
   * @function getSlot
   * @memberof RezInventory
   * @param {string} slotBinding - the binding prefix identifying the slot position
   * @returns {object} reference to the slot element for this binding, or throws
   * if the binding does not exist in this inventory.
   */
  getSlot(slotBinding) {
    const binding = this.getAttributeValue("slots").find(b => b.prefix === slotBinding);
    if(!binding) {
      throw new Error(`Inventory |${this.id}| does not have slot binding |${slotBinding}|!`);
    }
    return $t(binding.source, "slot", true);
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
   * @function setSlot
   * @memberof RezInventory
   * @param {string} slotBinding
   * @param {array} itemIds array of item id's
   */
  setSlot(slotBinding, itemIds) {
    this.getSlot(slotBinding); // validates binding exists
    this.setAttribute(`${slotBinding}_contents`, itemIds);
  }

  /**
   * @function appendItemToSlot
   * @memberof RezInventory
   * @param {string} slotBinding
   * @param {string} itemId
   * @description appends the given item to the given slot
   */
  appendItemToSlot(slotBinding, itemId) {
    this.getItemsForSlot(slotBinding).push(itemId);
  }

  /**
   * @function appendToSlot
   * @memberof RezInventory
   * @param {string} slotBinding
   * @param {string|array} itemOrItems either an item_id or array of item_id's to append to the slot
   * @description add either a single item_id or an array of item_ids to the slot
   */
  appendToSlot(slotBinding, itemOrItems) {
    if(Array.isArray(itemOrItems)) {
      itemOrItems.forEach((itemId) => {
        this.appendItemToSlot(slotBinding, itemId);
      });
    } else {
      this.appendItemToSlot(slotBinding, itemOrItems);
    }
  }

  /**
   * @function setItemForSlot
   * @memberof RezInventory
   * @param {string} slotBinding
   * @param {string} itemId
   * @description replaces any existing item content for the slot with this item
   */
  setItemForSlot(slotBinding, itemId) {
    this.setSlot(slotBinding, [itemId]);
  }

  /**
   * @function setItemsForSlot
   * @memberof RezInventory
   * @param {string} slotBinding
   * @param {array} items array of item ids
   * @description replaces any existing item content for the slot with these items
   */
  setItemsForSlot(slotBinding, items) {
    this.setSlot(slotBinding, items);
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
    for(const {prefix} of this.getAttributeValue("slots")) {
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
   */
  itemFitsInSlot(slotBinding, itemId) {
    const item = $(itemId);
    const itemSize = item.getAttributeValue("size", 0);
    if(itemSize === 0) return true;

    const slot = this.getSlot(slotBinding);
    if(slot.has_capacity) {
      const minSize = slot.getAttributeValue("min_size", 1);
      if(itemSize < minSize) return false;
      const usedCapacity = this.getItemsForSlot(slotBinding).reduce((amount, id) => {
        return amount + $(id).getAttributeValue("size", 0);
      }, 0);
      return usedCapacity + itemSize <= slot.capacity;
    }
    return true;
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

    if(!this.slotAcceptsItem(slotBinding, itemId)) {
      decision
        .no("slot doesn't take this kind of item")
        .setData("failed_on", "accepts");
    } else if(!this.itemFitsInSlot(slotBinding, itemId)) {
      decision.no("does not fit").setData("failed_on", "capacity");
    } else if(this.owner != null) {
      const actorDecision = this.owner.checkItem(this.id, slotBinding, itemId);
      if(actorDecision.result) {
        decision.yes();
      } else {
        decision.no(actorDecision.reason()).setData("failed_on", "actor");
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
   * @returns {RezDecision} decision object with result
   */
  canRemoveItemFromSlot(slotBinding, itemId) {
    const decision = new RezDecision("canRemoveItemFromSlot");
    decision.defaultYes();

    const item = $(itemId);
    decision.setData("inventory_id", this.id);
    decision.setData("slot_id", slotBinding);
    item.canBeRemoved(decision);
    if(!decision.result) {
      return decision;
    }

    if(this.owner == null) {
      return decision;
    }

    this.owner.canRemoveItem(decision);
    return decision;
  }

  /**
   * @function addItemToSlot
   * @memberof RezInventory
   * @param {string} slotBinding
   * @param {string} itemId
   * @description adds the given item to the given slot, notifying inventory, slot & item and applying effects
   */
  addItemToSlot(slotBinding, itemId) {
    const item = $(itemId);

    if(!item.hasAttribute("type")) {
      throw new Error(`Attempt to add ${itemId} to inventory, which does not define a 'type'!`);
    }

    this.appendItemToSlot(slotBinding, itemId);

    this.runEvent("insert", { slot_id: slotBinding, item_id: itemId });

    const slot = this.getSlot(slotBinding);
    slot.runEvent("insert", { inventory_id: this.id, item_id: itemId });

    item.runEvent("insert", { inventory_id: this.id, slot_id: slotBinding });

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
    if(!item.hasAttribute("effects")) {
      return false;
    }

    for(const effectId of item.effects) {
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
   * @description removes the specified item from the specified inventory slot
   */
  removeItemFromSlot(slotBinding, itemId) {
    const contents = this.getItemsForSlot(slotBinding);
    if(!contents.includes(itemId)) {
      throw new Error(
        "Attempt to remove item |" +
        itemId +
        "| from slot binding |" +
        slotBinding +
        "| on inventory |" +
        this.id +
        "|. No such item found!"
      );
    }

    this.setItemsForSlot(slotBinding, contents.filter((id) => id !== itemId));

    const slot = this.getSlot(slotBinding);
    slot.runEvent("remove", { inventory_id: this.id, item_id: itemId });

    const item = $(itemId);
    item.runEvent("remove", { inventory_id: this.id, slot_id: slotBinding });

    this.runEvent("remove", { slot_id: slotBinding, item_id: itemId });

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
    if(!item.hasAttribute("effects")) {
      return false;
    }

    for(const effectId of item.effects) {
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
