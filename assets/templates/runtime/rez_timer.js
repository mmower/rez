/**
 * @class RezTimer
 * @extends RezBasicObject
 * @category Elements
 * @description Represents a timer in the Rez game engine. Timers can be configured to run once or repeatedly,
 * with optional count-down functionality. When triggered, they dispatch timer events through the game's event processor.
 */
class RezTimer extends RezBasicObject {
  #timer;

  /**
   * @function constructor
   * @memberof RezTimer
   * @param {string} id - unique identifier for this timer
   * @param {object} attributes - timer attributes from Rez compilation
   * @description Creates a new timer instance with the specified configuration
   */
  constructor(id, attributes) {
    super("timer", id, attributes);
  }

  /**
   * @function running
   * @memberof RezTimer
   * @returns {boolean} true if the timer is currently active
   * @description Indicates whether the timer is currently running and will trigger events
   */
  get running() {
    return this.#timer != null;
  }

  /**
   * @function start
   * @memberof RezTimer
   * @description Starts the timer using either setInterval (for repeating timers) or setTimeout (for one-shot timers).
   * The timer will trigger the notify method when it fires.
   */
  start() {
    const timerHandler = this.notify.bind(this);
    if(this.repeats) {
      this.#timer = setInterval(timerHandler, this.interval);
    } else {
      this.#timer = setTimeout(timerHandler, this.interval);
    }
  }

  /**
   * @function dec_counter
   * @memberof RezTimer
   * @description Decrements the timer's count attribute if present. When count reaches zero,
   * the timer automatically stops itself.
   */
  dec_counter() {
    if(this.hasAttribute("count")) {
      let count = this.getAttribute("count") - 1;
      if(count === 0) {
        this.stop();
      }
      this.setAttribute("count", count);
    }
  }

  /**
   * @function notify
   * @memberof RezTimer
   * @description Called when the timer fires. Decrements the count (if present) and dispatches a timer event
   * through the game's event processor.
   */
  notify() {
    this.dec_counter();
    const eventProcessor = this.game.eventProcessor;
    eventProcessor.dispatchResponse(eventProcessor.raiseTimerEvent(this));
  }

  /**
   * @function stop
   * @memberof RezTimer
   * @description Stops the timer by clearing the timeout/interval and resetting the internal timer reference
   */
  stop() {
    clearTimeout(this.#timer);
    this.#timer = null;
  }
}

window.Rez.RezTimer = RezTimer;
