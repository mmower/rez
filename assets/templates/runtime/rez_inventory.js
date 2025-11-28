//-----------------------------------------------------------------------------
// Inventory
//-----------------------------------------------------------------------------

class RezInventory extends RezBasicObject {
  constructor(id, attributes) {
    super("inventory", id, attributes);
  }

  /**
   * @function elementInitializer
   * @memberof RezInventory
   * @description called as part of the init process this creates the inital inventory slots
   */
  elementInitializer() {
    this.addInitialContents();
  }

  addInitialContents() {
    const slots = this.getAttributeValue("slots");
    for(const slotId of slots) {
      const slot = $t(slotId, "slot", true);
      const accessor = slot.getAttributeValue("accessor");
      const slotInitialContentsAttrName = `initial_${accessor}`;
      const initialContents = this.getAttributeValue(slotInitialContentsAttrName, []);
      for(const contentId of initialContents) {
        this.addItemToSlot(slotId, contentId);
      }
    }
  }

  /**
   * @function addItemHolderForSlot
   * @memberof RezInventory
   * @param {string} slot_id
   * @description add a new slot to the inventory
   */
  addSlot(slotId) {
    const slot = $t(slotId, "slot", true);
    const attrName = `${slot.accessor}_contents`;
    if(!this.hasAttribute(attrName)) {
      this.setAttribute(attrName, []);
      this.createStaticProperty(attrName);
    }
  }

  /**
   * @function getFirstItemForSlot
   * @memberof RezInventory
   * @param {string} slot_id
   * @returns {string} id of first item in the slot
   */
  getFirstItemForSlot(slotId) {
    return this.getItemsForSlot(slotId)[0];
  }

  /**
   * @function getItemsForSlot
   * @memberof RezInventory
   * @param {string} slot_id
   * @returns {array} contents of the specified slot
   */
  getItemsForSlot(slotId) {
    const slot = this.getSlot(slotId);
    return this.getAttribute(`${slot.accessor}_contents`);
  }

  /**
   * @function slotIsOccupied
   * @memberof RezInventory
   * @param {string} slot_id
   * @returns {boolean} true if there is at least one item in the slot
   */
  slotIsOccupied(slotId) {
    return this.countItemsForSlot(slotId) > 0;
  }

  /**
   * @function getSlot
   * @memberof RezInventory
   * @param {string} slot_id
   * @returns {object} reference to the slot with the given id or throws an Error
   * if the slot is either not defined, or not part of this inventory.
   */
  getSlot(slotId) {
    if(!this.getAttribute("slots").has(slotId)) {
      throw new Error(`Inventory |${this.id}| does not have slot |${slotId}|!`);
    } else {
      return $t(slotId, "slot", true);
    }
  }

  /**
   * @function setSlot
   * @memberof RezInventory
   * @param {string} slot_id
   * @param {array} items array of item id's
   */
  setSlot(slotId, itemIds) {
    const slot = this.getSlot(slotId);
    const attrName = `${slot.accessor}_contents`;
    this.setAttribute(attrName, itemIds);
  }

  /**
   * @function appendItemToSlot
   * @member RezInventory
   * @param {string} slot_id
   * @param {string} item_id
   * @description appends the given item to the given slot
   */
  appendItemToSlot(slotId, itemId) {
    this.getItemsForSlot(slotId).push(itemId);
  }

  /**
   * @function appendItemsToSlot
   * @memberof RezInventory
   * @param {string|array} item_or_items either an item_id or array of item_id's to append to the slot
   * @description add either a single item_id or an array of item_ids to the slot
   */
  appendToSlot(slotId, itemOrItems) {
    if(Array.isArray(itemOrItems)) {
      itemOrItems.forEach((itemid) => this.appendItemToSlot(slotId, itemid));
    } else {
      this.appendItemToSlot(slotId, itemOrItems);
    }
  }

  /**
   * @function setItemForSlot
   * @memberof RezInventory
   * @param {string} item_id
   * @description replaces any existing item content for the slot with this item
   */
  setItemForSlot(slotId, itemId) {
    this.setSlot(slotId, [itemId]);
  }

  /**
   * @function setItemsForSlot
   * @memberof RezInventory
   * @param {array} items array of item ids
   * @description replaces any existing item content for the slot with these items
   */
  setItemsForSlot(slotId, items) {
    this.setSlot(slotId, items);
  }

  /**
   * @function countItemsInSlot
   * @memberof RezInventory
   * @param {string} slot_id
   * @returns {integer} number of items in the given slot
   */
  countItemsInSlot(slotId) {
    return this.getItemsForSlot(slotId).length;
  }

  /**
   * @function slotContainsItem
   * @memberof RezInventory
   * @param {string} slot_id
   * @param {string} item_id
   * @returns {boolean} true if the item_id is in the slot
   */
  slotContainsItem(slotId, itemId) {
    return this.getItemsForSlot(slotId).some((anItemId) => itemId === anItemId);
  }

  /**
   * @function containsItem
   * @memberof RezInventory
   * @param {string} item_id
   * @returns {string|null} slot_id of the slot containing the item, or null if no slot contains it
   */
  containsItem(itemId) {
    for(const slotId of this.getAttribute("slots")) {
      if(this.slotContainsItem(slotId, itemId)) {
        return slotId;
      }
    }
    return undefined;
  }

  /**
   * @function itemFitsInSlot
   * @memberof RezInventory
   * @param {string} slot_id
   * @param {string} item_id
   * @returns {boolean} true if the item will fit with any other contents of the slot
   */
  itemFitsInSlot(slotId, itemId) {
    // TODO: this code looks like shit
    const slot = $(slotId);
    if(slot.has_capacity) {
      const used_capacity = this.getItemsForSlot(slotId).reduce((amount, itemId) => {
        const item = $(itemId);
        return amount + item.size;
      });

      return used_capacity + item.size <= slot.capacity;
    } else {
      return true;
    }
  }

  /**
   * @function slotAcceptsItem
   * @memberof RezInventory
   * @param {string} slot_id
   * @param {string} item_id
   * @returns {boolean} true if the given item has a type that this slot accepts
   */
  slotAcceptsItem(slotId, itemId) {
    const slot = this.getSlot(slotid);
    const accepts = slot.getAttributeValue("accepts");
    const item = $(itemId);
    const type = item.getAttributeValue("type");

    return type === accepts;
  }

  /**
   * @function canAddItemForSlot
   * @memberof RezInventory
   * @param {string} slot_id
   * @param {string} item_id
   * @returns {boolean} true if the slot accepts the item
   */
  canAddItemForSlot(slotId, itemId) {
    const decision = new RezDecision("canItemForSlot");

    if(!this.slotAcceptsItem(slotId, itemId)) {
      decision
        .no("slot doesn't take this kind of item")
        .setData("failed_on", "accepts");
    } else if(!this.itemFitsInSlot(slotId, itemId)) {
      decision.no("does not fit").setData("failed_on", "capacity");
    } else if(this.owner != null) {
      const actorDecision = this.owner.checkItem(this.id, slotId, itemId);
      if (actorDecision.result()) {
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
   * @param {string} slot_id
   * @param {string} item_id
   * @returns {object} RezDecision containing the result whether the item can be removed from the slot
   */
  canRemoveItemFromSlot(slotId, item_id) {
    // TODO: this code looks like shit
    const decision = new RezDecision("canRemoveItemFromSlot");
    decision.default_yes();

    const item = $(item_id);
    decision.setData("inventory_id", this.id);
    decision.setData("slot_id", slotId);
    item.canBeRemoved(item_decision);
    if(!item_decision.result) {
      return item_decision;
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
   * @param {string} slot_id
   * @param {string} item_id
   * @description adds the given item to the given slot, notifying inventory, slot & item and applying effects
   */
  addItemToSlot(slotId, itemId) {
    const item = $(itemId);

    // Anything can be added to an inventory provided it has an `type`
    // attribute to work with the slot accepts
    if(!item.hasAttribute("type")) {
      throw new Error(`Attempt to add ${itemId} to inventory, which does not define a 'type'!`);
    }

    this.appendItemToSlot(slotId, itemId);

    this.runEvent("insert", { slot_id: slotId, item_id: itemId });

    const slot = $t(slotId, "slot");
    slot.runEvent("insert", { inventory_id: this.id, item_id: itemId });

    item.runEvent("insert", { inventory_id: this.id, slot_id: slotId});

    this.applyEffects(slotId, itemId);
  }

  /**
   * Determine whether effects should be applied to this inventory and the specified slot.
   *
   * @function shouldApplyEffects
   * @memberof RezInventory
   * @param {string} slot_id
   */
  shouldApplyEffects(slotId) {
    // apply_effects is defined in Rez @slot
    if(this.owner) {
      if(this.apply_effects) {
        const slot = $t(slotId, "slot", true);
        return slot.apply_effects;
      } else {
        return false;
      }
    } else {
      // No owner object to apply the effect to
      return false;
    }
  }

  /**
   * @function applyEffects
   * @memberof RezInventory
   * @param {string} slot_id
   * @param {string} item_id
   * @returns {boolean} whether the effect was applied
   */
  applyEffects(slotId, itemId) {
    if(!this.shouldApplyEffects(slotId)) {
      return false;
    }

    const item = $(itemId);
    if (!item.hasAttribute("effects")) {
      // This item doesn't have any effects
      return false;
    }

    for (const effectId of item.effects) {
      const effect = $t(effectId, "effect");
      effect.apply(this.owner_id, slotId, itemId);
    }

    return true;
  }

  /**
   * @function removeItemForSlot
   * @memberof RezInventory
   * @param {string} slot_id
   * @param {string} item_id
   * @description removes the specified item from the specified inventory slot
   */
  removeItemFromSlot(slotId, itemId) {
    const contents = this.getItemsForSlot(slotId);
    if (!contents.includes(itemId)) {
      throw new Error(
        "Attempt to remove item |" +
        itemId +
        "| from slot |" +
        slotId +
        "| on inventory |" +
        this.id +
        "|. No such item found!"
      );
    }

    this.setItemsForSlot(slotId, contents.filter((id) => {
      return id != itemId;
    }));

    const slot = $(slotId);
    slot.runEvent("remove", { inventory: this.id, item: itemId });

    this.runEvent("remove", { slot: slotId, item: itemId });

    this.removeEffects(slotId, itemId);
  }

  /**
   * @function removeEffects
   * @memberof RezInventory
   * @param {string} slot_id
   * @param {string} item_id
   */
  removeEffects(slotId, itemId) {
    if(!this.shouldApplyEffects(slotId)) {
      return false;
    }

    const item = $(itemId);
    if (!item.hasAttribute("effects")) {
      return false;
    }

    for (const effectId of item.effects) {
      const effect = $t(effectId, "effect");
      effect.remove(this.owner_id, slotId, itemId);
    }
  }

  /**
   * @function clearSlot
   * @memberof RezInventory
   * @param {string} slot_id
   * @description remove all items from give slot, removes any effects granted by those items
   */
  clearSlot(slotId) {
    const items = this.getItemsForSlot(slotId);
    items.forEach((itemId) => this.removeItemFromSlot(slotId, itemId));
  }
}

window.Rez.RezInventory = RezInventory;
