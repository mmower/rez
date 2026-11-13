// Tests for assets/templates/runtime/rez_roll.js
// Run with: npm run test:js

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";

const src = readFileSync(
  new URL("../../assets/templates/runtime/rez_roll.js", import.meta.url),
  "utf8"
);

const ctx = vm.createContext({ window: { Rez: {} } });
vm.runInContext(
  "Math.rand_int_between = (a, b) => a + Math.floor(Math.random() * (b - a + 1));",
  ctx
);
vm.runInContext(src, ctx);
const RezRoll = ctx.window.Rez.RezRoll;

// Values from the vm context belong to another realm, so normalise them before deep comparisons
const plain = (x) => JSON.parse(JSON.stringify(x));

// Returns a dieFn that hands out the given values in order
function scripted(...values) {
  let i = 0;
  return () => {
    if(i >= values.length) throw new Error("scripted dice exhausted");
    return values[i++];
  };
}

function withDice(roll, ...values) {
  roll.dieFn = scripted(...values);
  return roll;
}

test("keepHighest / keepLowest", () => {
  const hi = withDice(new RezRoll(3, 6, RezRoll.keepHighest(2)), 2, 6, 5);
  hi.roll();
  assert.deepEqual(plain(hi.final), [5, 6]);

  const lo = withDice(new RezRoll(3, 6, RezRoll.keepLowest(2)), 2, 6, 5);
  lo.roll();
  assert.deepEqual(plain(lo.final), [2, 5]);
});

test("a single transformer is wrapped in an array", () => {
  const r = new RezRoll(2, 6, RezRoll.sum());
  assert.equal(r.transformers.length, 1);
});

test("sum with modifier and beats vs meets", () => {
  const beats = withDice(new RezRoll(2, 6, RezRoll.sum(2), RezRoll.beats(8)), 3, 3);
  assert.equal(beats.roll(), false); // 8 > 8 is false
  assert.equal(beats.final, 8);

  const meets = withDice(new RezRoll(2, 6, RezRoll.sum(2), RezRoll.meets(8)), 3, 3);
  assert.equal(meets.roll(), true);
});

test("default evaluator returns the final value", () => {
  const r = withDice(new RezRoll(2, 6, RezRoll.sum()), 4, 5);
  assert.equal(r.roll(), 9);
});

test("rolls records every stage", () => {
  const r = withDice(new RezRoll(3, 6, [RezRoll.keepHighest(2), RezRoll.sum()]), 1, 4, 6);
  r.roll();
  assert.deepEqual(plain(r.rolls), [[1, 4, 6], [4, 6], 10]);
  assert.deepEqual(plain(r.dice), [1, 4, 6]);
});

test("twoD6 crits on kept double 6 and double 1", () => {
  assert.equal(withDice(RezRoll.twoD6({target: 20}), 6, 6).roll(), "crit_success");
  assert.equal(withDice(RezRoll.twoD6({bonus: 10, target: 2}), 1, 1).roll(), "crit_failure");
});

test("twoD6 advantage keeps the best 2, disadvantage the worst 2", () => {
  const adv = withDice(RezRoll.twoD6({mode: "advantage", target: 8}), 1, 6, 6);
  assert.equal(adv.roll(), "crit_success");

  const dis = withDice(RezRoll.twoD6({mode: "disadvantage", target: 8}), 1, 6, 6);
  assert.equal(dis.roll(), "failure"); // kept [1, 6] = 7
  assert.equal(dis.flags.critical, undefined);
});

test("twoD6 bonus and op", () => {
  assert.equal(withDice(RezRoll.twoD6({bonus: 2, target: 8}), 3, 4).roll(), "success"); // 9 > 8
  assert.equal(withDice(RezRoll.twoD6({bonus: 1, target: 8}), 3, 4).roll(), "failure"); // 8 > 8 false
  assert.equal(withDice(RezRoll.twoD6({bonus: 1, target: 8, op: ">="}), 3, 4).roll(), "success");
});

test("twoD6 rejects an unknown mode", () => {
  assert.throws(() => RezRoll.twoD6({mode: "sideways"}), /unknown mode/);
});

test("d20 meets the DC with bonus", () => {
  const r = withDice(RezRoll.d20({bonus: 3, dc: 15}), 12);
  assert.equal(r.number, 1);
  assert.equal(r.sides, 20);
  assert.equal(r.roll(), "success"); // 15 >= 15
  assert.equal(r.final, 15);
  assert.equal(withDice(RezRoll.d20({bonus: 3, dc: 15}), 11).roll(), "failure");
  assert.equal(withDice(RezRoll.d20(), 10).roll(), "success"); // default DC 10
});

test("d20 natural 20 and 1 are crits regardless of total", () => {
  assert.equal(withDice(RezRoll.d20({bonus: -10, dc: 30}), 20).roll(), "crit_success");
  assert.equal(withDice(RezRoll.d20({bonus: 20, dc: 5}), 1).roll(), "crit_failure");
});

test("d20 crits can be turned off", () => {
  assert.equal(withDice(RezRoll.d20({dc: 25, crits: false}), 20).roll(), "failure");
  assert.equal(withDice(RezRoll.d20({bonus: 5, dc: 5, crits: false}), 1).roll(), "success");
});

test("d20 advantage keeps the higher die, disadvantage the lower", () => {
  const adv = withDice(RezRoll.d20({mode: "advantage", dc: 12}), 4, 13);
  assert.equal(adv.number, 2);
  assert.equal(adv.roll(), "success");
  assert.deepEqual(plain(adv.rolls[1]), [13]);

  const dis = withDice(RezRoll.d20({mode: "disadvantage", dc: 12}), 4, 13);
  assert.equal(dis.roll(), "failure");
  assert.equal(dis.final, 4);

  assert.equal(withDice(RezRoll.d20({mode: "advantage"}), 1, 20).roll(), "crit_success");
  assert.equal(withDice(RezRoll.d20({mode: "disadvantage", bonus: 20}), 1, 20).roll(), "crit_failure");
});

test("d20 recompute after setting the die", () => {
  const r = withDice(RezRoll.d20({bonus: 2, dc: 15}), 5);
  assert.equal(r.roll(), "failure");
  r.setDie(0, 20, "inspiration");
  assert.equal(r.recompute(), "crit_success");
});

test("d20 rejects an unknown mode", () => {
  assert.throws(() => RezRoll.d20({mode: "sideways"}), /unknown mode/);
});

test("explode chains and supports an offset", () => {
  const r = withDice(new RezRoll(2, 6, RezRoll.explode()), 6, 3, 6, 2);
  r.roll();
  // dice [6, 3]; die 0 explodes: 6 then 2 -> 6 + 6 + 2
  assert.deepEqual(plain(r.final), [14, 3]);

  const coe = withDice(new RezRoll(1, 6, RezRoll.explode({extraOffset: -1})), 6, 6, 3);
  coe.roll();
  assert.equal(coe.final[0], 6 + 5 + 2);

  const once = withDice(new RezRoll(1, 6, RezRoll.explode({chain: false})), 6, 6);
  once.roll();
  assert.equal(once.final[0], 12);
});

test("recompute after an edit replays explosion dice", () => {
  const r = withDice(new RezRoll(3, 6, [RezRoll.explode(), RezRoll.sum()]), 6, 1, 6, 4, 5);
  r.roll();
  // dice [6, 1, 6]; die 0 explodes into 4, die 2 into 5 -> 10 + 1 + 11
  assert.equal(r.result, 22);

  // Editing die 0 removes its explosion; die 2 must keep its 5, not take die 0's 4
  r.setDie(0, 5, "luck");
  assert.equal(r.recompute(), 5 + 1 + 11);

  // Restoring the 6 brings back the same explosion die; no new dice are rolled
  r.setDie(0, 6);
  assert.equal(r.recompute(), 22);
});

test("unkeyed extra dice are replayed in call order", () => {
  const extra = (roll, dice) => [...dice, roll.die()];
  const r = withDice(new RezRoll(1, 6, [extra, RezRoll.sum()]), 2, 5);
  assert.equal(r.roll(), 7);
  assert.equal(r.recompute(), 7); // scripted dice would throw if it rolled again
});

test("editing a dropped die changes which dice are kept", () => {
  const r = withDice(RezRoll.twoD6({mode: "advantage", target: 8}), 1, 3, 4);
  assert.equal(r.roll(), "failure"); // kept [3, 4] = 7
  r.setDie(0, 6, "spent fate");
  assert.equal(r.recompute(), "success"); // kept [4, 6] = 10
  assert.deepEqual(plain(r.rolls[1]), [4, 6]);
});

test("edits are logged and cleared by a new roll", () => {
  const r = withDice(new RezRoll(2, 6, RezRoll.sum()), 1, 6, 4, 2, 3);
  r.roll();
  r.setDie(0, 6, "luck");
  r.adjustDie(1, 3, "skill"); // 6 + 3 clamps to 6
  r.rerollDie(0, "push");     // takes the next scripted die, 4
  assert.deepEqual(plain(r.edits), [
    {action: "set", index: 0, from: 1, to: 6, reason: "luck"},
    {action: "adjust", index: 1, from: 6, to: 6, reason: "skill"},
    {action: "reroll", index: 0, from: 6, to: 4, reason: "push"}
  ]);
  assert.equal(r.recompute(), 10);

  r.roll();
  assert.deepEqual(plain(r.edits), []);
  assert.deepEqual(plain(r.dice), [2, 3]);
});

test("adjustDie clamps to 1", () => {
  const r = withDice(new RezRoll(1, 6), 2);
  r.roll();
  r.adjustDie(0, -5);
  assert.equal(r.dice[0], 1);
});

test("edits reject bad indices and unrolled dice", () => {
  const r = new RezRoll(2, 6);
  assert.throws(() => r.setDie(0, 6), /no dice/);
  r.dieFn = scripted(1, 2);
  r.roll();
  assert.throws(() => r.setDie(2, 6), /no die at index 2/);
});

test("transform resets stages and flags", () => {
  const r = withDice(RezRoll.twoD6({target: 8}), 6, 6);
  r.roll();
  assert.equal(r.flags.critical, "success");
  r.setDie(1, 5);
  assert.equal(r.recompute(), "success");
  assert.equal(r.flags.critical, undefined);
  assert.equal(r.rolls.length, 3); // dice, critOnAll, sum
});

test("transform before initialRoll throws", () => {
  assert.throws(() => new RezRoll(2, 6).transform(), /initialRoll/);
});

test("transformers cannot mutate the raw dice", () => {
  const mutate = (roll, dice) => { dice[0] = 99; return dice; };
  const r = withDice(new RezRoll(1, 6, mutate), 3);
  r.roll();
  assert.equal(r.dice[0], 3);
  assert.equal(r.final[0], 99);
});

test("blades outcome bands", () => {
  assert.equal(withDice(RezRoll.blades(3), 6, 2, 6).roll(), "critical");
  assert.equal(withDice(RezRoll.blades(3), 6, 2, 1).roll(), "success");
  assert.equal(withDice(RezRoll.blades(2), 5, 2).roll(), "partial");
  assert.equal(withDice(RezRoll.blades(2), 3, 2).roll(), "failure");
});

test("blades zero pool rolls 2 and takes the lowest, never critical", () => {
  const r = withDice(RezRoll.blades(0), 6, 6);
  assert.equal(r.number, 2);
  assert.equal(r.roll(), "success");
  assert.equal(withDice(RezRoll.blades(0), 6, 4).roll(), "partial");
});

test("countSuccesses", () => {
  const r = withDice(
    new RezRoll(5, 6, RezRoll.countSuccesses({successOn: 5, failOn: 1, mod: 1})),
    5, 6, 1, 3, 1
  );
  r.roll();
  assert.deepEqual(plain(r.final), {successes: 2, failures: 2, net: 1});

  const defaults = withDice(new RezRoll(3, 6, RezRoll.countSuccesses()), 6, 5, 6);
  defaults.roll();
  assert.deepEqual(plain(defaults.final), {successes: 2, failures: 0, net: 2});
});

test("countIf and highest", () => {
  const c = withDice(new RezRoll(4, 6, RezRoll.countIf((d) => d % 2 === 0)), 2, 3, 4, 6);
  assert.equal(c.roll(), 3);
  const h = withDice(new RezRoll(3, 6, RezRoll.highest()), 2, 5, 3);
  assert.equal(h.roll(), 5);
});

test("custom outcome rules see the roll", () => {
  const r = withDice(
    new RezRoll(2, 6, RezRoll.sum(), RezRoll.outcome([
      ["doubles", (f, roll) => roll.dice[0] === roll.dice[1]],
      ["other", () => true]
    ])),
    3, 3
  );
  assert.equal(r.roll(), "doubles");
  assert.equal(RezRoll.outcome([["never", () => false]])(1, r), null);
});

test("default dieFn uses Math.rand_int_between within range", () => {
  const r = new RezRoll(50, 6);
  r.roll();
  assert.ok(r.dice.every((d) => d >= 1 && d <= 6));
});
