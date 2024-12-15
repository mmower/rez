//-----------------------------------------------------------------------------
// Faction
//-----------------------------------------------------------------------------

class RezFaction extends RezBasicObject {
  constructor(id, attributes) {
    super("faction", id, attributes);
  }
}

window.Rez.RezFaction = RezFaction;
