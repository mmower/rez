//-----------------------------------------------------------------------------
// Effect
//-----------------------------------------------------------------------------

class RezEffect extends RezBasicObject {
  constructor(id, attributes) {
    super("effect", id, attributes);
  }

  apply(ownerId, slotId, itemId) {
    return this.runEvent("apply", {owner_id: ownerId, slot_id: slotId, item_id: itemId});
  }

  remove(ownerId, slotId, itemId) {
    return this.runEvent("remove", {owner_id: ownerId, slot_id: slotId, item_id: itemId});
  }
}

window.Rez.RezEffect = RezEffect;
