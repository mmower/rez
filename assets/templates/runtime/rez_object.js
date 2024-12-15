//-----------------------------------------------------------------------------
// Object
//
// The RezObject is a way for authors to define their own types of object
// that don't belong to one of the provided functionalities (e.g. actors,
// items, and the like). An author can define a RezObject and put whatever
// data they like into it and make use of it from their own scripted functions
// or behaviours.
//-----------------------------------------------------------------------------

class RezObject extends RezBasicObject {
  constructor(id, attributes) {
    super("object", id, attributes)
  }
}

window.Rez.RezObject = RezObject;
