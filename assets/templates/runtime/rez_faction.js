//-----------------------------------------------------------------------------
// Faction
//-----------------------------------------------------------------------------

/**
 * @class RezFaction
 * @extends RezBasicObject
 * @category Elements
 * @description Represents a faction or group affiliation in the Rez game engine.
 * Factions can be used to organize actors, track reputation, implement conflict systems,
 * or manage group-based game mechanics. Faction objects can have attributes like
 * reputation values, member lists, or faction-specific behaviors.
 */
class RezFaction extends RezBasicObject {
  /**
   * @function constructor
   * @memberof RezFaction
   * @param {string} id - unique identifier for this faction
   * @param {object} attributes - faction attributes from Rez compilation
   * @description Creates a new faction instance
   */
  constructor(id, attributes) {
    super("faction", id, attributes);
  }
}

window.Rez.RezFaction = RezFaction;
