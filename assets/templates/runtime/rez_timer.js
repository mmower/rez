class RezTimer extends RezBasicObject {
  #timer;

  constructor(id, attributes) {
    super("timer", id, attributes);
  }

  get running() {
    return this.#timer != null;
  }

  start() {
    const timerHandler = this.notify.bind(this);
    if(this.repeats) {
      this.#timer = setInterval(timerHandler, this.interval);
    } else {
      this.#timer = setTimeout(timerHandler, this.interval);
    }
  }

  dec_counter() {
    if(this.hasAttribute("count")) {
      let count = this.getAttribute("count") - 1;
      if(count === 0) {
        this.stop();
      }
      this.setAttribute("count", count);
    }
  }

  notify() {
    this.dec_counter();
    const eventProcessor = this.game.eventProcessor;
    eventProcessor.dispatchResponse(eventProcessor.raiseTimerEvent(this));
  }

  stop() {
    clearTimeout(this.#timer);
    this.#timer = null;
  }
}

window.Rez.RezTimer = RezTimer;
