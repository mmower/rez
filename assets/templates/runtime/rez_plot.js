//-----------------------------------------------------------------------------
// Plot
//-----------------------------------------------------------------------------

/**
 * @class RezPlot
 * @extends RezBasicObject
 * @description Tracks the progression of a storyline or quest through discrete stages.
 *
 * A plot represents a linear sequence of stages that the player advances through.
 * Each plot has a current stage and a total number of stages. When the current
 * stage equals the total stages, the plot is considered complete.
 *
 * Plots must be started before they can be advanced. Starting a plot makes it
 * active but keeps it at stage 0. Advancing moves through stages 1 to N.
 *
 * Plots fire events at key lifecycle points:
 * - "start" when the plot is started (becomes active)
 * - "advance" each time the stage increases (with `{stage}` param)
 * - "complete" when the final stage is reached
 *
 * Use plots for:
 * - Main story progression
 * - Side quests with multiple steps
 * - Tutorial sequences
 * - Achievement tracking
 *
 * @example
 * // Define in Rez
 * @plot main_quest {
 *   stages: 5
 *   on_start: (plot, evt) => {
 *     console.log("Quest begun!");
 *   }
 *   on_advance: (plot, evt) => {
 *     console.log(`Advanced to stage ${evt.stage}`);
 *   }
 * }
 *
 * @example
 * // Start and advance the plot at runtime
 * const quest = $("main_quest");
 * quest.start();  // Activates the plot, fires on_start
 * quest.advance(); // Moves to stage 1
 */
class RezPlot extends RezBasicObject {
  /**
   * Creates a new RezPlot.
   *
   * @param {string} id - Unique identifier for this plot
   * @param {Object} attributes - Initial attributes (should include `stage` and `stages`)
   */
  constructor(id, attributes) {
    super("plot", id, attributes);
  }

  /**
   * Whether this plot has reached its final stage.
   * @type {boolean}
   */
  get isComplete() {
    return this.stage == this.stages;
  }

  /**
   * Starts the plot, making it active.
   *
   * Sets the `active` attribute to true and fires the "start" event.
   * The plot remains at stage 0 until `advance()` is called.
   *
   * Does nothing if the plot is already active.
   *
   * @fires start - When the plot becomes active
   */
  start() {
    if(!this.active) {
      this.active = true;
      this.runEvent("start", {});
      this.notifySubscribers("plot_did_start");
    }
  }

  /**
   * Advances the plot to the next stage.
   *
   * Increments the `stage` attribute and fires appropriate events:
   * - "advance" with `{stage}` param on every advance
   * - "complete" when reaching the final stage
   *
   * Does nothing if the plot is not active or is already complete.
   *
   * @fires advance - On every advance, with `{stage}` param
   * @fires complete - When reaching the final stage
   */
  advance() {
    if(!this.active || this.isComplete) {
      return;
    }

    this.stage += 1;

    this.runEvent("advance", {stage: this.stage});
    this.notifySubscribers("plot_did_advance", {stage: this.stage});

    if(this.isComplete) {
      this.runEvent("complete", {});
      this.notifySubscribers("plot_did_complete");
    }
  }

  subscribe(subscriber_id) {
    if($(subscriber_id, false) === undefined) {
      throw new Error(`Attempt to subscribe to plot ${this.id} with invalid subscriber id: ${subscriber_id} must be game object id!`);
    }
    this.subscribers.push(subscriber_id);
  }

  unsubscribe(subscriber_id) {
    this.subscribers = this.subscribers.filter(sub_id => sub_id !== subscriber_id);
  }

  /**
   * Notify every subscriber to this plot about a plot related event.
   * Subscribers are notified in priority order (highest first, default 0).
   */
  notifySubscribers(event, params = {}) {
    this.subscribers
      .refs()
      .sort((a, b) => (b.priority ?? 0) - (a.priority ?? 0))
      .forEach((subscriber) => {
        subscriber.runEvent(event, {...params, plot_id: this.id});
      });
  }
}

window.Rez.RezPlot = RezPlot;
