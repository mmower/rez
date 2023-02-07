//-----------------------------------------------------------------------------
// Die
//-----------------------------------------------------------------------------

let die_proto = {
  between: function(min, max) {
    return Math.floor(min + Math.random() * (max - min + 1));
  },

  die() {
    return this.between(1, this.sides);
  },

  rollOnce() {
    let sum = this.modifier;
    for(let i = 0; i<this.count; i++) {
      sum += this.die();
    }
    return sum;
  },

  cl_avg(sum) {
    const f = Math.random() < 0.5 ? Math.ceil : Math.floor;
    return f(sum/this.rounds);
  },

  roll() {
    let sum = 0;
    for(let i = 0; i<this.rounds; i++) {
      sum += this.rollOnce();
    }
    return this.cl_avg(sum);
  }
};

function RezDie(count = 1, sides = 6, modifier = 0, rounds = 1) {
  this.count = count;
  this.sides = sides;
  this.modifier = modifier;
  this.rounds = rounds;
}

RezDie.prototype = die_proto;
RezDie.prototype.constructor = RezDie;
window.Rez.Die = RezDie;
