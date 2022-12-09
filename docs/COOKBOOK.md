# Rez Cookbook

The following is a guide to some of Rez's features and common things you may want to be able to do.

# Using `@object`

Rez defines a number of generally useful elements like `@actor`, `@item`, `@inventory`, `@scene` and so forth. These elements have built-in behaviours designed to be useful but flexible.

For example `@item` and `@inventory` can be used to define much more than physical objects. You could have an inventory representing things different actors know about and use an item for individual topics/thoughts. Or items could represent spells in an inventory spell-book. The `@item`/`@inventory` elements are flexible enough to cover a range of container/containment situations.

However, there are going to be a range of concepts in a game for which Rez cannot plan or which may require very customised behaviour. A good example is that of "classes" as in RPG classes. There are so many possible ways to have a class work in a game that Rez cannot really offer a useful starting point. For this type of situation there is `@object`.

The `@object` element allows you to create a fully-custom object that has no built-in behaviours (beyond what you get from the `__basic_object__` runtime prototype that all in-game objects share).

Let's look at an example:

    @object soldier begin
      specialisation: :combat
      perks: #{#two_weapon_style #pounce #shield_bash #second_wind}
    end

    @object two_weapon_style begin
      level: 3
      label: "Fight with two weapons almost as well as one"
    end

    @object pounce begin
      level: 5
      label: "Close distance to an enemy and engage them quicker"
    end

    @object shield_bash begin
      level: 7
      label: "Shields can be a weapon in the right hands"
    end

    @object second_wind begin
      level: 9
      label: "When the chips are down, you come out fighting"
    end

    @object wizard begin
      specialisation: :magic
      perks: #{#fast_cast #mana_surge #concentration #max_damage}
    end

    @object fast_cast begin
      level: 3
      label: "Faster than a speeding magic missile"
    end

    @object mana_surge begin
      level: 5
      label: "You can always reach down for just one more spell"
    end

    @object concentration begin
      level: 7
      label: "Nothing can distract you"
    end

    @object max_damage begin
      level: 9
      label: "Your fireballs are the crispiest"
    end

    @actor thaugrim_the_wise begin
      %% Code dealing with this actor can lookup available perks from
      %% the Wizards class object
      class: #wizard
    end

How an author chooses to use these elements in their game is up to them, there are many ways that class membership & perks could be applied to in-game situations. You'd write callbacks or behaviour tasks that make use of them. These elements can be referenced by `$(<id>)`, the same as other elements and implement the `__basic_object__` abstraction.

# Avoiding Duplication with Aliases

A common scenario is a number of scenes wanting to share the same layout. While it is possible to supply the same `layout:` attribute and duplicate the content Rez does offer a better way: aliases.

An alias specifies a type of element to create and default attributes to supply, so for example:

    @alias std_scene = scene # begin
      layout: """
      A common layout for all standard scenes
      {{content}}
      """
    end

Allows us to define a scene with the common layout as:

    @std_scene scene_one begin
    end

Note that the values in an alias are a starting point and can be overriden:

    @alias class = object # begin
      description: "A class"
      tags: #{:class}
    end

    @class fighter_class begin
      description: "Fighter"
      tags: #{:combat_class}
    end

The `figher_class` object will end up with the description "Fighter" not "A class" and this is what you want. Any `tags` attribute is treated specially however, and `fighter_class` has `tags: #{:class :combat_class}` beacuse it merges, rather than overwriting, the tags defines in the `@alias`.

Anywhere that you want a common way of defining multiple game objects, the alias is a possible solution.

# Using Decisions

`RezDecision` is an object that doesn't have an element. You create them when you want code (or perhaps users) to make a yes/no decision.

You can use a decision like this:

    const decision = new RezDecision("Include Adult themes", {info: "Toggle this on to include themes of sex & violence that might not be suitable for all. Leave it off for a family friendly experience."});
    decision.default_no();
    some_function_making_the_decision(decision);
    if(decision.result) {
      // do something
    } else {
      // do something else
    }

In this case the `some_function_making_the_decision(decision)` is expected to call either `decision.yes()` or `decision.no("reason")` before returning. In most cases you will be passing a decision to a script. In this case if neither function gets called the decision will default to 'no' (`false`). If we had used `decision.default_yes()` it would work the other way around.

You can pass data into a decision either through the second argument to `new RezDecision()` or using the `setData(key, value)` API. After receiving a decision you can use the `data()` API to retrieve data. This way the callee can pass other information back with the decision.

# Linking to things

The current scene will render its card which can include links to render other cards and other scenes. This is done by specifying either a card or scene id in a link.

If the id is of a card then the new card will be rendered as part of the layout of the existing scene. Depending on the scenes layout mode it will either replace the content of the previous card, or be appended to it.

If the id is of a scene then a transition to the new scene will be started.

# Static Links

A static link is always embedded and points directly at a card or scene. It is equivalent to a Twine passage link and has the same syntax as follows:

```
[[Main Street]]
```

This will embed a link to load a card with the id `main_street` and is syntactic sugar for writing:

```
[[Main Street|#main_street]]
```

If no id is included the link text is converted into lower case and spacres are replaced with underscores, so "Main Street" becomes "main_street".

# Dynamic Links

Sometimes you want more control over whether links are displayed at all, can be clicked, and what text they present. For example an option may be disabled with a message that informs the player why they can't take that action at present. Or hidden because it doesn't make sense yet.

Rez supports dynamic links that give you this level of control. For example if you write:

```
[[*main_street]]
```

Rez will look for a `main_street` script attribute of the card and will call that script to determine whether a link should be displayed, what the text of the link should be, and whether the player can click it or not, and even what happens when they do.

The options are:

 * **allow** which will display the link and point to the id
of a card or scene to load if the player clicks it.
* **deny** which will present the link text but disable the link so that it
cannot be selected.
* **hide** which will return empty text so that no link is presented at all

Example

```
card side_street begin
  main_street: (choice) => {
    if choice.game.is("dark") {
      choice.deny("You can't see a thing, maybe use your flashlight or a match.");
    } else {
      choice.allow("Head to Main st.", "main_street");
    }
  }
end
```

You can also take over what happens when a link is clicked:

```
card side_street begin
  on_main_street: (game, evt) => {
    // do what you want here
  }
end
```

## Forms and Inputs

Rez has built in support for forms and inputs that is enabled by adding
`rez-live` to the `<form>` or `<input>` tag. For example to process a form
when it is submitted:

  <form name="foo" rez-live>
    …
  </form>

When this form is submitted a handler `on_foo` will be invoked on the `Card`
that contains the form.

Alternatively if you just want an input that is "live" you can use:

  <input id="…" rez-live … />

Whenever the input generates an event (e.g. the user changes the value of the
field) a corresponding handler:

  on_input: (game, evt) => {// do something with evt.input}

will be called on the enclosing Card.

The potential uses for this are endless but typically you will either be
updating a stored value or triggering a new scene/interlude.

## Switching Scenes

There are two ways to change the scene:

A scene shift is where we move from one scene to another as part of the
narrative flow of the game.

A scene interlude is where we suspend the current scene and temporarily switch
to another scene before resuming the original scene. Scenes are held in a
stack so we can also interlude from an interlude but always with the ability
to backtrack to the original scene.

Rez provides two Handlebars helpers for this:

    {{rez_shift card <scene_id> 'Title'}}
    {{rez_interlude card <scene_id> 'Title'}}

with the respective shorthand syntaxes:

    [[Title|>scene_id]] # Switches to a new scene
    [[Title|!scene_id]] # Interrups the current scene with the new scene

Use the Scene API to resume after an iterlude.

# Asset Management

Rez has built in support for assets including images, sounds, and movie files.
You specify the assets you want to use in your source file.

```
@asset frobzz_1 begin
  tags: #[:background]
  file_name: "scary_dungeon.jpg"
end
```

Rez will automatically copy asset files into the games distribution folder.

Rez provides a Handlebars helper

    {{rez_asset <asset_id>}}

to generate appropriate markup to embed the asset into the game. Rez assets
auto-detect the MIME type of the asset file and generate the appropriate
HTML tag for the asset.

# Procedural Generation

Rez has support for games making use of procedural generation.

It makes use of template copying and ref'd attributes.

To make an element into a template specify the attribute

    template: true

This enables the use of the `copyAssigningId()` and `copyWithAutoId()` functions
on all game objecs. Then specify attributes that should initialised in the copy
when it is created by using refs.

    name: &name_gen
    name_gen: () => {function returning a name}

All ref-based attributes are assigned their values when a template is copied.

There is a special behaviour that when a ref references an attribute which is
either a die roll or a function that the attribute is evaluated, i.e. the
function is called or the dice rolled and the resulting value is assigned
to the referring attribute. Hence:

    skill_roll: 3d6
    skill: &skill_roll

When the object is copied the `skill_roll` will be made (e.g. 3d6 = 13) and
the value 13 will be assigned to the attribute `skill`.
