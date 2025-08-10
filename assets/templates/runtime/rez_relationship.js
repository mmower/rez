//-----------------------------------------------------------------------------
// Relationship
//-----------------------------------------------------------------------------

/**
 * @class RezRelationship
 * @extends RezBasicObject
 * @description Represents a relationship between two game objects in the Rez game engine.
 * Relationships are directional (source -> target) and can have attributes like strength,
 * type, or other relationship-specific data. Each relationship automatically gets
 * source_id and target_id attributes that reference the related objects.
 */
class RezRelationship extends RezBasicObject {
  /**
   * @function constructor
   * @memberof RezRelationship
   * @param {string} id - unique identifier for this relationship (typically "rel_sourceId_targetId")
   * @param {object} attributes - relationship attributes including source_id and target_id
   * @description Creates a new relationship instance between two game objects
   */
  constructor(id, attributes) {
    super("relationship", id, attributes);
  }

  // The @relationship element will define source_id and target_id
  // attributes, leading to source & target being defined automatically

  /**
   * @function inverse
   * @memberof RezRelationship
   * @returns {RezRelationship|null} the inverse relationship (target -> source) or null if it doesn't exist
   * @description Gets the inverse relationship where the target and source are swapped.
   * Since relationships are directional, the inverse represents the relationship in the opposite direction.
   */
  get inverse() {
    return this.game.getRelationship(this.target_id, this.source_id);
  }
}

window.Rez.RezRelationship = RezRelationship;
