"use strict";

/**
 * JSDoc plugin that removes inherited members from subclass documentation.
 * Base class members are still documented on the base class itself.
 * Subclass pages show the "Extends" link to navigate to the base class.
 */
exports.handlers = {
  processingComplete(e) {
    // Must splice in-place — reassigning e.doclets doesn't affect the underlying array
    // that gets wrapped in TaffyDB and passed to the template.
    let i = e.doclets.length;
    while (i--) {
      if (e.doclets[i].inherited) {
        e.doclets.splice(i, 1);
      }
    }
  }
};
