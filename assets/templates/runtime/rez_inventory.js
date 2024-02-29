//-----------------------------------------------------------------------------
// Inventory
//-----------------------------------------------------------------------------

/**
 * Creates a new RezInventory
 * @class
 * @param {string} id assigned id
 * @param {object} attributes initial attributes
 * @description constructs @inventory game-objects
 */
function RezInventory(id, attributes) {
  this.id = id;
  this.game_object_type = "inventory";
  this.attributes = attributes;
  this.properties_to_archive = [];
  this.changed_attributes = [];
}

RezInventory.prototype = {
  __proto__: basic_object,
  constructor: RezInventory,

  /**
   * @function addItemHolderForSlot
   * @memberof RezInventory
   * @param {string} slot_id
   * @description adds an empty array to hold items for the given slot.
   */
  addSlot(slot_id) {
    const items = this.getAttribute("items");
    items[slot_id] = [];

    Object.defineProperty(this, `${slot_id}_contents`, {
      get: function () {
        return this.getAttribute("items")[slot_id];
      },
    });
  },

  /**
   * @function elementInitializer
   * @memberof RezInventory
   * @description called as part of the init process this creates the inital inventory slots
   */
  elementInitializer() {
    const slots = this.getAttribute("slots");
    for (const slot_id of slots) {
      this.addSlot(slot_id);
    }

    const initial_contents = this.getAttribute("initial_contents");
    if(typeof(initial_contents) === "object") {
      for(const [slot_id, contents] of Object.entries(initial_contents)) {
        for(const item_id of contents) {
          this.addItemToSlot(slot_id, item_id);
        }
      }
    }
  },

  /**
   * @function getItemsForSlot
   * @memberof RezInventory
   * @param {string} slot_id
   * @returns {array} contents of the specified slot
   */
  getItemsForSlot(slot_id) {
    this.validateSlot(slot_id);
    return this.getAttribute("items")[slot_id];
  },

  /**
   * @function slotIsOccupied
   * @memberof RezInventory
   * @param {string} slot_id
   * @returns {boolean} true if there is at least one item in the slot
   */
  slotIsOccupied(slot_id) {
    return this.countItemsForSlot(slot_id) > 0;
  },

  /**
   * @function getItemForSlot
   * @memberof RezInventory
   * @param {string} slot_id
   * @returns {string} id of first item in the slot
   */
  getItemForSlot(slot_id) {
    return this.getItemsForSlot(slot_id)[0];
  },

  /**
   * @function validateSlot
   * @memberof RezInventory
   * @param {string} slot_id
   * @returns {boolean} true if the given slot_id is part of this inventory
   */
  validateSlot(slot_id) {
    if(!this.getAttribute("slots").has(slot_id)) {
      throw `Inventory |${this.id}| does not have slot |${slot_id}|!`;
    };
  },

  /**
   * @function setSlot
   * @memberof RezInventory
   * @param {string} slot_id
   * @param {array} items array of item id's
   */
  setSlot(slot_id, item_ids) {
    this.validateSlot(slot_id);
    const items = this.getAttribute("items");
    items[slot_id] = item_ids;
  },

  /**
   * @function appendItemToSlot
   * @member RezInventory
   * @param {string} slot_id
   * @param {string} item_id
   * @description appends the given item to the given slot
   */
  appendItemToSlot(slot_id, item_id) {
    this.getItemsForSlot(slot_id).push(item_id);
  },

  /**
   * @function appendItemsToSlot
   * @memberof RezInventory
   * @param {string|array} item_or_items either an item_id or array of item_id's to append to the slot
   * @description add either a single item_id or an array of item_ids to the slot
   */
  appendToSlot(slot_id, item_or_items) {
    if(typeof(item_or_items) === "string") {
      this.appendItemToSlot(slot_id, item_or_items);
    } else if(typeof(item_or_items) === "array") {
      item_or_items.forEach((item_id) => this.appendItemToSlot(slot_id, item_id));
    }
  },

  /**
   * @function setItemForSlot
   * @memberof RezInventory
   * @param {string} item_id
   * @description replaces any existing item content for the slot with this item
   */
  setItemForSlot(slot_id, item_id) {
    this.setSlot(slot_id, [item_id]);
  },

  /**
   * @function setItemsForSlot
   * @memberof RezInventory
   * @param {array} items array of item ids
   * @description replaces any existing item content for the slot with these items
   */
  setItemsForSlot(slot_id, items) {
    this.setSlot(slot_id, items);
  },

  /**
   * @function countItemsInSlot
   * @memberof RezInventory
   * @param {string} slot_id
   * @returns {integer} number of items in the given slot
   */
  countItemsInSlot(slot_id) {
    return this.getItemsForSlot(slot_id).length;
  },

  /**
   * @function slotContainsItem
   * @memberof RezInventory
   * @param {string} slot_id
   * @param {string} item_id
   * @returns {boolean} true if the item_id is in the slot
   */
  slotContainsItem(slot_id, item_id) {
    return this.getItemsForSlot(slot_id).some((an_item_id) => item_id === an_item_id);
  },

  /**
   * @function containsItem
   * @memberof RezInventory
   * @param {string} item_id
   * @returns {string|null} slot_id of the slot containing the item, or null if no slot contains it
   */
  containsItem(item_id) {
    for(const slot_id of this.getAttribute("slots")) {
      if(this.slotContainsItem(slot_id, item_id)) {
        return slot_id;
      }
    }
    return null;
  },

  /**
   * @function itemFitsInSlot
   * @memberof RezInventory
   * @param {string} slot_id
   * @param {string} item_id
   * @returns {boolean} true if the item will fit with any other contents of the slot
   */
  itemFitsInSlot(slot_id, item_id) {
    const slot = $(slot_id);
    if(slot.has_capacity) {
      const used_capacity = this.getItemsForSlot(slot_id).reduce((amount, item_id) => {
        const item = $(item_id);
        return amount + item.size;
      });

      return used_capacity + item.size <= slot.capacity;
    } else {
      return true;
    }
  },

  /**
   * @function slotAcceptsItem
   * @memberof RezInventory
   * @param {string} slot_id
   * @param {string} item_id
   * @returns {boolean} true if the given item has a type that this slot accepts
   */
  slotAcceptsItem(slot_id, item_id) {
    this.validateSlot(slot_id);

    const slot = $(slot_id);
    const accepts = slot.getAttributeValue("accepts");
    const item = $(item_id);
    const type = item.getAttributeValue("type");

    return type === accepts;
  },

  /**
   * @function canAddItemForSlot
   * @memberof RezInventory
   * @param {string} slot_id
   * @param {string} item_id
   * @returns {boolean} true if the slot accepts the item
   */
  canAddItemForSlot(slot_id, item_id) {
    const decision = new RezDecision("canItemForSlot");

    if (!this.slotAcceptsItem(slot_id, item_id)) {
      decision
        .no("slot doesn't take this kind of item")
        .setData("failed_on", "accepts");
    } else if (!this.itemFitsInSlot(slot_id, item_id)) {
      decision.no("does not fit").setData("failed_on", "capacity");
    } else if (this.owner != null) {
      const actor_decision = this.owner.checkItem(this.id, slot_id, item_id);
      if (actor_decision.result()) {
        decision.yes();
      } else {
        decision.no(actor_decision.reason()).setData("failed_on", "actor");
      }
    } else {
      decision.yes();
    }

    return decision;
  },

  /**
   * @function canRemoveItemFromSlot
   * @memberof RezInventory
   * @param {string} slot_id
   * @param {string} item_id
   * @returns {object} RezDecision containing the result whether the item can be removed from the slot
   */
  canRemoveItemFromSlot(slot_id, item_id) {
    const decision = new RezDecision("canRemoveItemFromSlot");
    decision.default_yes();

    const item = $(item);
    decision.setData("inventory_id", this.id);
    decision.setData("slot_id", slot_id);
    item.canBeRemoved(item_decision);
    if(!item_decision.result) {
      return item_decision;
    }

    if(this.owner == null) {
      return decision;
    }

    this.owner.canRemoveItem(decision);
    return decision;
  },

  /**
   * @function addItemToSlot
   * @memberof RezInventory
   * @param {string} slot_id
   * @param {string} item_id
   * @description adds the given item to the given slot, notifying inventory, slot & item and applying effects
   */
  addItemToSlot(slot_id, item_id) {
    const item = $t(item_id, "item");

    this.appendItemToSlot(slot_id, item_id);

    this.runEvent("insert", { slot_id: slot_id, item_id: item_id });

    const slot = $(slot_id);
    slot.runEvent("insert", { inventory_id: this.id, item_id: item_id });

    item.runEvent("insert", { inventory_id: this.id, slot_id: slot_id});

    this.applyEffects(slot_id, item_id);
  },

  /**
   * Determine whether effects should be applied to this inventory and the specified slot.
   *
   * @function shouldApplyEffects
   * @memberof RezInventory
   * @param {string} slot_id
   */
  shouldApplyEffects(slot_id) {
    if (this.owner) {
      if (this.apply_effects) {
        const slot = $(slot_id);
        return slot.apply_effects;
      } else {
        return false;
      }
    } else {
      // No owner object to apply the effect to
      return false;
    }
  },

  /**
   * @function applyEffects
   * @memberof RezInventory
   * @param {string} slot_id
   * @param {string} item_id
   * @returns {boolean} whether the effect was applied
   */
  applyEffects(slot_id, item_id) {
    if(!this.shouldApplyEffects(slot_id)) {
      return false;
    }

    const item = $(item_id);
    if (!item.hasAttribute("effects")) {
      // This item doesn't have any effects
      return false;
    }

    for (const effect_id of item.effects) {
      const effect = $t(effect_id, "effect");
      effect.apply(this.owner_id, slot_id, item_id);
    }

    return true;
  },

  /**
   * @function removeItemForSlot
   * @memberof RezInventory
   * @param {string} slot_id
   * @param {string} item_id
   * @description removes the specified item from the specified inventory slot
   */
  removeItemFromSlot(slot_id, item_id) {
    const contents = this.getItemsForSlot(slot_id);
    if (!contents.includes(item_id)) {
      throw (
        "Attempt to remove item |" +
        item_id +
        "| from slot |" +
        slot_id +
        "| on inventory |" +
        this.id +
        "|. No such item found!"
      );
    }

    this.setItemsForSlot(slot_id, contents.filter((id) => {
      return id != item_id;
    }));

    const slot = $(slot_id);
    slot.runEvent("remove", { inventory: this.id, item: item_id });

    this.runEvent("remove", { slot: slot_id, item: item_id });

    this.removeEffects(slot_id, item_id);
  },

  /**
   * @function removeEffects
   * @memberof RezInventory
   * @param {string} slot_id
   * @param {string} item_id
   */
  removeEffects(slot_id, item_id) {
    if(!this.shouldApplyEffects(slot_id)) {
      return false;
    }

    const item = $(item_id);
    if (!item.hasAttribute("effects")) {
      return false;
    }

    for (const effect_id of item.effects) {
      const effect = $t(effect_id, "effect");
      effect.remove(this.owner_id, slot_id, item_id);
    }
  },

  /**
   * @function clearSlot
   * @memberof RezInventory
   * @param {string} slot_id
   * @description remove all items from give slot, removes any effects granted by those items
   */
  clearSlot(slot_id) {
    const items = this.getItemsForSlot(slot_id);
    items.forEach((item_id) => this.removeItemFromSlot(slot_id, item_id));
  }
};

window.RezInventory = RezInventory;
