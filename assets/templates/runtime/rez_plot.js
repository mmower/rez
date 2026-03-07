//-----------------------------------------------------------------------------
// Plot
//-----------------------------------------------------------------------------

/**
 * @class RezPlot
 * @extends RezBasicObject
 * @mixes HasSubscribers
 * @category Elements
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
 * **Define in Rez:**
 * <pre><code>
 * &#64;plot main_quest {
 *   stages: 5
 *   on_did_start: (plot, evt) => {
 *     console.log("Quest begun!");
 *   }
 *   on_did_advance: (plot, evt) => {
 *     console.log(`Advanced to stage ${evt.stage}`);
 *   }
 * }
 * </code></pre>
 *
 * @example <caption>Start the plot at runtime</caption>
 * const quest = $("main_quest");
 * // Activates the plot, fires on_start, sends on_plot_did_start to subscribers
 * quest.start();
 * // Moves to stage 1, fires on_advance, sends on_plot_did_advance to subscribers
 * quest.advance();
 * // Moves to stage 5, as with stage 1 but since the plot is now at stage 5 (complete)
 * // also fires on_complete, sends on_plot_did_complete to subscribers
 * quest.advance(4);
 */
class RezPlot extends RezBasicObject {
  /**
   * @function constructor
   * @memberof RezPlot
   * @description Creates a new RezPlot.
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
    return this.stage === this.stages;
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
   * Resets the plot clock to a previous stage.
   *
   * @param {number} n - stage to
   *
   * Fires revert on itself and `plot_did_revert` to subscribers.
   */
  revert(n = 0) {
    this.stage = max(0, Math.min(n, this.stages-1));
    this.runEvent("revert");
    this.notifySubscribers("plot_did_revert");
  }

  /**
   * Advances the plot to the next stage.
   *
   * @param {number} n - number of stages to advance (default :1)
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
  advance(n = 1) {
    if(!this.active || this.isComplete) {
      return;
    }

    this.stage = Math.min(this.stage + n, this.stages);

    this.runEvent("advance");
    this.notifySubscribers("plot_did_advance", this);

    if(this.isComplete) {
      this.runEvent("complete");
      this.notifySubscribers("plot_did_complete", this);
    }
  }
}

window.Rez.RezPlot = RezPlot;

/**
 * @class RezQuest
 * @extends RezBasicObject
 * @mixes HasSubscribers
 * @category Elements
 * @description Tracks the progression of a storyline or quest through discrete stages.
 */

class RezQuest extends RezBasicObject {
  /**
   * @function constructor
   * @memberof RezQuest
   * @description Creates a new RezQuest.
   *
   * @param {string} id - Unique identifier for this quest
   * @param {Object} attributes - Initial attributes
   */
  constructor(id, attributes) {
    super("quest", id, attributes);
  }

  /**
   * @function mentioned
   * @memberof RezQuest
   * @description Advances the quest state from unknown to mentioned
   * @fires quest_did_update
   */
  mentioned() {
    if(this.status === "unknown") {
      this.status = "mentioned";
      this.notifySubscribers("quest_did_update");
    }
  }

  /**
   * @function accepted
   * @memberof RezQuest
   * @description Advances the quest state from mentioned to accepted
   * @fires quest_did_update
   */
  accepted() {
    if(this.status === "mentioned") {
      this.status = "accepted";
      this.notifySubscribers("quest_did_update");
    }
  }

  /**
   * @function achieved
   * @memberof RezQuest
   * @description Advances the quest state from accepted to achieved
   * @fires quest_did_update
   */
  achieved() {
    if(this.status === "accepted") {
      this.status = "achieved";
      this.notifySubscribers("quest_did_update");
    }
  }

  /**
   * @function completed
   * @memberof RezQuest
   * @description Advances the quest state from achieved to completed
   * @fires quest_did_update
   */
  completed() {
    if(this.status === "achieved") {
      this.status = "completed";
      this.notifySubscribers("quest_did_update");
    }
  }

  /**
   * @function botched
   * @memberof RezQuest
   * @description Changes the quest state from mentioned|accepted|achieved to botched
   * @fires quest_did_update
   */
  botched() {
    if(["mentioned", "accepted", "achieved"].includes(this.status)) {
      this.setAttribute("old_status", this.status);
      this.status = "botched";
      this.notifySubscribers("quest_did_update");
    }
  }

  /**
   * @function unbotched
   * @memberof RezQuest
   * @description Returns the quest state from botched to its previous good state
   * @fires quest_did_update
   */
  unbotched() {
    if(this.status === "botched") {
      this.status = this.getAttribute("old_status");
      this.notifySubscribers("quest_did_update");
    }
  }
}

window.Rez.RezQuest = RezQuest;
