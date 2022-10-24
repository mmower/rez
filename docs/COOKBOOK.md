# Rez Cookbook

The following is a guide to some of Rez's features and common things you may
want to be able to do.

# Avoiding Duplication with Aliases

A common scenario is a number of scenes wanting to share the same layout. While
it is possible to supply the same `layout:` attribute and duplicate the content
Rez does offer a better way: aliases.

An alias specifies a type of element to create and default attributes to supply,
so for example:

    @alias std_scene = scene # begin
      layout: """
      A common layout for all standard scenes
      {{content}}
      """
    end

Allows us to define a scene with the common layout as:

    @std_scene scene_one begin
    end

Anywhere that you want a common way of defining multiple game objects, the
alias is a possible solution.

# Linking to things

The current scene will render its card which can include links to render other
cards and other scenes. This is done by specifying either a card or scene id
in a link.

If the id is of a card then the new card will be rendered as part of the layout
of the existing scene. Depending on the scenes layout mode it will either
replace the content of the previous card, or be appended to it.

If the id is of a scene then a transition to the new scene will be started.

# Static Links

A static link is always embedded and points directly at a card or scene. It is
equivalent to a Twine passage link and has the same syntax as follows:

```
[[Main Street]]
```

This will embed a link to load a card with the id `main_street` and is syntactic
sugar for writing:

```
[[Main Street|#main_street]]
```

If no id is included the link text is converted into lower case and spacres are
replaced with underscores, so "Main Street" becomes "main_street".

# Dynamic Links

Sometimes you want more control over whether links are displayed at all, can
be clicked, and what text they present. For example an option may be disabled
with a message that informs the player why they can't take that action at
present. Or hidden because it doesn't make sense yet.

Rez supports dynamic links that give you this level of control. For
example if you write:

```
[[*main_street]]
```

Rez will look for a `main_street` script attribute of the card and will
call that script to determine whether a link should be displayed, what the
text of the link should be, and whether the player can click it or not, and
even what happens when they do.

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
