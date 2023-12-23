//-----------------------------------------------------------------------------
// Inventory
//-----------------------------------------------------------------------------

/*
 * A RezInventory is an object that holds RezItems in separate containers
 * designated by RezSlots.
 */

let inventory_proto = {
  __proto__: basic_object,

  addContentHolderForSlot(slot_id) {
    this.contents[slot_id] = [];
  },

  elementInitializer() {
    for (const slot_id of this.slots) {
      this.addContentHolderForSlot(slot_id);
    }
  },

  slotIsOccupied(slot_id) {
    return this.getContentsForSlot(slot_id).length == 0;
  },

  getContentsForSlot(slot_id) {
    const contents = this.contents[slot_id];
    if(typeof(contents) === "undefined") {
      throw `Attempt to get unknown slot "${slot_id} from container ${this.id}!`;
    }
    return contents;
  },

  appendContentToSlot(slot_id, item_id) {
    this.contents[slot_id].push(item_id);
  },

  setContentsForSlot(slot_id, contents) {
    this.contents[slot_id] = contents;
  },

  countItemsInSlot(slot_id) {
    return this.getContentsForSlot(slot_id).length;
  },

  /*
   * Determines whether the specified item is contained in any slot in this inventory.
   *
   * Either returns the slot_id that contains the item, or null.
   */
  containsItem(item_id) {
    for (const slot_id in this.contents) {
      const contents = this.getContentsForSlot(slot_id);
      if (
        contents.some((contained_item_id) => {
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
    return this.game.$(this.ownerId());
  },

  itemFitsInSlot(slot_id, item_id) {
    const capacity = this.game.$(slot_id).capacity();
    const size = this.game.$(item_id).size();
    const current_size = this.countItemsInSlot(slot_id);

    return current_size + size <= capacity;
  },

  slotAcceptsItem(slot_id, item_id) {
    const accepts = this.game.$(slot_id).getAttributeValue("accepts");
    const type = this.game.$(item_id).getAttributeValue("type");

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

    const slot = this.game.$(slot_id);
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
  this.contents = {};
  this.attributes = attributes;
  this.properties_to_archive = ["contents"];
  this.changed_attributes = [];
}

RezInventory.prototype = inventory_proto;
RezInventory.prototype.constructor = RezInventory;
window.Rez.Inventory = RezInventory;
