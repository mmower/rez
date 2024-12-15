//-----------------------------------------------------------------------------
// Relationship
//-----------------------------------------------------------------------------

class RezRelationship extends RezBasicObject {
  constructor(id, attributes) {
    super("relationship", id, attributes);
  }

  // The @relationship element will define source_id and target_id
  // attributes, leading to source & target being defined automatically

  get inverse() {
    return this.game.getRelationship(this.target_id, this.source_id);
  }
}

window.Rez.RezRelationship = RezRelationship;
