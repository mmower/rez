//-----------------------------------------------------------------------------
// Dice
//-----------------------------------------------------------------------------

const die_proto = {
  roll() {
    return Number.rand_between(1, this.sides);
  },
};

function RezDie(sides = 6) {
  this.sides = sides;
}

RezDie.prototype = die_proto;
RezDie.prototype.constructor = RezDie;
window.Rez.Die = RezDie;

window.Rez.D4 = new RezDie(4);
window.Rez.D6 = new RezDie(6);
window.Rez.D8 = new RezDie(8);
window.Rez.D10 = new RezDie(10);
window.Rez.D12 = new RezDie(12);
window.Rez.D20 = new RezDie(20);
window.Rez.D100 = new RezDie(100);

const die_roll_proto = {
  rollRound() {
    let sum = this.modifier;
    for (let i = 0; i < this.count; i++) {
      sum += this.die.roll();
    }
    return sum;
  },

  roll() {
    if (this.rounds == 1) {
      return this.rollRound();
    } else {
      const sum = Number.range(1, this.rounds)
        .map(() => this.rollRound())
        .reduce((sum, round) => sum + round, 0);
      return sum.cl_avg(this.rounds);
    }
  },
};

function RezDieRoll(die, count, modifier, rounds = 1) {
  this.die = die;
  this.count = count;
  this.modifier = modifier;
  this.rounds = rounds;
}

RezDieRoll.prototype = die_roll_proto;
RezDieRoll.prototype.constructor = RezDieRoll;
window.Rez.DieRoll = RezDieRoll;
