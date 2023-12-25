//-----------------------------------------------------------------------------
// Inventory
//-----------------------------------------------------------------------------

/*
 * A RezInventory is an object that holds RezItems in separate containers
 * designated by RezSlots.
 */

let inventory_proto = {
  __proto__: basic_object,

  addItemHolderForSlot(slot_id) {
    this.items[slot_id] = [];
  },

  elementInitializer() {
    for (const slot_id of this.slots) {
      this.addItemHolderForSlot(slot_id);
    }
  },

  slotIsOccupied(slot_id) {
    return this.countItemsForSlot(slot_id) > 0;
  },

  getItemForSlot(slot_id) {
    return this.getItemsForSlot(slot_id)[0];
  },

  getItemsForSlot(slot_id) {
    const items = this.items[slot_id];
    if(typeof(items) === "undefined") {
      throw `Attempt to get unknown slot "${slot_id} from container ${this.id}!`;
    }
    return items;
  },

  appendItemToSlot(slot_id, item_id) {
    this.items[slot_id].push(item_id);
  },

  setItemForSlot(slot_id, item_id) {
    this.items[slot_id] = [item_id];
  },

  setItemsForSlot(slot_id, items) {
    this.items[slot_id] = items;
  },

  countItemsInSlot(slot_id) {
    return this.getItemsForSlot(slot_id).length;
  },

  /*
   * Determines whether the specified item is contained in any slot in this inventory.
   *
   * Either returns the slot_id that contains the item, or null.
   */
  containsItem(item_id) {
    for (const slot_id in this.items) {
      const items = this.getItemsForSlot(slot_id);
      if (
        items.some((contained_item_id) => {
          return contained_item_id == item_id;
        })
      ) {
        return slot_id;
      }
    }
    return null;
  },

  isOwned() {
    return this.hasAttribute("owner");
  },

  ownerId() {
    return this.getAttributeValue("owner");
  },

  owner() {
    return $(this.ownerId());
  },

  itemFitsInSlot(slot_id, item_id) {
    const slot = $(slot_id);
    const capacity = slot.capacity();
    const item = $(item_id);
    const size = item.size();
    const current_size = this.countItemsInSlot(slot_id);

    return current_size + size <= capacity;
  },

  slotAcceptsItem(slot_id, item_id) {
    const slot = $(slot_id);
    const accepts = slot.getAttributeValue("accepts");
    const item = $(item_id);
    const type = item.getAttributeValue("type");

    return type == accepts;
  },

  canAddItemForSlot(slot_id, item_id) {
    const decision = new RezDecision("canItemForSlot");

    if (!this.slotAcceptsItem(slot_id, item_id)) {
      decision
        .no("slot doesn't take this kind of item")
        .setData("failed_on", "accepts");
    } else if (!this.itemFitsInSlot(slot_id, item_id)) {
      decision.no("does not fit").setData("failed_on", "fits");
    } else if (this.isOwned()) {
      const actor_decision = this.owner().checkItem(this.id, slot_id, item_id);
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

  addItemToSlot(slot_id, item_id) {
    this.appendContentToSlot(slot_id, item_id);

    this.runEvent("insert", { slot_id: slot_id, item_id: item_id });

    const slot = $(slot_id);
    slot.runEvent("insert", { inventory_id: this.id, item_id: item_id });

    this.applyEffects(item_id);
  },

  applyEffects(item_id) {
    if (!this.getAttributeValue("apply_effects", false)) {
      return;
    }

    const item = this.game.$(item_id);
    if (!item.hasAttribute("effects")) {
      return;
    }

    if (!this.hasAttribute("owner")) {
      return;
    }

    const effects = item.getAttributeValue("effects");
    const owner = this.getAttributeValue("owner");

    for (const effect_id of effects) {
      owner.applyEffect(effect_id, item_id);
    }
  },

  removeItemFromSlot(slot_id, item_id) {
    const contents = this.getContentsForSlot(slot_id);
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

    const remaining_contents = contents.filter((id) => {
      return id != item_id;
    });
    this.setContentsForSlot(slot_id, new_contents);

    const slot = this.game.$(slot_id);
    slot.runEvent("remove", { inventory: this.id, item: item_id });
    this.runEvent("remove", { slot: slot_id, item: item_id });

    this.removeEffects(item_id);
  },

  removeEffects(item_id) {
    if (!this.getAttributeValue("apply_effects", false)) {
      return;
    }

    const item = this.game.$(item_id);
    if (!item.hasAttribute("effects")) {
      return;
    }

    if (!this.hasAttribute("owner")) {
      return;
    }

    const effects = item.getAttributeValue("effects");
    const owner = this.getAttributeValue("owner");

    for (const effect_id of effects) {
      owner.removeEffect(effect_id, item_id);
    }
  },
};

function RezInventory(id, attributes) {
  this.id = id;
  this.game_object_type = "inventory";
  this.items = {};
  this.attributes = attributes;
  this.properties_to_archive = ["items"];
  this.changed_attributes = [];
}

RezInventory.prototype = inventory_proto;
RezInventory.prototype.constructor = RezInventory;
window.Rez.Inventory = RezInventory;
