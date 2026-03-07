// This file exists solely to provide JSDoc documentation for Rez stdlib mixins.
// These mixins are defined in stdlib.rez.eex and applied to game objects at runtime.
// They do not correspond to actual JS classes or objects in this file.

/**
 * @mixin HasSubscribers
 * @description Adds subscriber management to a game element. Applied automatically
 * to `@plot` and `@quest` elements via the `$has_subscribers` Rez stdlib mixin.
 *
 * Subscribers are other game objects that receive event notifications when the
 * element fires lifecycle events. Subscribers are notified in descending priority
 * order (highest `priority` attribute first; default priority is 0).
 *
 * @example <caption>Subscribe an actor to a plot</caption>
 * const plot = $("main_quest");
 * const actor = $("player");
 * plot.subscribe(actor);
 *
 * // The actor's on_plot_did_advance handler will now be called when
 * // the plot fires plot_did_advance.
 * plot.advance();
 *
 * // Later, stop receiving notifications
 * plot.unsubscribe(actor);
 */

/**
 * @function subscribe
 * @memberof HasSubscribers

 * @param {string|Object} refOrId - A game object reference or element ID to add as a subscriber
 * @description Adds a game object as a subscriber. The object will receive event
 * notifications when {@link HasSubscribers#notifySubscribers} is called.
 * Throws if `refOrId` cannot be resolved to a known game object ID.
 */

/**
 * @function unsubscribe
 * @memberof HasSubscribers

 * @param {string|Object} refOrId - A game object reference or element ID to remove
 * @description Removes a previously added subscriber. Has no effect if the object
 * is not currently subscribed.
 * Throws if `refOrId` cannot be resolved to a known game object ID.
 */

/**
 * @function notifySubscribers
 * @memberof HasSubscribers

 * @param {string} event - The event name to fire on each subscriber
 * @param {Object} [params={}] - Additional parameters passed to the event handler.
 *   A `source` key is automatically added pointing to the notifying element.
 * @description Fires the named event on every current subscriber, sorted by
 * descending `priority` attribute (highest first, default 0).
 */
