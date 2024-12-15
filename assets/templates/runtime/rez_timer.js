class RezTimer extends RezBasicObject {
  #timer;

  constructor(id, attributes) {
    super("timer", id, attributes);
  }

  run() {
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
    const event_processor = this.game.event_processor;
    event_processor.dispatchResponse(event_processor.raiseTimerEvent(this));
  }

  stop() {
    clearTimeout(this.timer);
    this.timer = null;
  }
}

window.Rez.RezTimer = RezTimer;
