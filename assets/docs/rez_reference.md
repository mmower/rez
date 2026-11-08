# Rez Compact Reference

A terse reference to the Rez language for AI assistants and authors who want
rules rather than a tutorial. Print one topic with `rez docs <topic>`; list
them with `rez docs topics`. For the exact attributes an element accepts run
`rez schema <element>` (add your game source, `rez schema src/game.rez <elem>`,
to include your own `@elem`/`@schema`/`@defaults`).

## overview
Project layout, commands, and the authortime/runtime split.

Rez compiles `.rez` source (authortime) into a single-page HTML game whose
elements become JavaScript objects (runtime). `@card` → `RezCard`, `@actor` →
`RezActor`, etc. All game logic is JavaScript embedded in attributes.

Project created by `rez new <name> --author-name=".." --author-email=".." --game-title=".."`:

```
<name>/
  src/<name>.rez   main source; includes the stdlib with %(../lib/stdlib.rez)
  lib/stdlib.rez   regenerated on every compile — never edit it
  assets/          images, audio, js, css (referenced by @asset)
  dist/            compiled game (index.html + assets/js/runtime.js)
```

Commands (run from the game folder, or pass `--wdir <dir>`):

- `rez compile src/<name>.rez` — build into `dist/`.
- `rez lint src/<name>.rez` — run every compiler check, write no game files.
  Exit status 0 = no errors. Use this after every edit.
- `rez schema [src/<name>.rez] [element]` — list elements with schemas, or the
  attributes, types, defaults and rules of one element.
- `rez docs [topic]` — this reference.

Source structure:

- `%(path/file.rez)` includes another file (path relative to the including
  file). A file may only be included once.
- `%%` starts a comment to end of line. `//` is NOT a Rez comment (it is only
  valid inside JavaScript bodies).
- Order of elements in the source does not matter. `@defaults` apply to every
  element of that type wherever it is defined; several `@defaults` for the
  same type merge.

## syntax
Element and attribute syntax, ids.

```
@card c_intro {          %% element: @<type> <id> { attributes }
  title: "Intro"         %% attribute: name, colon, at least one space, value
  content: ```
  <p>Hello</p>
  ```
}

@game { ... }            %% the one @game has no id; it is always #game
```

- Ids follow JS identifier rules (`[A-Za-z_$][A-Za-z0-9_$]*`), are
  case-sensitive and unique across the game. Common prefixes: `c_` cards,
  `sc_` scenes, `T_` templates.
- Attribute names are snake_case. At runtime they are accessed by the same
  name: `card.visit_count`. Methods of the runtime API are camelCase
  (`getAttributeValue`, `playCardWithId`).
- Attributes beginning `$` are system attributes (`$global`, `$template`, …).
  Ids beginning `$` and `_` are reserved for the stdlib.
- Attributes ending `_id` hold an element ref; the runtime also creates the
  attribute without the suffix holding the object: `location_id: #forest` gives
  `actor.location` (assigning either keeps both in sync).
- An element may have attributes not in its schema (except `@contains`).
  Schema rules validate type/required/etc. for the attributes they mention.
- Nested elements: `@contains` blocks go inside `@inventory`; elements can also
  be written inline as attribute values only where documented.

## values
Every attribute value type and its literal syntax.

| Type | Syntax | Notes |
|---|---|---|
| boolean | `true` `false` `yes` `no` | |
| number | `42` `-3` `2.5` | |
| string | `"text"` | `\n` `\t` `\"` escapes; may span lines |
| keyword | `:sword` | a string at runtime; also a constant `$kSword` (`:big_goblin` → `$kBigGoblin`) |
| element ref | `#player` | id string at runtime |
| element name | `@item` | refers to all elements of that type/alias (e.g. in `$init_after`) |
| list | `[1 2 3]` `[#a, #b]` | space or `, ` separated, mixed types allowed |
| set | `#{:a :b}` | unordered, unique |
| merge set | `+#{:c}` | merges with the set from `@defaults` instead of replacing it |
| table | `{hp: 10 name: "Orc"}` | attributes, whitespace separated. On element attribute `stats:` it becomes a separate `@object` `<owner>_stats` and the owner gets `stats_id`/`stats`; a list of tables becomes `<owner>_stats_0`, `_1`… |
| template | ` ```...``` ` | HTML + template syntax (see `templates`) |
| event handler | `(obj, evt) => {...}` | arrow function; receiver is first param. The body must be in braces: `(s) => s.x` does not parse, write `(s) => { return s.x; }` |
| method | `function(a) {...}` | `this` is the element |
| append handler | `+(obj, evt) => {...}` | chains after the handler from defaults/mixins |
| dynamic property | `^p{ return this.a + 1; }` | recomputed on every read; `this` is the element |
| dynamic initializer | `^i{ return Math.rand_int(10); }` | computed once at init; `^i:3{...}` sets priority 1–10 (1 first, default 10) |
| copy initializer | `^c:#T_sword` | copies a `$template` element at init, assigns the copy's id (use on `_id` attributes). `^c:2:#T_sword` priority. `^c:#T_sword{copy.name = "X";}` customises the copy (params `copy`, `owner`; no space before `{`) |
| delegate | `^d:spell_book` | reads the same-named attribute from the object in `spell_book_id` |
| die roll | `^r:2d6+3` | a `RezDie`; `.roll()` at runtime |
| initializer roll | `^ir:2d6` | rolled once at init to a number |
| probability table | `\|:common 60 :rare 10\|` | weighted choice |
| behaviour tree | `^[$select [cond] [action opt=1]]` | see `behaviours` |
| const ref | `$MAX_HP` | value of `@const MAX_HP = 100` |
| placeholder | `_` | declares the attribute with no value yet (creates an accessor) |
| file contents | `<<<file.txt>>>` | inlines a file from the source folder |

System attributes (any element):

- `$global: true` — available as `$<id>` in JS and as `<id>` in every template
  binding. Use sparingly (player, a few hubs). Id must be a valid JS identifier.
- `$template: true` — not initialised itself; used as a source for copies
  (`^c:`, `addCopy()`, `@generator`). Copies get `$template: false` and
  `$original_id`.
- `$init_after: [#other @item]` — initialise after these elements/types.
- `$js_ctor: "MyCard"` — construct with a custom JS class (extend the Rez one).
- `$mixins: #{#mixin_id}` — runtime mixins (see `directives`).
- `$no_archive: #{:scratch}` — attributes left out of saved games.
- `$debug_bindings: true` (card) — breaks into the debugger while binding.

## elements
The built-in elements: purpose, key attributes, handlers.

Every element accepts `tags: #{:kw ...}` and `on_init: (obj, evt) => {}`
(runs during game initialisation). Run `rez schema <element>` for the full
attribute list with types and defaults.

**@game** (no id; it is `#game`; `$game` in JS). Required: `name`, `title`,
`author`, `IFID`, `archive_format` (number), `initial_scene_id: #scene`.
`layout: ```...${content}...```` must contain `${content}`. Optional
`bindings`, `blocks`, `links`/`scripts` (URL lists), `start_events`. Handlers:
`on_game_will_start`, `on_game_did_start`, `on_scene_will_start`,
`on_scene_did_end`, `on_scene_will_pause`, `on_scene_did_resume`,
`on_card_will_start`, `on_card_did_start`, `on_card_did_finish` (evt has
`card_id`, `params`), `on_will_render`, `on_did_render`, `on_will_save`,
`on_did_load`.

**@scene** — a context with its own layout that plays cards. Required
`initial_card_id: #card`. `layout` (default `${content}`), `layout_mode:
:single|:stack`, `layout_reverse`, `layout_separator`, `bindings`, `blocks`,
`resume_event: function(params) { return RezEvent.render(); }` (what happens
when an interlude returns). Handlers: `on_start`, `on_ready`, `on_finish`,
`on_interrupt`, `on_resume`, `on_card_will_start`, `on_card_did_start`,
`on_card_did_finish`, `on_will_render`, `on_did_render`. `layout_id:
#layout` imports a shared `@layout` (see `directives`).

**@card** — content the player sees. Required `content: ```...````. `back`
(face shown after the card finishes in a `:stack` scene), `title`,
`bindings`, `blocks`, `css_class`, `$suppress_wrapper`. Handlers:
`on_will_start` (before render; evt = params it was played with),
`on_did_start` (after render), `on_finish`, `on_will_render`,
`on_did_render`, plus `on_<custom_event>`.

**@actor** — a character. `container_id: #inventory`, `initial_location`,
`behaviours: ^[...]`. Handlers: `on_accept_item` (evt has `decision`,
`inventory_id`, `slot_id`, `position`, `item_id`; call
`evt.decision.no("why")` to refuse), `on_enter`/`on_leave` (evt has
`location_id`, after `actor.moveTo(id)`).

**@object** — a blank element for anything else (classes, perks, door state).
Usually combined with `@elem` and `@defaults`.

**@item** (alias of `@object`). `type: :keyword` (default `:item`) must be
accepted by some `@slot` (honouring `@derive`); a game with items needs at
least one slot. `size` (default 1), `weight`, `uses`, `effect_ids:
[#effect]`, `asset_id`. Runtime-only: `inventory_id`, `position`. Handlers
`on_insert`, `on_remove`.

**@slot** — a kind of place. Required `accepts: :type`. `name`,
`has_capacity` + `capacity` (sum of item sizes per position),
`apply_effects` (default true), `excludes: #{#other_slot}`. Handlers
`on_insert`, `on_remove`.

**@inventory** — a container of named positions:

```
@inventory player_inv {
  max_weight: 20
  @contains left_hand { slot_id: #ring_slot }
  @contains backpack {
    slot_id: #backpack_slot
    contents: [#rope #lantern]
    enabled: true
  }
}
```

At least one `@contains`; it accepts only `slot_id` (required), `contents`,
`enabled`. Position names are local (not `#ids`), unique, not starting `_`.
Optional `owner_id` (default: the actor whose `container_id` names it),
`apply_effects`, `max_weight`. Handlers `on_insert`, `on_remove`,
`on_positions_changed`. Insert order: inventory → slot → item; remove:
slot → item → inventory. Event: `{inventory_id, slot_id, position,
item_id, owner_id, owner}`. Runtime API in `runtime`.

**@effect** — `on_apply`/`on_remove: (effect, evt)` with `evt.owner_id`,
`item_id`, `inventory_id`, `slot_id`, `position`. Applied when an item with
the effect enters a position whose slot and inventory have `apply_effects`
and the inventory has an owner.

**@asset** — a media file copied to `dist/`. Exactly one of `file_name:
"x.png"` (searched for anywhere under `assets/`) or `file_path:
"images/x.png"` (relative to `assets/`). `width`+`height` together. JS/CSS
assets: `$js_runtime: true` (bundled into runtime.js), `$pre_runtime: true`,
`$js_defer: true`. Display with `<.img name="asset_id" />`, which needs
`width`/`height` on the asset or the tag. `asset.$dist_path` is the file's
path in the built game.

**@group** — asset collection resolved at compile time into a `RezList`
with the group's id whose `values` are the matching asset ids. Required
`type: :image|:audio|:video`. Optional `include_tags` (asset has any of
them) and `exclude_tags` (asset has none of them); both may be combined.
Matching no assets is a compile error. Select with the `@list` methods,
e.g. `$("hats").randomFromBag()`.
```
@group hats {
  type: :image
  include_tags: #{:hat}
  exclude_tags: #{:red}
}
```

**@list** — `values: [...]`, `includes: [#other_list]`. Runtime random
selection: `randomElement()`, `randomFromBag()`, `nextForCycle()`,
`randomWithoutStarvation()`, `randomWalk()`.

**@generator** — becomes a `RezList` with the generator's id whose values
are the ids of copies of a template, made at runtime. Required
`source_id`; `copies` (number, roll or function); `customize: (copy, idx)`
must return the copy.
```
@generator goblins {
  source_id: #T_goblin
  copies: 5
  customize: (goblin, idx) => { goblin.name = `Goblin ${idx + 1}`; return goblin; }
}
```

**@plot** — progress clock. Required `stages` (≥1). `priority`, `stage`,
`active`. `start()`, `advance(n)`, `revert(n)`, `isComplete`. Handlers
`on_start`, `on_advance`, `on_complete`; subscribers (`subscribe(id)`) get
`on_plot_did_start|advance|complete|revert` with `evt.source`.

**@quest** — required `description`. `status` ∈ `:unknown :mentioned
:accepted :achieved :completed :botched`; `mention() accept() achieve()
complete() botch() unbotch()`. Subscribers get `on_quest_did_update`.

**@faction** — `member_ids`; `members` gives objects.

**@rel** — relationship, special syntax, id `rel_<source>_<target>`:

```
@rel #player -> #gutman { affinity: -1.0 }
```

`$game.getRelationship("player", "gutman")`, `rel.inverse`.

**@timer** — required `interval` (ms) and `event: :name` (handled like a
custom event). `auto_start` (default true), `repeats` (default true),
`count`. `start()`, `stop()`.

**@system** — runs around every player event. Required `enabled`,
`priority` (higher runs first) and at least one of `before_event: (system,
evt) => {}`, `after_event: (system, evt, result) => { return result; }`,
`before_lifecycle_event: (system, name, params)`, `after_lifecycle_event:
(system, name, params, result)`.

**@behaviour** — behaviour-tree node. See `behaviours`.

## directives
Directives that define types, defaults, shared layouts, code and styles.

```
@elem npc = actor                %% new element type; may chain (@elem boss = npc)
@defaults npc { hostile: false } %% defaults for every @npc (works for built-ins too)
@npc guard { name: "Guard" }     %% obj.kindOf("npc") / kindOf("actor") are true

@derive :sword :weapon           %% keyword type hierarchy (items/slots/tags)
@derive :weapon :item

@const MAX_HP = 100              %% $MAX_HP in attributes and JS

@schema npc {                    %% compile-time validation (see `rez docs schema`)
  rank: {kind: :number, required: true, min: 1}
}

@mixin named {                   %% runtime-shared methods and ^p properties only
  full_name: ^p{ return `${this.first} ${this.last}`; }
}
@actor sam { $mixins: #{#named} first: "Sam" last: "Spade" }

@component badge (bindings, assigns, content) => {
  return `<span class="tag">${content}</span>`;
}

@filter SHOUT_FILTER {           %% template filter: ${x | shout}
  name: "shout"
  impl: (s) => { return s.toUpperCase(); }
}

@patch {                         %% extend a JS built-in; method: or function:
  patch: "Number"
  method: "double"
  impl: function() { return this * 2; }
}

@script {                        %% raw JS added to the page
  function rollDie(n) { return Math.rand_int_between(1, n); }
}

@styles {                        %% raw CSS (NOT @stylesheet)
  .card { margin: 1em; }
}

@keybinding ctrl+shift+C :show_sheet   %% key → custom event (shift needs upper-case key)

@behaviour_template order_whisky ^[$sequence [at_bar] [say msg="Whisky."]]

@pragma(after_process_ast) write_id_map("ids.txt")
```

- `@defaults` for an alias apply only to elements created with that alias.
- A `@mixin` contributes only functions and `^p{}` properties; plain values
  in a mixin are ignored. Prefer `@elem` + `@defaults` for data.
- `@component` assigns come from tag attributes: `<.badge n=3 label="x"
  hp={player.hp}>`. `{js}` / `${js}` values are evaluated with the bindings;
  `"..."` strings containing `${...}` are evaluated as JS template literals.
- `@pragma` timings: `after_build_schema`, `after_schema_apply`,
  `after_process_ast`, `before_create_runtime`, `after_copy_assets`.

**@layout** — directive (compile-time only, not game content): shares a
layout between scenes.
```
@layout l_two_column {
  layout_mode: :stack
  blocks: [sidebar: #c_sidebar]
  layout: ```
  <div class="columns"><div class="column">${content}</div><div class="column is-3">${sidebar}</div></div>
  ```
}
@scene s_market { layout_id: #l_two_column initial_card_id: #c_stalls }
```
Allowed: `layout` (required), `layout_mode`, `layout_separator`,
`layout_reverse`, `bindings`, `blocks`, `css_class`, `on_will_render`,
`on_did_render`. Copied into the scene at compile time: `@defaults` <
`@layout` < the scene's own attributes (`+` handlers chain after the
layout's). `bindings`/`blocks` are combined, layout entries first; a scene
entry with the same name replaces the layout's. `layout_id` must be a literal
`#id` (no constants), is removed after the import and replaced by
`$layout_reference: "<layout id>"`; there is no runtime `@layout` object.
Layouts can't nest. `@game` may use `layout_id` only with a `:single` layout.

## schema
Writing @schema rules for your own elements.

```
@schema weapon {
  damage: {kind: :number, required: true, min: 1, max: 20}
  kind_of: {kind: :keyword, in: [:blade :blunt]}
  owner_id: {kind: :elem_ref, ref_elem: @actor}
  traits: {kind: :set, coll_kind: :keyword}
  on_hit: {kind: :function, param_count: 2}
  ?/^stat_/: {kind: :number}           %% any attribute matching the regex
}
```

Rules: `kind:` (one or `[:a :b]`) from `:boolean :number :string :keyword
:list :set :elem_ref :map :function :source_template :list_binding :bht
:ptable :roll`; `coll_kind:`; `required: true`; `allowed: false`; `min:`
`max:` (numbers); `min_length:` `max_length:` (strings/collections);
`in: [...]`; `contains: "${content}"`; `ref_elem: @card` (or `[@a @b]`);
`xor: other`, `and: other`, `or: other`; `no_key_overlap: "blocks"`;
`min_arity:` `max_arity:` `param_count:`; `file_exists` (path relative to
`assets/`); `type_exists`;
`is_a: @slot/accepts`.

## templates
Template syntax for content/layout attributes.

```
content: ```
<p>Hello ${player.name}, you have ${player.gold | string} gold.</p>

$if(player.gold >= 10) -> {%
  <a event="buy">Buy (10g)</a>
%}
(player.gold > 0) -> {%
  <p>Not enough.</p>
%}
() -> {%
  <p>You are broke.</p>
%}

$foreach(item: items) {%
  <li>${item.name}</li>
%}, {%
  <hr>
%}

$do{ card.seen = true; }
$partial(#c_status_box, {hp: player.hp})
```
```

- `${expr}` — a binding path (`player.name`, `items[0]`, `obj["key"]`), a
  literal (string/number/bool/array) or `$CONST`, followed by zero or more
  filters `| name` or `| name: arg1, arg2`. NO operators or calls:
  `${a + 1}` and `${f()}` do not work. Compute values with `^p{}`
  properties, function bindings or filters.
- `$if(js) -> {% ... %}` — the condition is any JS expression evaluated with
  the bindings as variables. Chain more `(js) -> {% %}` branches; `() ->`
  is the else. The `->` is mandatory.
- `$foreach(name: binding.path) {% body %}` with optional `, {% divider %}`.
  The path must resolve to an array (bind objects, not ids — see `*` below).
- `$do{ js }` runs JS (no output). `$break(cond)` triggers the debugger.
- `$partial(#card_id, {k: v})` renders another card's content inline with
  `params`.
- `\$` writes a literal `$`.
- Components: `<.name attr="v" />` or `<.name attr={js}>content</.name>`.
  Built-in: `<.img name="asset_id" />`, `<.embed_card card="card_id" />`.

Bindings (available as variables in templates and `$if`):

- Always: `game`, `scene`, `card` (the element being rendered, under its
  type name), `block`, `source`, `params`, every `$global: true` element by
  id, and for layouts `content`. Bindings of game → scene → card flow down.
- `bindings: [...]` on game/scene/card:

```
bindings: [
  player: #player                       %% element
  name: player.name                     %% path into an earlier binding
  items: *player.item_ids               %% * = turn id(s) into object(s)
  total: (block, source, bindings) => { return bindings.player.gold * 2; }
  label: "Hello"                        %% literal (string/number/bool/keyword/list)
]
```

- `blocks: [sidebar: #c_sidebar]` renders that card and makes its HTML
  available as `${sidebar}` (typically in a layout).

Filters (stdlib): `eq ne gt gte lt lte` (comparison, arg), `bsel: [a, b]`
(true→a), `sel: [..]` (index), `add sub mul div mod abs neg inc dec round`
, `ordinal lpad rpad string append prepend capitalize to_camel_case
to_title_case trim upcase downcase pluralize nplural possessive i_article
quoted dquoted split starts_with ends_with contains char_at length take at`.
Custom filters with `@filter`. There is no `asset_path` filter. Use
`<.img name="asset_id" />`, `<.img name={js_expr} />` for a computed id,
or bind the asset and write `<img src="${portrait.$dist_path}">`.

Forms: `<input rez-bind="player.name">` (also checkbox, radio, select,
textarea) writes to the attribute as the player types; add `rez-live` to
raise `on_input`. `<form name="login" rez-live>` raises `on_login: (card,
evt)` on submit with `evt.form`.

## navigation
Links and buttons that play cards, switch scenes and raise events.

| Markup | Effect |
|---|---|
| `<a card="c_next">` | play card in current scene |
| `<a scene="sc_town">` | switch scene |
| `<a interlude="sc_shop">` | push current scene, run another; return with `<a resume>` |
| `<a event="search">` | call `on_search` (card → scene → game) |
| `<button ...>` | same attributes as `<a>` |

- These shorthands only work in templates. In `@component` output and other
  JS-generated HTML use `data-event="card|switch|interlude|resume|<name>"`
  and `data-target="id"`.
- Extra `data-*` attributes arrive in the handler's params:
  `<a event="wear" data-item="${item.id}">` → `params.item`. The native click
  is `params.evt` (`params.evt.shiftKey`).
- Event names are lower-cased; use snake_case (`event="try_key"` →
  `on_try_key`).
- A custom event is handled by the current card, then the scene, then the
  game. A handler on a *block* card is only found if the link has
  `data-target="<that card id>"`.

## events
Handler signatures and what they must return.

- Custom event handlers (`on_<name>` reached from links, forms, timers,
  keybindings) are `(receiver, params) => RezEvent`. Always return a
  `RezEvent`: a click handler that returns anything else throws.
- Lifecycle handlers (`on_init`, `on_start`, `on_will_start`, …) are
  `(obj, evt) => {}`; their return value is not used.

`RezEvent` responses (static constructors, chainable instance methods):

```
return RezEvent.playCard("c_next");             // play card in scene
return RezEvent.sceneChange("sc_town");         // switch scene
return RezEvent.sceneInterlude("sc_shop");      // interlude
return RezEvent.sceneResume();                  // end interlude
return RezEvent.render();                       // re-render current view
return RezEvent.noop();                         // nothing
return RezEvent.flash("Saved!");                // flash message
return RezEvent.modalMessage("Text", {title: "T"});
return RezEvent.modalCard("c_help", params, {showDismiss: false});
return RezEvent.banner("Level up!", {onscreen: 2000});
return RezEvent.error("message");
return RezEvent.queueEvent("enemy_turn", {}, {delay: 500, lock: true});
return RezEvent.playCard("c_win").flash("You won!").setParam("score", 10);
return RezEvent.render().after(() => { ... });
```

There is no `switchScene` and no `.modal()`.

## behaviours
Behaviour trees for NPC logic.

```
@behaviour is_thirsty {
  options_spec: [:threshold]
  execute: (behaviour) => {
    return behaviour.owner.thirst > behaviour.intOption("threshold");
  }
}

@actor sam {
  thirst: 5
  behaviours: ^[$sequence [is_thirsty threshold=3] [order_drink]]
}
```

- `execute: (behaviour) => boolean` — must return `true`/`false`. Use
  `behaviour.owner`, `behaviour.option("x")`, `intOption`, `numberOption`,
  `behaviour.children`, `behaviour.firstChild.executeBehaviour()`.
  Optional `configure: (behaviour) => {}`, `min_children`, `max_children`.
- The tree attribute is `behaviours` (British spelling). `behaviors:`
  compiles but is never run.
- Run a tree: `actor.behaviours.executeBehaviour()`. Or enable the stdlib
  `$actor_behaviours` system (`enabled: false` by default), which runs every
  actor's `behaviours` tree when a `behaviours` event is raised
  (`<a event="behaviours">`).
- Core composites/decorators: `$select` `$select_r` `$select_p` (p=1–100)
  `$sequence` `$loop` (count) `$loop_until` (attempts) `$maybe` (p)
  `$either` (p, 2 children) `$random_choice` `$random_each` `$always`
  `$never` `$invert` `$fail` `$succeed`.
- Reuse subtrees: `@behaviour_template t ^[...]`, then `[&t]` in a tree.

## runtime
The JavaScript API used in handlers, methods and bindings.

Globals: `$("id")` → element (or undefined), `$game`, `$<id>` for
`$global` elements, `$kKeyword` keyword constants, `$CONST` constants.

Any element (`RezBasicObject`):

- `obj.id`, `obj.attr_name` (get/set; assignment is tracked for saving and
  runs `on_<attr>_changed`).
- `getAttributeValue(name, default)`, `setAttribute(name, v)`,
  `hasAttribute(name)`.
- `modifyAttribute("list", (l) => l.push(x))` — required when mutating a
  list/set/table in place, otherwise the change is not saved.
  `markChanged("attr")` after an external mutation.
- `hasTag("t")` / `addTag("t")` / `removeTag("t")`, `kindOf("npc")`.
- `runEvent("name", params)`.
- Copies: `addCopy({id, post_init_fn})`, `copyWithAutoId()`,
  `copyAssigningId(id)`. On the copy, `on_copy: (obj, evt)` runs with
  `evt.original`.

`$game`:

- Lookup: `getAll("actor")`, `filterObjects(pred)`,
  `getObjectsWithTag("t")`, `getRelationship(a, b)`.
- `save()`, `load(json)`, `canSave`, `undo()`.
- Bypassing events: `playCardWithId`, `startSceneWithId`,
  `interludeSceneWithId`.
- Messages: `addFlashMessage`, `setBanner`, `setModalMessage`,
  `clearModal`.

`RezInventory` (positions by name, items by id):

- Queries: `itemsIn(pos)`, `allItems()`, `positionOf(id)`.
- Changes: `add(pos, id)`, `remove(pos, id)`, `move(pos, id)`. Each returns
  a `RezDecision`; check `d.wasYes` / `d.wasNo`, `d.reason` and
  `d.getData("failed_on")`, which is one of `enabled located accepts
  excludes capacity weight actor missing`.
- `enable(pos)`, `disable(pos)`, `isEnabled(pos)`, `isAvailable(pos)`.
- `totalWeight()`, `remainingWeight()`.
- Never edit `positions` directly.

`RezDecision`: `new RezDecision("purpose")`, `yes()`, `no("why")`,
`defaultYes()`, `defaultNo()`, `hide()`, `wasYes`/`result`, `wasNo`,
`reason`, `setData(k, v)`, `getData(k, default)`.

Array/collection helpers (stdlib patches):

- `refs()` (ids → objects), `ids()`, `randomElement()`, `fyShuffle()`,
  `sample(n)`, `uniq()`, `sum()`, `min()`, `max()`, `take(n)`, `remove(x)`,
  `englishList()`.
- `Math.rand_int(n)`, `Math.rand_int_between(a, b)`, `Math.clamped_add`.
- `n.ordinal()`, `s.capitalize()`, `s.indefiniteArticle()`,
  `s.possessive()`.
- Sets: `union`, `intersection`, `difference`.

Saving: only attributes that were assigned (or flagged with
`modifyAttribute`/`markChanged`) are saved. Bump `@game archive_format` when
saved attributes change shape. `on_will_save` / `on_did_load` handlers.

## gotchas
Mistakes that compile but misbehave, or fail confusingly.

1. `${}` holds a path plus filters, not JS. Use `$if(js)`, `^p{}` properties
   or function bindings for computation.
2. `$if` needs `->` before each `{% %}` body; the else branch is `() ->`.
3. `card=`/`scene=`/`event=` link shorthands are not expanded in
   `@component` output; use `data-event` and `data-target`.
4. Custom event handlers must return a `RezEvent`. Lifecycle handlers need
   not.
5. In-place mutation (`push`, `x.k = v`, `set.add`) is not saved. Use
   `modifyAttribute` or assign a new value.
6. `$foreach` needs objects. Bind with `*` (`items: *actor.item_ids`) or
   call `.refs()` in a function binding.
7. Attribute names are snake_case in Rez and in JS (`player.max_hp`); API
   methods are camelCase. Keywords are strings at runtime (`:sword` →
   `"sword"`).
8. An `_id` attribute gets a companion attribute (`weapon_id` → `weapon`).
   Don't define both yourself.
9. Comments are `%%`. `//` only works inside JS bodies. `%%` is stripped to
   the end of the line everywhere, even inside strings, templates and JS,
   so never write `%%` in content.
10. Arrow functions need a braced body: `(x) => { return x; }`. A `@mixin`
    only shares functions and `^p{}` properties, not plain values.
11. A handler for a link inside a block card needs `data-target`.
12. Items need a `@slot` whose `accepts` matches their `type` (via
    `@derive`), even if they are never placed in an inventory.
13. Don't edit `lib/stdlib.rez` because it is regenerated. Override with
    your own `@defaults`/`@elem`.
14. Event names are lower-cased before lookup.
15. The CSS directive is `@styles`. An asset needs exactly one of
    `file_name:` (searched for under `assets/`) or `file_path:` (relative
    to `assets/`), not `file:`.
16. `$global` elements become bindings everywhere. Keep them few.
