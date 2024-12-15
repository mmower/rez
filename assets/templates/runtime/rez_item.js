//-----------------------------------------------------------------------------
// Item
//-----------------------------------------------------------------------------

class RezItem extends RezBasicObject {
  constructor(id, attributes) {
    super("item", id, attributes);
  }
}

window.Rez.RezItem = RezItem;
