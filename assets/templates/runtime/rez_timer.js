function RezTimer(id, attributes) {
  this.id = id;
  this.timer = null;
  this.game_object_type = "timer";
  this.attributes = attributes;
  this.properties_to_archive = [];
  this.changed_attributes = [];
}

RezTimer.prototype = {
  __proto__: basic_object,
  constructor: RezTimer,

  run() {
    const timerHandler = this.notify.bind(this);
    if(this.repeats) {
      this.timer = setInterval(timerHandler, this.interval);
    } else {
      this.timer = setTimeout(timerHandler, this.interval);
    }
  },

  dec_counter() {
    if(this.hasAttribute("count")) {
      let count = this.getAttribute("count") - 1;
      if(count === 0) {
        this.stop();
      }
      this.setAttribute("count", count);
    }
  },

  notify() {
    this.dec_counter();
    const event_processor = this.game.event_processor;
    event_processor.dispatchResponse(event_processor.raiseTimerEvent(this));
  },

  stop() {
    clearTimeout(this.timer);
    this.timer = null;
  }
};

window.Rez.RezTimer = RezTimer;
