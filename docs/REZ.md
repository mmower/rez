# Rez

A language, compiler, and runtime system for creating interactive fiction games with HTML

By Matt Mower <self@mattmower.com>

Version 0.9 — 13 Nov 2022
Version 0.8 — 24 Oct 2022

# The Rez Language

Rez is a language for writing interactive fiction/RPG/simulation games using HTML and incorportating Javascript, CSS, and optionally graphics, audio, and movie files.

Rez started as a __quick__ alternative to [Twine](https://twinery.org/) for an author who had become frustrated with using Twine.

Twine describes itself as an "open source tool for telling interactive, nonlinear stories," and this is where it shines. It makes it relatively easy for those with almost no development experience to get started and create a choice-based game.

Rez, by contrast, is designed for making games whose complexity is not well suited to Twine and for authors who are comfortable writing small amounts of Javascript. Rez's complexity sits somewhere between Twine and an authoring system like [Inform](https://ganelson.github.io/inform-website/) or [TADS](https://www.tads.org/).

Rez has a standard library including support for creating NPCs, item & inventory management, scenes, and maps and a behaviour tree system to introduce AI behaivour. Rez also features a simple, yet powerful, layout & templating system.

Rez is designed to be flexible enough to create a really complex and ambitious game while offering a simple & usable framework for those just getting started.

# Outline of a Rez Game

Rez games are compiled into HTML & Javascript sources (plus associated assets like images, movies and sounds) and written in `.rez` source files that are composed of elements and directives that describe the various aspects of the game.

At the top level is the `@game` element that contains the game metadata and all the other elements that make up the game.

## Creating a new game

The command

    rez new --author-name="Name" --author-email="email" --game-title="Title" --game-homepage="URL" <name>

Will create a new folder <name> containing a default structure and source files ready to be customised.

## Compiling your game

The command

    rez compile src/<game_name>.rez

Will compile the sources into a game in the `dist` folder. It creates an `index.html` as well as all of the javascript & other asset files that constitute the game.

## Defaults

The following defaults are set by the framework:

* Game styling uses the [Bulma](https://bulma.io/) CSS framework
* Dynamic UI support comes from [Apline.js](https://alpinejs.dev/)
* In game templates are rendered using [Handlebars.js](https://handlebarsjs.com/)

In a future version it will be possible to vary the CSS framework and JS library.

### NPM

Rez depends upon NPM to deliver dependencies of the game:

* Alpine.js
* Bulma CSS
* Handlebars

## Source code format

Rez games are written in plain text files with a `.rez` extension.

The characters `%` and `@` are important when writing Rez source.

`%` is used to indicate a macro while `@` is used for defining elements and directives.

### Comment macro

Line comments are supported by placing `%%` in column 0.

    %% this line will be ignored

In future the restriction that comments must start in the first column will be lifted.

### Include macro

Once source file may include another by using the include macro `%(…)`, for example:

    %(act_one.rez)

An included file may include other files but beware of creating a cyclic dependency. For example this code will hang the compiler.

    file1.rez
    ---------
    %(file2.rez)

    file2.rez
    ---------
    %(file1.rez)

## Game Design Model

We distinguish between two environments: 'authortime' when we are dealing with .rez source files and elements like `@card` and `@item` and 'runtime' when we are in the browser and dealing with Javascript objects like `RezCard` and `RezItem`.

A core concept you need to master is that of scenes & cards.

A card is represented by the element `@card` and, at runtime, by a `RezCard` object. A card is used to display content to the user within the context of a scene.

A scene is a grouping of one or more cards within a scene-specific layout. A scene can either present the content of a single card so that the content changes each time a new card is added to the scene, or the content of many cards with each new card adding more content within the scene layout.

Every game must have at least one scene and one card although meaningful games are likely to have many of both.

The simplest possible game would look something like this:

    @game begin
      name: "Test Game"
      IFID: "D3C31250-53B4-11ED-9A26-3AF9D3B0DD88"
      archive_format: 1
      initial_scene: #play_game
      layout: """
      {{{scene}}}
      """

      @scene play_game begin
        initial_card: #did_you_win
        layout_mode: :single

        layout: """
        {{{content}}}
        """
      end

      @card did_you_win begin
        content: """
        Did you win? [[yes|yes_i_won]] | [[no|no_i_lost]]
        """
      end

      @card yes_i_won begin
        content: """
        Congratulations!

        [[Play again|did_you_win]]
        """
      end

      @card no_i_lost begin
        content: """
        Better luck next time!

        [[Play again|did_you_win]]
        """
      end
    end

Here we see that the `@game` wraps a `@scene` and three `@card`s. The scene has an incredibly basic layout that just consists of `{{{content}}}`. The `{{{...}}}` is a Handlebars macro and `content` is the scene content. In this case the content of the current card (since `layout_mode` is `single`).

The initial scene of the game is set through the `inital_scene` attribute. When the game starts it picks that scene and renders it. In turn the `play_game` scene has an `initial_card` that specifies what content it should start with. In this case the `@card` with ID `did_you_win`.

The contents for a `@card` is set by the `content` attribute which is written in the Markdown format and uses some convenient syntax shorthands. In this case the simple link formats as from Twine. `[[yes]]` converts to a link that plays the card `@yes` to the scene, while `[[Play again|did_you_win]]` converts into a link to the `did_you_win` card.

Additionally Rez supports a number of other link syntaxes such as `[[*]]` for dynamic links and `[[! ]` & `[[>]]` for scene interludes and shifts respectively.

## Elements & directives

Rez is written in terms of a series of elements and directives that are specified using the `@` character. For example: `@game`, `@item`, `@inventory`, and `@alias`.

The `@game` element is required, as is at least one `@scene` and one `@card` however all other elements, and all directives, are optional.

Most elements are specified using a common syntax:

    @element [element-id] begin
      attr_name_1: attr_value_1
      attr_name_2: attr_value_2
      %% and so on
    end

Every element has an ID (the `@game` element has an implicit id of `game`) which must be unique and follow the rules for legal Javascript identifiers.

For example:

    @game begin
      name: "The Maltese Parrot"
      author_name: "Dachshund Hamlet"
      IFID: "D2050DE2-97A2-1ED1-4CCA-AF9D3B0DD883"
      created: "2022-08-31 22:13:43.830755Z"
      version: 1
      initial_scene: #meet_sam_spade

      @actor player begin
        name: "Miss ..."
        intuition: 12
        deceit: 15
        playfulness: 17
        has_parrot: false
      end

      @actor sam_spade begin
        height: 180
        eyes: "piercing, yellow grey"
        intuition: 17
        gunplay: 12
        callousness: 14
        has_parrot: false
      end

      @scene meet_sam_spade begin
        layout_mode: :continuous
        initial_card: #sam_at_his_desk
        location: #sams_office
        blocks: [#sidebar]
        layout: """
        <div class="sidebar">{{sidebar}}</div>
        <div class="main">{{content}}</div>
        """
        on_enter: (game, event) => {
          const sam = $("sam_spade");
          const intuition = sam.getAttribute("intuition");
          if(roll("d20") < intuition) {
            const sam_knows = $("sam_knows");
            const idea = $("suspicous_about_player");
            sam_knows.addForSlot("concepts", idea);
          }
        }
      end

      @card sam_at_his_desk begin
        bindings: [#player]
        content: """
        You enter the room to see a man, probably 6', with pale brown, almost
        blonde hair. He looks up with yellowish grey eyes that don't miss a
        beat.

        "Come in miss...", he says to you.

        [[* say_name]] [[Enter the Office]] [[Turn Around]]
        """
      end
    end

Elements describe in-game content in terms of attributes. Directives are more varied and typically alter how game content is defined. See the <a href="#directives-catalog">catalog</a> for more info.

## Rendering

What is displayed on screen is determined by three things:

* The layout provided by the game
* The layout provided by the current scene
* The content provided by the card, or stack of cards

### <a name="rendering_content_elements">Content Elements</a>

The `@game`, `@scene`, and `@card` elements all specify content that will be presented to the player. In the case of the `@game` and `@scene` this is their `layout` attribute, in the case of `@card` it is the `content` attribute.

What appears on screen is the current card (or stack of cards) content wrapped in the scene and then game layouts.

This makes it easy to have an overall layout with different layouts for different scenes (although scenes may also share layouts) wrapping the card content itself.

Content can be written as Markdown or plain HTML and is passed to the [Handlebars](https://handlebarsjs.com/) compiler and turned into a rendering function. This also means that all the facilities of Handlebars templates are available when creating dynamic content.

A game is all about the actions you take. In Rez these will usually be represented by links that load new cards or scenes, or trigger events that you can respond to. There are many ways to generate such links (see [Linking To Other Content](#rendering_linking_to_other_content)).

### <a name="rendering_layout">Layout</a>

The game uses a template:

    <div class="game">
      ...layout...
    </div>

So the `layout:` attribute of the `@game` is injected into the master game `<div>`. The `layout:` attribute is expected to include `{{scene}}` somewhere as this is what brings in the current `@scene` content. If `{{scene}}` is not included the layout will be empty.

Scenes use a template:

    <div id="scene_<scene_id>" class="scene">
      ...layout...
    </div>

The `layout:` attribute of the `@scene` is expected to include `{{content}}` as this is what brings in the `@scene` content which can be the output of one or more cards depending on the scene's layout mode.

Cards use a template:

    <div id="card_<render_id>"
         data-card="<card_id>"
         class="card <card_type>"
    >
      ...content...
    </div>

The `render_id` is a unique value to disambiguate each rendered thing. This means that if a card is rendered twice, while the `card_id` will be the same, the `render_id` will disambiguate them.

The rendererd `content:` attribute of the `@card` is injected into this HTML div. The `card_type` will be one of `block`, `card_active`, or `card_passive` depending on whether the content is coming from the scene's current card, an old card (in a scene with continuous layout), or a block.

Block content comies from cards that are being rendered as part of another card. For example we might have a card `#sidebar` that we want to render as part of a scene layout. In this case we would include it in the `blocks:` attribute of the scene. It will be automatically rendered and have a `card_type` of `block` to distinguish it from other content.

The rendering process disables links where `card_type` = `card_passive`. Hotlinks are only active from the current card and blocks.

You can always target a card with the `card` CSS class and then distinguish particular kinds of card through the `block`, `card_active`, or `card_passive` classes.

### <a name="rendering_linking_to_other_content">Linking to other content</a>

Borrowing from Twine we can load a new card into the scene as follows:

    [[Link text|card_id]]

This presents a link labelled "Link text" that, when clicked, loads the card with the specified id.

    [[Link Text]]

This will convert the display text "Link Text" into the snake_case `link_text` and look for a card with that id. Clicking the link will load the specified card.

Additionally we have three other convenient link syntaxes:

    [[*attribute_name]]

This is the dynamic link syntax. It looks for the attribute with name `attribute_name` on the current card and calls it passing a `RezDynamicLink` that allows the script to customise the link or hide it. This allows for creating conditionally enabled links (e.g. only works after dark, or only with a specific item) or hiding links (only visible while wearing special glasses etc…)

    [[>Link text|scene_id]]

This presents a link labelled "Link text" that, when clicked, ends the current scene and loads a new scene with id `scene_id`.

    [[!Link text|scene_id]]

This presents a link labelled "Link text" that, when clicked, interrupts the current scene and loads a new scene, with id `scene_id`, as an interlude. This is designed such that the interrupted scene can be resumed. For example you might have a scene that implements a player profile view. When the player switches to this scene we expect that, when it ends, the previous scene will continue from where they left off.

    [[Link Text|!!]]

This presents a link labelled "Link text" that, when clicked, ends a scene interlude and resumes the previous scene where it left off.

### <a name="rendering_including_assets">Including assets</a>

Rez includes a Handlebars helper `r_asset` for including asset content. The helper will generate an appropriate tag for the assert. So, for example:

    {{r_asset "image_01"}}

Would generate an appropriate `<img />` tag to include the asset with id `image_01`. At present only image assets are fully supported however sound and movie assets will be implemented in a future version.

To access the raw path to the asset file get the corresponding `RezAsset` object and access its `path` attribute.

### <a name="rendering_cs_and_js">CS & JS</a>

By default Rez uses the [Bulma CSS framework](https://bulma-css.com/) for styling and makes the [Alpine.js](https://alpinejs.dev/) library available for effects.

## <a name="scripts_and_styles">Scripts and Styles</a>

If you need to include custom Javascript code (outside of the in-game event handlers) or CSS styles in your game you can use the `@script` and `@style` elements respectively. These elements do not have an ID, nor do they have attibutes and are written as follows:

    @script begin
      function identifyParrot() {
        // I need this function to be available to my event handlers
      }
    end

    @style begin
      /* https://gist.github.com/JoeyBurzynski/617fb6201335779f8424ad9528b72c41 */
      .main {
        max-width: 38rem;
        padding: 2rem;
        margin: auto;
      }
    end

The content of `@script` and `@style` tags will automatically be included into the relevant parts of the generated game files.

## API Model

A game in Rez is specified in terms of the elements, described in this guide, that are compiled into a Javascript runtime model. Each element type corresponds to a runtime prototype. For example the `@game` element is represented by the `RezGame` object, the `@item` by `RezItem` and so on. All of these game objects have `RezObject` as their root prototype.

Attributes defined on an element are converted into attributes on the equivalent JS object. Callback scripts that you write are converted into JS functions.

The main game loop is implemented in terms of `RezGame`, `RezScene` and `RezCard`. The game has a concept of the __current_scene__ and the scene of the __current_card__. It is these the content (and, ultimately, markup) generated by these objects that the player interacts with.

Every object has an id which is assigned from its source element. Objects can be retrieved via the `RezGame` method `getGameObject(<id>)` which has a shorthand name of `$(<id>)` (for ease of use this shortcut is defined on most objects). Most script callbacks will be passed the id of relevant game objects. For example the actor callback `on_accept_item` which is called whenever an attempt is made to add an item to an inventory owned by the actor:

    @actor spade begin
      on_accept_item: (actor, evt)) => {
        const decision = evt.decision;
        const slot_id = evt.slot_id;
        const item = actor.$(evt.item_id);

        if(slot_id == "holster_pisol") {
          const item = actor.$(item_id);
          if(item.getAttributeValue("calibre") < 38) {
            decision.no("That's a dames gun!");
          }
        }
      }
    end

Here you can see a [`RezDecision`](#rezdecision) object at work. You will sometimes find decisions being passed to callbacks where the purpose of the callback is to check whether some action or outcome is possible or not.

Much of the work of writing Javascript in a Rez game will be implementing event callbacks of one type or another. They all follow a consistent pattern:

    on_<event-name>: (obj, evt) => {
      ...
    }

The `obj` parameter will be the object that is responding to the event (in the example above it is the `actor`) and the `evt` parameter will be a map containing data that pertains to the event (in the example above we have `decision`, `inventory_id`, `slot_id`, and `item_id` although the `inventory_id` is not used in the example).

Your game objects are not required to respond to every event, only those where they wish to customise the default behaviour. For example if an actor doesn't implement the `on_accept_item` callback the default is to allow the item.

All game objects have a `game` attribute, a reference to the root game object from where all other game objects and functionality can be accessed.

See the [API Reference](#api-reference) for a complete breakdown of the objects, methods, and events in the Rez runtime.

# Behaviour Trees

A Rez game can include elements of artificial intelligence using behaviour trees ([ref1](https://opsive.com/support/documentation/behavior-designer/what-is-a-behavior-tree/), [ref2](https://towardsdatascience.com/designing-ai-agents-behaviors-with-behavior-trees-b28aa1c3cf8a)) that are implemented as a native part of the language.

While it is possible to script __intelligent__ behaviour using Javascript based script attributes, behaviour trees offer an alternative, more declarative, approach that focus on the action, not the code.

A behaviour tree is specified in terms of __tasks__ that can be of one of four types (composite, decorator, condition, and action) that get executed and either succeed or fail.

## composite (sometimes known as control) tasks

Composite tasks like `SEQUENCE` and `SELECT` take a number of child tasks and organise how they are executed. For example `SEQUENCE` tries to execute all of its children, while `SELECT` executes until one of them succeeds.

## decorator tasks

Decorator tasks like `INVERT` and `ALWAYS` take a single child task and modifies how that childs success or failure is represented to the rest of the tree. For example `INVERT` changes success to failure and vice verca while `ALWAYS` ignores whether the childs succeeds or fails and always succeeds itself.

## condition tasks

Condition tasks are implemented by the author and allow the behaviour tree to query the state of the game.

## action tasks

Action tasks are implemented by the author and allow the behaviour tree to change the state of the game.

## Standard Library

The Rez standard library defines a number of ["core tasks"](#task_catalog) (composites and decorators) that can be used to structure your behaviour trees. As an author you will implement condition & action task elements tailored to your game.

## Example

    @actor wilmer begin
      behaviours: ^[SEQUENCE [
        [ACTOR_ALONE_WITH actor=sam_spade]
        [ACTOR_HAS_BEEF_WITH actor=sam_space]
        [ACTOR_HAS item=handgun]
        [ACTOR_SHOOTS item=handgun target=sam_spade]
      ]]
    end

Wilmer has a very simple behaviour. If they are alone in the same location as Sam Spade, they've got a beef with Sam, and they are armed, they will attempt to shoot Sam. This example shows one of the default library tasks `SEQUENCE`.

`SEQUENCE` takes a number of children and attempts to execute them in turn, stopping (and failing) if any child fails. So, for example, if Wilmer isn't in the same location as Sam the `SEQUENCE` will fail at that point. It will also fail if there are other actors present, or Wilmer doesn't have a beef with Sam, or Wilmer has been disarmed.

In this case the `SEQUENCE` task is provded by Rez while the author must provide behaviours like `ACTOR_ALONE_WITH`, `ACTOR_HAS_BEEF_WITH`, `ACTOR_HAS`, and `ACTOR_SHOOTS`. The exact details of how these task should be implemented will vary from game to game.

It should be noted that the same behaviour could be implemented in Javascript as a function. However behaviour trees provide a declarative style that is suited to creating more complex behaviours.

    @actor wilmer begin
      behaviours: ^[SELECT [
        [SEQUENCE [
          [ACTOR_ALONE_WITH actor=sam_spade]
          [ACTOR_HAS_BEEF_WITH actor=sam_spade]
          [ACTOR_HAS item=handgun]
          [ACTOR_SHOOTS item=handgun target=sam_spade]
        ]]
        [SEQUENCE [
          [INVERST [ACTOR_HAS item=handgun]]
          [LOCATION_HAS item=handgun]
          [ACTOR_TAKES item=handgun]
        ]]
        [SEQUENCE [
          [ACTOR_WITH actor=sam_spade]
          [ACTOR_WITH actor=kaspar_gutman]
          [ACTOR_THREATENS actor=sam]
        ]]
      ]]
    end

In this slightly more complex example we combined the `SEQUENCE` behaviour with the `SELECT` behaviour. Wilmer will now attempt to shoot Sam if he can, if he's been disarmed he'll attempt to take any available handgun, failing that if he's in the same place as Sam & Gutman he'll attempt to threaten Sam. Note the use of the `INVERT` decorator to change the meaning of the `ACTOR_HAS` condition task.

You can see how with a few simple concepts we can create more and more complex behaviours, and this is just the beginning. It can also be a lot easier to understand and modify a complex behaviour tree than the equivalent JS code.

Note that Rez behaviour trees do not presently support a 'running' status such as is common with some popular behaviour tree implementations (e.g. Crysis on which this is loosely based). A real-time FPS requires 'running' because some of its actions may take many game ticks (e.g. pathfinding to a new location). This is assumed not to be the case for Rez games. Support for 'running' may be implemented in the future if it turns out to be useful.

# Attributes

A Rez element is defined in terms of attributes. Some attributes are expected (and perhaps required) by the game (e.g. the `content` attribute of `@card`) while some you will define yourself and use in your event handlers and glue code.

An attribute has a name and a value. The name follows the rules for legal Javascript identifiers:

* cannot contain spaces
* must begin with a letter, underscore (_), or dollar sign ($)
* can only contain letters, numbers, underscores, or dollar signs
* are case sensitive

This means that any attribute defined on any in-game object can be referenced naturally in user Javascript code.

Note that attributes with a leading underscore are considered to be "internal" to the Rez compiler and will not appear in the generated code.

Attributes are written:

    name: value

There should be no space between the end of the attribute name and the `:` and at least one whitespace between the `:` and the value.

**Legal**

    title: "The Maltese "

**Not-legal**

    title : #foo
    title :#foo
    title:#foo

## Attribute Types

The following types are supported:

### Boolean

The values `true`, `false`, and `yes`, `no` are recognised and can be used interchangably to represent truthy values.

### Number

Positive and negative integer and floating point numbers, e.g.

  `12`, `-2.5`

### String

Text delimited by `"` useful for short strings such as descriptions. However, for passages of text it can be easier to use a Heredoc String

### Heredoc Strings

Text delimited by `"""`. These can span over multiple lines.

### Attribute reference

An attribute reference is `&` prefix followed by the name of the attribute to be referenced.

    name_gen: () => {...function returning a name...}
    name: &name_gen

These are typically used during initialization. An element that uses an attribute reference will resolve it during object initialization. This is a an advanced technique mainly useful for procedural generation.

### Element reference

An element reference consists of a `#` prefix followed by an element ID, e.g.

    favourite_monster: #ugly_troll
    initial_scene: #lost_scene

A reference is used to refer to a unique element in the game. The compiler will generates an error if the referenced element does not exist. At runtime an exception will be generated if the element lookup function `$("some_id")` is passed an id not known to the game.

### Dice Roll

A dice roll is specified in the form [count]d[sides][+|- modifier]. So that:

    strength: d6
    strength: 2d6
    strength: 3d6-1
    strength: d20+1

Are all legal die roll specifiers.

Dice role based attributes are mainly a shorthand for games making use of procedural generation.

### Keyword

A keyword is a `:` prefix followed by a Javascript compatible id, e.g.

    :continuous
    :weapon
    :item

Keywords are used for constant values, for example the type of an item (e.g. `:sword`) or the layout mode of a scene (`:continuous`).

Keywords can be formed into hierarchies using the `@derive` directive.

### Script

In Rez a script is an arrow-style function. Scripts are typically used as event handlers. However script attributes can also be invoked by user code.

    (event) => {
      if(event.target.value == "Fight") {
        $game.setCurrentScene("fight");
      }
    }

### List

A `[]` bracketed list of values that can include other collections such as lists, sets, & tables. Lists items are ordered as specified.

    [#ugly_troll #friendly_troll]
    [1 2 3 4]
    [[:a 1] [:b 2] [:c 3]]

Note that lists in Rez are whitespace, not comma, separated.

### Set

A `#{}` bracketed list of values that are constrained to be unique (according to the JS notion of equality). Set items have no defined order.

    #{:one :two :three}

Note that sets in Rez are whitespace, not comma, separated.

### Table

A `{}` bracketed list of name/value pairs where the name follows the attribute naming rules and the value can include other collections such as lists, sets, and tables.

    {
      hostile: true
      coordinates: [1 2]
      attrs: {
        strength: 10
        hp: 15
      }
    }

Note that key/value pairs in tables are whitespace, not comma, separated. Table items have no specific order.

### Behaviour Tree

A behaviour tree is a collection of tasks (which can be an action, condition, composite, or decorator), assembled into a hierarchy with a root task at the top. Syntacically a behaviour tree is written:

    ^[root_task]

Each task is described as a list:

    [task_id option=value option=value ... child_list]

Some tasks have options and some (usually composites) will take children.

The standard library includes a number of composite and decorator tasks that are typically used to structure and manipulate other tasks.

Action tasks alter the game while condition tasks test the state of the game. For example we could imagine a condition task like:

    [ACTOR_SEES actor=sam_spade item=whisky_bottle]

We can imagine that `ACTOR_SEES` would be written to see if the `whisky_bottle` item is in the same location as the actor `sam_spade` succeeding if it is or fail. Such a task might be implemented as follows:

    @task ACTOR_SEES begin
      options: [:actor, :item]

      execute: (task, wmem) => {
        const game = action.game;
        const actor_id = task.options("actor");
        const actor = task.$(actor_id);
        const location_id = actor.getAttributeValue("location");
        if(location_id == null) {
          return {
            success: false,
            error: "Actor " + actor_id + " is off-stage",
            wmem: wmem
          };
        };
        const location = task.$(location_id);
        const container_id = location.getAttributeValue("container");
        if(container_id == null) {
          return {
            success: false,
            error: "Location " + location_id + " does not have a container",
            wmem: wmem
          };
        }

        const item_id = task.options("item");
        const slot_id = container.contains_item(item_id);

        if(slot_id == null) {
          return {
            success: false,
            error: "It not in actors location",
            wmem: wmem
          };
        } else {
          return {
            success: true,
            wmem: wmem
          };
        }
      }
    end

Let's pair that with another behaviour:

    [ACTOR_TAKES]

We can imagine this task putting a previously identified item into an actors inventory. We could make this action happen by using the composite task `SEQUENCE` as follows:

    [SEQUENCE [
      [ACTOR_SEES actor=sam_spade item=whisky_bottle]
      [ACTOR_TAKES_ITEM]]]

If `ACTOR_SEES` fails the `SEQUENCE` will fail before the `ACTOR_TAKES` can be executed. We can stack up more than one of this type of `SEQUENCE` using the `SELECT` composite as follows:

    [SELECT [[BEHAVIOUR_1 ...] [BEHAVIOUR_2 ...]]]

    [SELECT [
      [SEQUENCE [
        [ACTOR_SEES actor=sam_spade item_tagged=booze]
        [ACTOR_TAKES_ITEM]]]
      [SEQUENCE [
        [ACTOR_HUNGOVER actor=sam_spade]
        [ACTOR_HAS item=whisky_bottle]
        []
      ]]
    ]]

or MAYBE which has one option `p` meaning probability and takes exactly one child:

    ^[MAYBE p=25 [BEHAVIOUR_3 ...]]

or INVERT which takes no options and has one child

    ^[INVERT [BEHAVIOUR_4 ...]]

or we can imagine a behaviour such as:

    ^[ACTOR_SPEAKS actor=sam_spade line="You know, that's good, because if you actually were as innocent as you pretend to be, we'd never get anywhere"]

Here we can see the three different kinds of behaviours: a composite such as `SELECT` that takes many children and organises whether & how they are executed, a decorator such as `INVERT` that takes one child and modifies how it is interpreted, and a leaf such as `ACTOR_SPEAKS` that has no children and interacts at the in-game level.

By combining these different types of behaviours we can create quite complex plans for our game components (which may principally be actors but could be anything).

See the [behaviours catalog](#behaviours-catalog) for more on the built in behaviours.

## Notes

Please note that sets, lists, and tables use whitespace as a separator between elements/pairs rather than a comma as is common in many programming languages.

So a list is written:

    numbers: [1 2 3 4]

rather than:

    numbers: [1, 2, 3, 4]

The latter will cause a syntax error.

# Elements

Rez includes many elements that you will combine to create your game, starting with the `@game` element that wraps the whole thing.

All elements in a Rez source file are prefixed by `@`.

A few Rez elements like `@game` and `@zone` contain other elements but most do not.

<a name="elements-catalog">The elements are:</a>

* [`@actor`](#actor-element)
* [`@asset`](#asset-element)
* [`@task`](#task-element)
* [`@card`](#card-element)
* [`@effect`](#effect-element)
* [`@faction`](#faction-element)
* [`@game`](#game-element)
* [`@group`](#group-element)
* [`@inventory`](#inventory-element)
* [`@item`](#item-element)
* [`@list`](#list-element)
* [`@location`](#location-element)
* [`@object`](#object-element)
* [`@plot`](#plot-element)
* [`@rel`](#relationship-element)
* [`@scene`](#scene-element)
* [`@slot`](#slot-element)
* [`@system`](#system-element)
* [`@zone`](#zone-element)

# Directives

<a name="directives-catalog">The directives are:</a>

* [`@alias`](#alias-directive)
* [`@derive`](#derive-directive)
* [`@script`](#script-directive)
* [`@style`](#style-directive)

# Catalog

## <a name="alias-directive">Alias</a>

<emph>As of v0.8 it is not possible to define an alias of an alias and an error will occur if you try to do so. This functionality may be supported in a future version.</emph>

An alias is a directive that defines a way to refer to a customised version of a built-in element. Define an alias using the `@alias` directive.

Why would you want to do this? Two primary reasons:

1. An alias can supply useful default values for the element attributes
2. It may be more meaningful to define `@sword` and `@shield` rather than a series of `@item`s

You don't need to use aliases but if you find yourself repeating a lot of attributes it may be that an alias can make the game shorter and clearer.

### Example

In our Maltese Parrot game hats are a big deal and a range of hat items will be needed but we don't want to repeat ourselves defining each one using `@item` so we can create an alias that specifies that a hat is an item and how hats are, generally, configured. Then our hat definition just needs to supply what's different about *that* hat.

    @alias hat = item # begin
      type: :hat
      wearable: true
      usable: false
      bogie_would_approve: false
    end

    @hat wool_fedora begin
      material: :wool
      colour: :black
      description: "A Messer black wool fedora hat"
      bogie_would_approve: true
    end

    @hat brown_derby begin
      material: :felt
      colour: :brown
      description: "Battered brown derby"
    end

## <a name="actor-element">Actor</a>

<emph>As of v0.8 actors are mostly a placeholder for future functionality although see the `item_filter` optional attribute.</emph>

An actor represents an in-game character which could be the player avatar or a non-playable character that the player interacts with. Define an actor with the `@actor` element.

If your game is simple enough you may not need actors and they are an optional concept. However if you want to keep track of attributes, behaviours, and relationships between actors the actor element helps you do this.

### Example

In this example of our game the player can decide which of the antagonists they wish to play as. Each has different abilities and trust other characters different amounts.

    @actor sam_spade begin
      name: "Sam Spade"
      stats: {
        gunplay: 5
        fisticuffs: 8
        drinking: 8
        flirting: 6
        sluething: 9
        chat: 6
      }
      trusts: {
        miss_wonderly: 5
        joel_cairo: 4
        kaspar_gutman: 2
      }
      container: #ss_carrying
    end

    @actor joel_cairo begin
      name: "Joel Cairo"
      stats: {
        gunplay: 3
        fisticuffs: 3
        drinking: 5
        flirting: 9
        sleuthing: 6
        chat: 8
      }
      trusts: {
        miss_wonderly: 3
        kaspar_gutman: 5
        sam_spade: 3
      }
      container: #jc_carrying
    end

    @actor miss_wonderly begin
      name: "Ruth Wonderly"
      stats: {
        gunplay: 2
        fisticuffs: 2
        drinking: 5
        flirting: 10
        sleuthing: 4
        chat: 9
      }
      trusts: {
        sam_spade: 6
        joel_cairo: 4
        kaspar_gutman: 5
      }
      container: #rw_carrying
    end

    @actor kaspar_gutman begin
      name: "Kaspar Gutman"
      stats: {
        gunplay: 1,
        fisticuffs: 3,
        drinking: 6,
        flirting: 4,
        sleuthing: 7,
        chat: 9
      }
      trusts: {
        sam_space: 6
        joel_cairo: 6
        miss_wonderly: 2
      }
      container: #kg_carrying
    end

### Required Attributes
### Optional Attributes

* tags — set of keywords
* container — element-id

### Event Handlers

#### on_accept_item: `(actor, event) => {...}`

    event = {
      decision: <decision_obj>,
      inventory_id: <id>,
      slot_id: <id>,
      item_id: <id>
    }

This is a script that can be called to check whether an item can be placed into an inventory slot of a container that they are owner of (See also: inventory#owner)

    on_accept_item: (actor, event) => {
      event.decision.no(actor.getAttributeValue("name") + " wants no worldly goods.");
    }

#### on_init: `(actor, event = {}) => {...}`

This script will be called during game initialization and before the game has started.

#### on_enter: `(actor, event) => {...}`

    event = {location_id: <id>}

This callback will be received when the actor is moved to a new location and is passed the id of the location to which the actor has moved.

#### on_leave: `(actor, event) => {...}`

    event = {location_id: <id>}

This callback will be received when the actor has left a location and is passed the id of the location which has been vacated.

#### on_turn: `(actor, event = {}) => {...}`

If the game turn mechanism is being used this callback will be received on each game turn. This is intended for simple cases and if you need to coordinate behaviours across multiple elements it may be better to use a system instead.

## <a name="asset-element">Asset</a>

An `@asset` element refers to a file on disk, typically an image, audio, or
video file, that will be presented in game.

Rez automatically copies asset files into the game distribution folder when the game is compiled and manages pathing so that assets can be referred to in game without worrying about filenames and paths.

Assets can be collected into groups (using the `@group` element) dynamically choose from among related assets.

### Example

    @asset hat_01 begin
      file: "hat_01.png"
      tags: #{:hat}
    end

This defines an asset that will be copied into the game when built and which can be referred to in-game by it's id.

Rez will ensure that all assets are available during compilation.

Assets are the key to using asset groups that can be used for showing different but randomised media.

### Required Attributes

* file_name — string

### Optional Attributes

* tags — set of keywords

### Event Handlers

#### on_init: `(asset, event = {}) => {...}`

This script will be called during game initialization and before the game has started.

## <a name="card-element">Card</a>

Cards are the basic unit of content in a Rez game. They are somewhat equivalent to a passage in Twine. A card defines content that is added to the current scene when the card is played.

Internally a card is transformed into a Javascript Handlerbars template so they render quickly.

### Example

    @card intro_part_1 begin
      content: """
      You are in a mazy of twisty passages all alike.
      [[Go forward|#intro_part_2]]
      """
    end

    @card intro_part_2 begin
        …
    end

### Required Attributes

* content — string|heredoc

### Optional Attributes

* blocks — list of element-id
* css_class — a string containing custom CSS classes to apply
* bindings — map of label to element-id
* tags — set of keywords

#### blocks

If specified, the `blocks` attribute should contain a list of ids of cards that are going to be included in the output content of this card. At render time all blocks are pre-rendered and passed into the rendering context.

    @card test_card begin
      blocks: [#other_card]

      content: """
      This is what is in #other_card
      {{{other_card}}}
      """
    end

#### bindings

If specified this should be a map of keys to game object ids. When the card is rendered all bindings will be resolved and made available to the rendering context. You can then use the `$` macro to render attributes of the bound objects.

    @card test_card begin
      bindings: {player: #player}

      content: """
      The player's name is {{attr player "name"}}
      """
    end

### Event Handlers

#### on_init: `(card, event = {}) => {...}`

This script will be called during game initialization and before the game has started.

#### on_enter: `(card, event = {}) => {...}`

#### on_render: `(card, event = {}) => {...}`

#### on_ready: `(card, event = {}) => {...}`

#### on_leave: `(card, event = {}) => {...}`

### Notes

Card content is written in Markdown and converted to HTML. It's somewhat similar to a Twine passage and some of the basic syntax, e.g. `[[Go forward|intro_part_2]]` translate across to Rez.

However there are a number of additional syntaxes. For example it's possible to hijack this mechanism using a script:

    @card intro_part_1 begin
      content: """
      You are in a mazy of twisty passages all alike.
      [[Go forward]]
      """
      on_go_forward: (game, evt) => {return Scene.load_card(game, "intro_part_2");}
    end

Here we define an event handler which will respond to the link being clicked. By default Rez will automatically convert a link such as "Go forward" into the equivalent "go_forward" by downcasing and replacing whitespace with a single underscore(_).

Rez also has support for more dynamic types of links:

    @card intro_part_1 begin
      content: """
      You are in a mazy of twist passages all alike.
      [[Go forward|go_forward]]
      """
      go_forward: (game, evt) => {evt.choice.show("Go forward);}
      on_go_forward: (game, evt) => {return Scene.load_card(game, "intro_part_2")}
    end

When a card link is written in this format, Rez will look inside the card for an attribute with the same name and a function value. It will call the function which can determine whether the link should be shown or hidden and, if it is shown whether it should be enabled or disabled. whether it is enabled or disabled.

However there is support for other kinds of actions and dynamic links. See the COOKBOOK for more information.

## <a name="derive-directive">Derive</a>

The `@derive` element is used to form keywords into hierarchies of types for items, effects, and so on. Let's take an example of where this might be useful: inventories.

We setup a hierarchy as follows:

  @derive :weapon :item
  @derive :sword :weapon
  @derive :mace :weapon
  @derive :potion :item

The result is that an item with `type: :sword`, `type: :mace`, or `type: :potion` can be placed into a slot that `accepts: :item`. It's not required to list all the different types of items that are legal in that slot. Equally our sword can be placed into a slot that `accepts: :sword` but an item `type: :mace` cannot, nor can an item `type: :potion`.

An item hierarchy can be as simple of complex as you need. At run-time all of the item type information is converted into tags. For example an item with `type: :sword` would have tags as if we had written `tags: #{:sword :weapon :item}`.

## <a name="effect-element">Effect</a>

Effects are modifiers to aspects of the game that can be applied and removed dynamically as the game progresses.

For example an item, when worn, might convey a bonus to the actor wearing it. In this case the effect, attached to the item, is applied when the item is worn and removed when the item is removed.

Effect support is limited in v0.8. Effect scripts will be called and its up to the caller to ensure these work. In particular there is no support yet for effects that, for example, wear off over time.

### Example

    @effect drunk begin
      name: "Drunk"
      description: "you're drunk, it's so much harder to concentrate"
      on_apply: (evt) => {
        const actor = $(evt.actor_id);
        // Add drunkness effects
      }
      on_remove: (evt) => {
        const actor = $(evt.actor_id);
        // Remove drunkness effects
      }
    end

### Required Attributes
### Optional Attributes

* tags — set of keywords

### Event Handlers

#### on_init: `(effect, event = {}) => {...}`

This script will be called during game initialization and before the game has started.

#### on_apply: `(effect, event = {}) => {...}`

#### on_remove: `(effect, event = {}) => {...}`

#### on_turn: `(effect, event = {}) => {...}`

If the game turn mechanism is being used this callback will be received on each game turn. This allows an effect to, for example, grow or decline over time.

## <a name="faction-element">Faction</a>

<emph>As of v0.8 faction support is a placeholder. Factions will be fully implemented in a future version.</emph>

Factions represent in-game groups with their own agenda, reputation, and views of others. Define a faction using a `@faction` element.

### Example

    @faction police begin
      ...
    end

    @faction gutman begin
      ...
    end

    @faction player begin
      ...
    end

### Required Attributes
### Optional Attributes

* tags — set of keywords

### Event Handlers

#### on_init: `(faction, event = {}) => {...}`

This script will be called during game initialization and before the game has started.

## <a name="game-element">Game</a>

The game element is the top-level specification of the game and its metadata. It also defines the scebe entry point of the game.

The `@game` element has an implicit ID of `game`. All other elements and directives should be nested inside the top-level `@game`.

### Example

    @game begin
      name: "The Maltese Parrot"
      author_name: "Dachshund Hamlet"
      IFID: "D2050DE2-97A2-1ED1-4CCA-AF9D3B0DD883"
      created: "2022-08-31 22:13:43.830755Z"
      version: 10
      initial_scene: #sam_and_wonderly_meet
    end

### Required Attributes

* name — string
* initial_scene — element-id
* IFID — string

### Optional Attributes

* tags — set of keywords

### Event Handlers

#### on_init: `(game, event = {}) => {...}`

This script will be called during game initialization and before the game has started.

#### on_start: `(game, event = {}) => {...}`

The `on_start` event is triggered right after the Rez framework has initialized
itself and before the first scene or card gets rendered. It's an opportunity
to customise game setup.

#### on_scene_change: `(game, event) => {...}`

    event = {
      scene_id: <id>
    }

The `on_scene_change` script is called whenever a new scene gets started.

The callback happens between the `on_finish` and `on_start` scripts of the scenes that are ending and beginning respectively.

#### on_card_Change: `(game, event = {}) => {...}`

The `on_card_change` script is called whenever a new card is played into the current scene.

The callback happens between the `on_leave` and `on_enter` scripts of the card that is being played.

### API

#### archive()

Returns a JSON string containing the archived state of the game. This is used internally by the save() call.

#### save()

Archives the current game state and triggers a file download of a JSON save game. The file will automatically be named using the game name as a prefix and the date & time as a suffix.

It works by adding the JSON to a `File` object and adding a link to the document link to that `File` and automatically clicking it.

Before the download gets triggered a `save` event is raised allowing the game an opportunity to make changes before state gets archived.

#### load(json)

Retrieves a game state from the passed in JSON and attempts to reload it first checking that it has the same archive_version.

After the state has been reloaded a `load` event is raised giving the game an opportunity to do any necessary work before the player sees the new state.

#### addGameObject(obj)

Adds a game object (one of the RezXXX object types) to the games database. Once an object has been added it becomes available using `$(obj_id)`.

If the object has a `tags` attribute the object will be automatically indexed against its tags and will appear in searches using `getTaggedWith(tag)`.

Note that unlike most other attributes it is inadvisable to use `obj.setAttribute("tag", ...)` to update tags. The `setTags()`, `addTag()` and `removeTag()` functions should be used instead and will automatically keep the game tag-index up to date.

#### getGameObject(id, should_throw = true)

Retrieves the game object with id.

If `should_throw` is true (default: true) then an exception is thrown if the id is not in the game database.

Returns:

`null` if the specified `id` is not in the game database
`ref` reference to the object with id `id`

The compiler attempts to ensure that invalid id references are not used however this cannot be enforced when copies with dynamic ids get made.

#### getRelationship(source_id, target_id)

Returns a relationship from the source object towards the target object.

Returns:

`null` if there is no relationship from source to target
`ref` a `RezRelationship` from source to target

#### getTaggedWith(tag)

Get objects that have the tag.

Returns:

`[]` if there are no objects with the tag
`[...]` array of objects that have the tag

#### getAll(target_type)

Get objects that have the specified target type, e.g. 'actor', 'item', 'scene'.

Returns:

`[]` if there are no objects with this target type
`[...]` array of objects of the target type

#### getCurrentScene()

Get a reference to the current scene.

Returns:

`ref` reference to the current `RezScene`

#### setCurrentScene(new_scene_id)

Transitions from the current scene to a new scene with id `new_scene_id`.

The current scene will receive a call to `finish()` to give it an opportunity to clean up.

The new scene will receive a call to `start()` to indicate it should get ready to render.

#### getTarget(target_id)

This method will probably be deprecated when the renderer gets rewritten.

#### container()

Gets the HTML element that the game is rendered inside.

#### render()

Triggers a render pass.

The current scene is asked to render itself and the resulting content is passed into the game layout template.

The `innerHTML` property of the HTML container is set to this content.

The scene is then given an opportunity to transform links, forms, inputs and so on to add the `rez-live` functionality.

The inner workings of the render method are likely to change when the renderer is rewritten. Do not depend upon them.

#### interludeWithScene(scene_id)

Interrupts the current scene with another scene.

Unlike when the scene is changed with `setCurrentScene` the old scene is expected to be resumed.

The current scene gets a call to `interrupt` to notify it that it is being interrupted and the new scene is started.

Interrupted scenes are held in a stack allowing an interrupted scene to, itself, be interrupted.

Use `resumePrevScene` to return to the last scene in the stack.

#### resumePrevScene()

Use to return to the previous scene after an interruption.

The current scene will receive a call to `finish()` to let it know a scene change is coming.

The last interrupted scene is then made the current scene again and receives a call to `resume()` to let it know that its on stage again.

#### start(container_id)

Used to start the game and tells it which HTML element it should live inside. An author should never need to call this as the framework does this automatically.

#### getEnabledSystems()

Returns a list of `RezSystem` objects that have `enabled: true` and ordered by `priority` with the highest priority system appearing first in the list.

Returns:

`[]` no systems are enabled
`[...]` a list of systems in increasing priority order

#### runTick()

Sends a `tick` event to all enabled systems returned by `getEnabledSystems`.

This area is not yet well thought out but the idea is that a 'tick' represents a unit of game time and probably there is a correspondence between player actions and ticks. After a player has taken an action use `runTick()` to allow the game systems to respond.

For example a system might run actor behaviours, or create items, or whatever your game needs.

There'll probably be more on this in the Cookbook as time goes on. Or maybe the whole thing will get rewritten.

## <a name="group-element">Group</a>

<emph>As of v0.8 the group element is a placeholder for future functionality.</emph>

A group specifies a collection of assets that can be selected from. Groups can be static by defining the id of member assets, or dynamic by specifying a set of tags. In the latter case the group will collect together all assets with any of the specified tags.

A group can be used to select an image at random, or cycle through the collection one-by-one.

### Example
### Required Attributes

* assets — list of element-id
* tags — set of keywords

### Optional Attributes
### Event Handlers

#### on_init: `(group, event = {}) => {...}`

This script will be called during game initialization and before the game has started.

## <a name="inventory-element">Inventory</a>

The `@inventory` element creates a container that can hold `@item`s through the use of `@slot`s. Rez inventories are deliberately flexible to handle a range of use cases for example working memory (where items are thoughts) or spell books (where items are spells).

Rez has a fairly flexible inventory system that is based around 'slots' that define how items can be held. This allows an inventory to hold different kinds of items: you could have an inventory for items as well as an inventory for spells (spell book).

Inventory slots are matched against items to determine whether it's possible to put an item in a slot.

Inventories are defined using the `@inventory` tag.

Inventories have a category which determines the kind of items that can be added to their slots. For example "spell" could represent a spell book, while "equipment" could represent the players inventory.

### Example

    @inventory player_inventory begin
      slots: #{#hat_slot #jacket_slot #trousers_slot #shoes_slot #holster_slot}
    end

### Required Attributes

* slots — set of element-id

### Optional Attributes

* tags — set of keywords

### Event Handlers

#### on_init: `(inventory, event = {}) => {...}`

This script will be called during game initialization and before the game has started.

#### on_insert: `(inventory, event) => {...}`

    event = {
      slot_id: <id>,
      item_id: <id>
    }

This script will be called when an item has been added to the specified slot of this inventory.

#### on_remove: `(inventory, event) => {...}`

    event = {
      slot_id: <id>,
      item_id: <id>
    }

This script will be called after an item has been removed from the specified slot of this inventory.

## <a name="item-element">Item</a>

The `@item` element defines a conceptual item the player the player (or potentially an NPC) can acquire and add to an inventory. Items don't have to represent physical objects but anything a player has for example a spell could be an item or even a memory.

Items are required to have a `type` keyword-attribute that connects them to compatible slots in inventories. That might include a shop, a wardobe, and a players backpack inventories.

However the Item/Inventory system is quite flexible so we can also think about spells as Items with the Inventory being a spell-book, or knowledge as Items with an Inventory being memory.

Items may be usable in which case they may have a limit to the number of times they can be used.

Some items can grant effects, either when the item is acquired, put into a specific slot (e.g. equipped), or when it is used.

The can_equip/on_equip scripts are used to decide whether the player can put an item in a given inventory & slot, and to process what happens when doing so.

For example equipping a magic ring might confer an effect on the player. But first it may be necessary to check that the player doesn't already have a magic ring equipped.

A potion on the other hand confers no effect until it is used and might have only one use after which is presumed to be consumed.

### Example

    @item black_fedora begin
      type: :hat
      description: "black fedora"
      wearable: true
      description: "A Messer wool fedora hat. Classy."
    end

Note that this example throws up a design issue to be aware of: tags and boolean attributes are equivalent. For example `wearable: true` can also be represented by presence or absence of a tag `wearable`. In the case of `Item` elements its further possible to use the type system:

    @derive :wearable :item
    @derive :hat :wearable

In this case an `Item` with `type: :hat` will automatically be tagged as `:wearable` and `:item`.

### Required attributes

* type — keyword — `:hat`
* name: string
* description: string

### Optional attributes

* description — string|heredoc — `"Description"`
* size — number — defaults to 1
* usable — boolean
* uses — number — assumed >= 0
* container — element-id
* on_equip: script
* can_equip: script
* on_use: script
* can_use: script

### Event Handlers

#### on_init: `(item, event = {}) => {...}`

This script will be called during game initialization and before the game has started.

## <a name="location-element">Location</a>

<emph>In v0.8 locations are still a bit of a sketch for future map functionality.</emph>

Locations in Rez are an optional concept that can be used to create a "stage" for one or more scenes. In cases where different scenes may play out in one virtual location it may make sense to use a location to represent what is the same about the background. If scenes and cards get the job done, you don't have to worry about using locations.

Locations are defined using the `@location` tag.

### Example
### Required Attributes
### Optional Attributes
### Event Handlers

#### on_init: `(location, event = {}) => {...}`

This script will be called during game initialization and before the game has started.

## <a name="list-element">List</a>

A list is a named collection of values that can be used by other in-game elements, for example lists of names, locations, actors, and so on. Lists are defined using the `@list` element.

The run-time API supports selecting randomly from lists including with & without replacement.

### Example

    @list antagnoists begin
      content: [#sam_spade #miss_wonderly #kaspar_gutman #joel_cairo]
    end

    @list lines begin
      content: [
        "I distrust a man that says when. If he's got to be careful not to drink to much it's because he's not to be trusted when he does."
        "The cheaper the crook, the gaudier the patter."
        "I couldn't be fonder of you if you were my own son. But, well, if you lose a son, its possible to get another. There's only one Maltese Falcon."
        "What do you want me to do, learn to stutter?"
      ]
    end

### API

#### randomElement()

  `list.randomElement()`

  Return a random element of the list.

#### nextForCycle()

  `list.nextForCycle(key)`

  Cycles through the list element by element. Each cycle is identified by a key.

#### randomUnique()

  `list.randomUnique(key)`

  Returns a random element of the list without repeating elements. Each random
  walk is idenfied by a key.

### Required Attributes
### Optional Attributes

* tags — set of keywords

### Event Handlers

#### on_init: `(list, event = {}) => {...}`

This script will be called during game initialization and before the game has started.

## <a name="object-element">Object</a>

An `@object` element describes an author-driven concept. Isn't everything in
Rez an object of some kind? Yes, but elements like `@author`, `@item`, and
`@plot` have built-in meaning and functionality. By contrast `@object` is a
blank canvas that an author can use for anything they think of.

### Example

Imagine we are building a role-playing game and we want to introduce the notion
of classes and skills. Rez does not provide these concepts out of the box. So
we can use `@object` (and, optionally, `@alias`) to this ourselves.

    @alias class = object # begin
      description: "A class for players and NPCs"
    end

    @alias skill = object # begin
      template: true
      description: "Something an actor has learned how to do"
      min: 0
      max: 5
      level: 0
    end

    @alias perk = object # begin
      description: "Represents a class based bonus to skills and stats"
    end

    @alias stat = object # begin
      template: true
      description: "Represents how good or bad someone is at doing things"
      min: 3
      max: 18
      level_gen: 3d6
      level: &level_gen
    end

    @class detective begin
      description: "Detectives are savvy at following clues and untangling mysteries."
      primary_stat: #perception
      perk: #gun_license
      skills: #{#puzzling #gunplay #drinking}
    end

    @class hood begin
      description: "Hoods supply the muscle and take care of problems."
      primary_stat: #toughness
      perk: #dont_go_down_easy
      skills: #{#gunplay #fisticuffs #intimidate}
    end

    @class dame begin
      description: "Dames are trouble"
      primary_stat: #charisma
      perk: #beguile
      skills: #{#evade #fast_talk #scheming}
    end

    @perk gun_license begin
      description: "Without this cops might pick you up for flashing your lead pumper."
      ...
    end

    @perk dont_go_down_easy begin
      description: "Takes more than a bullet to put you down."
      ...
    end

    @perk beguile begin
      description: "One look into your eyes and they're putty in your hands."
      ...
    end

    @skill puzzling begin
      description: "Figuring out how the clues fit together."
    end

    @skill gunplay begin
      description: "Shooting straight, esp. when it matters."
    end

    @skill drinking begin
      description: "Hold your liquour, yes sir!"
    end

    @skill fisticuffs begin
      description: "Marquis of Queensbury be damned, hit 'em where it hurts."
    end

    @skill intimidate begin
      description: "You don't actually **need** to shoot 'em."
    end

    @skill evade begin
      description: "Never be in the wrong place at the wrong time."
    end

    @skill fast_talk begin
      description: "They'll think it was you doing a favour for them!"
    end

    @skill scheming begin
      description: "They'll never see it coming."
    end

    @stat perception begin
      description: "Notice what others don't."
    end

    @stat toughness begin
      description: "Take a licking and keep on ticking."
    end

    @stat charisma begin
      description: "Charm their socks off."
    end

Now we can make use of our classes in-game:

    @actor player begin
      class: #detective
    end

Rez itself knows nothing about classes and detectives but your in-game code
(scripts and behaviour tasks) can make use of the referenced objects &
attributes.

In this example `@perk` could have been a tag of some kind but we imagine that
there may be perk-specific data or event handlers in a real use case.

Note that we have set `template: true` on `@skill` and `@stat` reflecting that
we probably want to create a copy of the object for each actor in particular,
rather than them sharing the original (in this example the `level` attribute
would could change as the game progresses).

Note that because Rez doesn't know the "shape" of your custom objects it cannot
validate them or their attributes. Extra care should be taken here that they
are well-formed.

## <a name="plot-element">Plot</a>

<emph>As of v0.8 the plot element is mainly a placeholder for future functionality.</emph>

### Example
### Required Attributes

* priority

### Optional Attributes

* tags — set of keyword

### Event Handlers

#### on_init: `(plot, event = {}) => {...}`

This script will be called during game initialization and before the game has started.

## <a name="relationship-element">Relationship</a>

A `@rel` (short for relationship) element describes the relationship between two
in-game elements (typically actors and factions but you could imagine reasons
why it could be items or locations).

A relationship has a source (the thing that has the relationship), target
(the object of the relationship), and affinity (that describes the nature of
the relationship).

Affinities range from -5.0 to +5.0 where 0.0 is considered to be
a neutral relationship. The meaning of -5.0 is assumed to be "source hates the
target" and +5.0 to be "source loves the target" but it is up to the game to
definte its own meanings for the value.

Of course relationships can be extended with other game-specific attributes and
tags can be used to enhance a relationship, for example you could apply tags
like "partner", "husband", "lover", or "rival" to specify a relationship more
completely.

To keep the number of relationships manageable it may be preferable to setup
relationships between [Factions](#faction-element) rather than specific actors
as demonstrated in the examples below. However you can setup relationships in
any combination you like.

**Note:** the `@rel` element does not allow the author to specify an id. All
relationships have an automatically generated id based on the source & target
attributes. It is specified as:

    rel_<source id>_<target id>
    rel_player_gutman

The `getRelationship(source, target)` API on the `RezGame` object is a short-
hand for doing this lookup manually.

### Example

In these examples we are using faction-to-faction relationships.

    @rel begin
      source: #player_faction
      target: #gutman_faction
      affinity: -2.0
    end

    @rel begin
      source: #gutman_faction
      target: #player_faction
      affinity: 0
    end

    @rel begin
      source: #player_faction
      target: #wannalee_faction
      affinity: +2.5
    end

    @rel begin
      source: #wannalee_faction
      target: #player_faction
      affinity: +4.0
    end

### Required Attributes

* `source` — element ref of the element that holds the relationship
* `target` - element ref of the element on which the relationship is held
* `affinity` - number ranging from -5.0 to +5.0 indicating the strength of the relationship

### Optional Attributes

* `tags` — set of tags

### Event Handlers

#### on_init

    on_init: (relationship, event) => {...}

    event = {}

#### on_change_affinity

    on_change_affinity: (relationship, event) => {...}

    event = {
      prior: previous affinity value,
      current: updated affinity value
    }

This event handler will be called whenever the relationship affinity changes and
will be passed the prior & new affinity values.

### API

* `getAffinity()`
* `setAffinity(new_affinity)`
* `alterAffinity(change)`

## <a name="scene-element">Scene</a>

A Game in Rez is authored in terms of `@scene`s and `@card`s. Each `@card` represents some content that is presented to the player. By contrast the `@scene` represent the structure and intelligence about which `@card`s to present and how to respond to player input.

If you are familiar with Twine then a `@card` is roughly equivalent to a Twine passage. A Twine game is one long stream of passages woven together. Rez differs from Twine in that it uses the `@scene` to organise how the player interacts with the game and which/how the content is presented.

For example you might use different scenes for moving around the map, examining items, interacting with NPCs, buying from shops, and so on. You don't have to, you could implement the game in a single scene, but the different layout and event handling possibilities make it easier.

A `@scene` requires an `initial_card: #card_ref` attribute that identifies the card that will be rendered when the scene begins. Additionally it requires a `layout:` attribute that specifies the surrounding markup.

Within the layout using the `{{{content}}}` macro to specify where scene content is inserted.

A `@scene` requires a `layout_mode:` attribute which must be either `:single` or `:continuous`. In the `:single` layout mode only a single `@card` is ever displayed. While in `:continuous` mode each new `@card` is layed out after the previous one.

Lastly a `@scene` may optionally have a `blocks: [#card_id_1 #card_id_2 ...]` attribute. Each referenced `@card` will be rendered and it's content can be inserted into the layout using `{{{card_id_1}}}`, `{{card_id_2}}`, etc.

### Example

    @scene introduction begin
      title: "Introduction"
      initial_card: #intro_part_1
      blocks: [#sidebar_1 #sidebar_2]
      layout_mode: :single
      layout: """
        <div class="sidebar">
          {{{sidebar_1}}}
          {{{sidebar_2}}}
        </div>
        <div>
          {{{content}}}
        </div>
      """
      on_new_card: (game, evt) => {...}
    end

### Required Attributes

* title — string
* initial_card — element-id
* layout_mode — keyword — one of `:single` or `:continuous`
* layout — string|heredoc

### Optional Attributes

* tags — set of keyword
* blocks — list of element-id
* bindings — list of element-id

## Event Handlers

Scenes support a range of events:

#### on_init: `(scene, event = {}) => {...}`

The `on_init` script is called during game initialization and before the player has been able to take any actions. It will be passed an empty map of arguments.

#### on_start: `(scene, event) => {...}`

    event = {
      card_id: <id>
    }

The `on_start` script is called when a new scene is started. It will receive a map containing the scene_id.

#### on_finish: `(scene, event = {}) => {...}`

The `on_finish` script is called when a scene has eneded.

#### on_interrupt: `(scene, event = {}) => {...}`

The `on_interrupt` script is called when a scene is being interrupted by an interlude.

#### on_resume: `(scene, event = {}) => {...}`

The `on_resume` script is called when a scene is being resumed after an interlude.

#### on_render: `(scene, event = {}) => {...}`

The `on_render` script is called every time the scene is being rendered.

#### on_start_card: `(scene, event) => {...}`

    event = {
      card_id: <id>
    }

The `on_start_card` script is called when a new card is played into the scene. It will be passed a map containing the id of the card that has been played.

#### on_finish_card: `(scene, event) => {...}`

    event = {
      card_id: <id>
    }

The `on_finish_card` script is called when when a card has 'finished' as a new card is being played into the scene. It will be passed the id of the card that is finished.

## <a name="script-directive">Script</a>

A script is used to include arbitrary Javascript code into the compiled game. Specify a script using the `@script` directive.

The `@script` directive consists of a string containing the code to include between `begin` and `end` markers. Note that the Javascript code should not include the term "end" as this will cause the parser to fail. In a future version a more robust approach will be included.

The code defined in the game's `@script` directives will be automatically included as &lt;script&gt; tags before the end of the &lt;body&gt; element of the generated HTML template.

## Example

    @script begin
      function customFunction() {
        // Javascript code here
      }
    end

## <a name="slot-element">Slot</a>

A `@slot` describes a component of an `@inventory` so that an inventory can hold different types of things.

For example an inventory representing what a player is wearing might have slots for coats, trousers, and so forth while an inventory representing a spell book might have slots for different levels of spell.

### Example

    @slot holster_slot begin
      accepts: :pistol
    end

### Required Attributes

* `name` — string
* `accepts` — keyword

### Optional Attributes

* `tags` — set of keyword — tags applied to the slot
* `capacity` — number — the sum of the size of items that fit in the slot

### Event Handlers

#### on_init: `(slot, event = {}) => {...}`

This script will be called during game initialization and before the game has started.

#### on_insert: `(slot, event) => {...}`

    event = {
      inventory: <id>,
      item: <id>
    }

When an `@item` is placed into a `@slot` the `on_insert` event handler will be called.

    on_insert: (inventory_id, item_id) => {
      // Do something
    }

#### on_remove: `(slot, event) => {...}`

    event = {
      inventory_id: <id>,
      item_id: <id>
    }

When an `@item` is taken out of an inventory `@slot` the `on_remove` event handler will be called.

    on_remove: (inventory_id, item_id) => {
      // Do something
    }

## <a name="style-directive"></a>Style

A style is used to include arbitrary CSS into the compiled game. Specify a style using the `@style` directive.

The `@style` directive consists of a string containing the CSS to include between `begin` and `end` markers. Note that the Javascript code should not include the term "end" as this will cause the parser to fail. In a future version a more robust approach will be included.

The styles defined in the game's `@style` directives will be automatically included as &lt;style&gt; tags before the end of the &lt;head&gt; element of the generated HTML template.

### Example

    @style begin
      .card {
        /* My custom styles here */
      }
    end

### Required Attributes

* styles — string

### Optional Attributes
### Event Handlers

## <a name="system-element">System</a>

The `@system` element describes an in-game author defined __system__ that can query and update the game state on every game tick (that is, whenever the `runTick` method is called a the `RezGame` instance).

### Example

    %% Here is a system that maintains wall clock time, advancing the clock
    %% by one hour on each game tick. It also maintains a description of the
    %% hour in terms of morning, afternoon, etc…

    @system clock_system begin
      enabled: true
      priority: 1

      wallTime: 0
      description: ""

      on_tick: (system, evt) => {
        let wallTime = system.getAttributeValue("wallTime");
        let description;
        wallTime += 1;
        if(wallTime > 18) {
          description = "evening";
        } else if(wallTime > 12) {
          description = "afternoon";
        } else if(wallTime > 6) {
          description = "morning";
        } else {
          description = "night";
        }
        game.setAttribute("wallTime", wallTime);
        game.setAttribute("description", description);
      }
    end

### Required Attributes

* `enabled` — if false, this system will not be run
* `priority` — systems are run in priority order

### Optional Attributes

### Event Handlers

#### on_init: `(system, event = {}) => {...}`

This script will be called during game initialization and before the game has started.

#### on_tick: `(system, event = {}) => {...}

As long as the system `enabled` attribute is `true` this script will be called every time the `RezGame` method `runTick` is called.

## <a name="task-element">Task</a>

Tasks are elements that describe components of a behaviour tree. Author defined tasks are usually __conditions__ (that test the state of the game) and __actions__ (that change the state of the game). The built in tasks provided in the stdlib are __composites__ (that work on groups of tasks) and __decorators__ (that modify the meaning of other tasks)

Note that, by convention, we use UPPER CASE ids for task elements.

The core of the task is the execute attribute which implements the functionality of the task and returns a value indicating success or failure. Optionally a task can update the working memory that is passed through the tree as it gets executed.

### Example

    @task ACTOR_IN begin
      options: [:actor :location]

      execute: (task, wmem) => {
        const actor_id = task.option("actor");
        const actor = task.$(actor_id);
        const location_id = task.option("location");
        if(actor.getAttributeValue("location") == location_id) {
          return {success: true, wmem: wmem};
        } else {
          return {success: false, error: "Actor is not in location", wmem: wmem};
        }
      }
    end

In this example we have defined a condition task to test whether a specified actor is in a given location. This could be used in a sequence to ensure that an action only gets performed if in the correct location.

    ^[SEQUENCE [
      [ACTOR_IN actor=sam_spade location=sams_office]
      [ACTOR_RELOADS item=sams_gun]]]

### Required Attributes

* options

A list of keywords describing the options that this behaviour uses. If there are no options use the empty list `[]`

* execute

A script attribute that is expected to take two parameters `task` (a reference to the task itself) and `wmem` which is a reference to a map of "working memory" that can be used to record task state or pass state between tasks.

The return value must either be `{success: true, wmem: wmem}` or `{success: false, error: "Message", wmem: wmem}`.

### Optional Attributes

* min_children
* max_children
* check_*

## <a name="zone-element">Zone</a>

<emph>As of v0.8 zones are mainly a placeholder for future functionality.</emph>

A `@zone` element defines a map zone, a region in which locations are logically grouped together.

For example a zone could represent a planet, a building, a street, or a shopping mall with locations defining specific areas of each.

The idea is that locations in the same zone can be reached easily while locations in different zones may require a specific transition.

For example a player can walk between locations in the "downtown" zone but might need to use a cab to reach the connected "suburbs" zone. A cab rank location in each zone could act as the gateway to the other zones and their locations.

Individual locations must be defined in a zone. If you don't require multiple zones just create a single zone and define all your locations in it.

### Example

    @zone docks begin
      @location la_paloma_gangway begin
        ...
      end

      @location la_paloma_bridge begin
        ...
      end

      @location docks_cabrank begin
        ...
      end
    end

    @zone spade_and_archer begin
      @location street_cabrank begin
        ...
      end

      @location hallway begin
        ...
      end

      @location outer_office begin
        ...
      end

      @location sams_office begin
        ...
      end
    end

### Required Attributes
### Optional Attributes
### Event Handlers

#### on_init: `(zone, event = {}) => {...}`

This script will be called during game initialization and before the game has started.

# <a name="task_catalog">Task Catalog</a>

* <a href="#task_sequence">`SEQUENCE`</a>
* <a href="#task_select">`SELECT`</a>
* <a href="#task_selectp">`SELECT_P`</a>
* <a href="#task_loop">`LOOP`</a>
* <a href="#task_loop_until">`LOOP_UNTIL`</a>
* <a href="#task_maybe">`MAYBE`</a>
* <a href="#task_either">`EITHER`</a>
* <a href="#task_random_choice">`RANDOM_CHOICE`</a>
* <a href="#task_random_each">`RANDOM_EACH`</a>
* <a href="#task_invert">`INVERT`</a>
* <a href="#task_always">`ALWAYS`</a>
* <a href="#task_never">`NEVER`</a>
* <a href="#task_succeed">`SUCCEED`</a>
* <a href="#task_fail">`FAIL`</a>

## <a name="task_sequence">`SEQUENCE`</a>

The `SEQUENCE` task takes two or more children and when executed will execute its children in turn. If any child fails then `SEQUENCE` will stop at that point and fail. If all the children suceeed then `SEQUENCE` will succeed.

## <a name="task_select">`SELECT`</a>

The `SELECT` task takes two or more children and when executed will execute its children in turn. If a child succeeds then `SELECT` will immediately stop executing and succeed. If all the children fail then `SELECT` will fail.

## <a name="task_selectp">`SELECT_P`</a>

The `SELECT_P` task is a variant on `SELECT`. It takes a probability option `p` and before executing any child will test `p`. If the test succeeds it will execute that child and task similar to `SELECT`. If no children get executed or all the children fail then `SELECT_P` will fail.

### Options

* `p` — (1-100) — of any given child getting executed

## <a name="task_loop">`LOOP`</a>

The `LOOP` task takes one child and executes it a number of times specified by the option `count`. If the child should fail then `LOOP` fails. If the child succeeds each time then `LOOP` succeeds.

### Options

* `count` — positive integer — number of times to execute the child

## <a name="task_loop_until">`LOOP_UNTIL`</a>

The `LOOP_UNTIL` task takes one child and attempts to execute it a number of times specified by the option `attempts`. If the child succeeds then `LOOP_UNTIL` succeeds. If the child never succeeds then `LOOP_UNTIL` fails.

### Options

* `attempts` — positive integer — number of attempts to execute the child

## <a name="task_maybe">`MAYBE`</a>

The `MAYBE` task takes one child and based on a probability option `p` decides whether to attempt to execute it or not. If the `p` test succeeds the child gets executed and `MAYBE` will succeed or fail based on whether the child succeeds or fails. If the `p` test fails then `MAYBE` fails.

### Options

* `p` — (1-100) — of the child being executed

## <a name="task_either">`EITHER`</a>

The `EITHER` task takes two children and based on the probability option `p` decides whether to execute the first or the second child. If the `p` test succeeds then the first child is executed, otherwise the second child is executed. `EITHER` succeeds or fails based on whether the child it executes succeeds or fails.

### Options

* `p` — (1-100) — of the first child getting executed

## <a name="task_random_choice">`RANDOM_CHOICE`</a>

The `RANDOM_CHOICE` task takes at least two children and executes one child at random. If the child succeeds then `RANDOM_CHOICE` succeeds, otherwise it fails.

## <a name="task_random_each">`RANDOM_EACH`</a>

The `RANDOM_EACH` task takes at least two children and executes one child at random. `RANDOM_EACH` succeeds or fails based on the selected child succeeding or failing.

Once a child has been executed it is not eligible to be selected again until all the other children of `RANDOM_EACH` have, likewise, been executed. When all the children have been executed `RANDOM_EACH` will begin again with a new random order of children.

## <a name="task_invert">`INVERT`</a>

The `INVERT` task takes one child and executes it. If the child succeeds then `INVERT` fails, likewise if the child fails then `INVERT` will succeed.

## <a name="task_always">`ALWAYS`</a>

The `ALWAYS` task takes one child and executes it. It ignores whether the child succeeds or fails and always suceeds itself.

## <a name="task_never">`NEVER`</a>

The `NEVER` task takes one child and executes it. It ignores whether the child succeeds or fails, always failing itself. It's a shorthand for `[INVERT [ALWAYS ...]]`.

## <a name="task_succeed">`SUCCEED`</a>

The `SUCEED` task takes no chilren and when executed it always succeeds.

## <a name="task_fail">`FAIL`</a>

The `FAIL` task takes no children and when executed it always fails.

# API Reference

* <a href="#object_prototype">Object.prototype</a>
* <a href="#array_prototype">Array.prototype</a>
* <a href="#string_prototype">String.prototype</a>
* <a href="#set_prototype">Set.prototype</a>
* <a href="#rez_object">`basic_object`</a>
* <a href="#rez_actor">`RezActor`</a>
* <a href="#rez_asset">`RezAsset`</a>
* <a href="#rez_card">`RezCard`</a>
* <a href="#rez_decision">`RezDecision`</a>
* <a href="#rez_die">`RezDie`</a>
* <a href="#rez_dynamic_link">`RezDynamicLink`</a>
* <a href="#rez_effect">`RezEffect`</a>
* <a href="#rez_faction">`RezFaction`</a>
* <a href="#rez_game">`RezGame`</a>
* <a href="#rez_inventory">`RezInventory`</a>
* <a href="#rez_item">`RezItem`</a>
* <a href="#rez_list">`RezList`</a>
* <a href="#rez_plot">`RezPlot`</a>
* <a href="#rez_scene">`RezScene`</a>
* <a href="#rez_slot">`RezSlot`</a>
* <a href="#rez_system">`RezSystem`</a>
* <a href="#rez_zone">`RezZone`</a>

## <a name="object_prototype">`Object.prototype`</a>

### `copy()`

The `copy()` method returns a copy of `this` object.

### `isGameObject()`

Determines whther is object is a game-object derived from an @element.

## <a name="rez_object">`basic_object`</a>

The `basic_object` object is a prototype for all game objects representing game elements. You likely won't interact with it directly unless you are implementing a new game element or working on the Rez Stdlib but it provides a number of helper methods to the game objects you are likely to interact with in an event handler.

### `init()`

This method is automatically called by the runtime and initialises the object.

It also calls the "on_init" handler if one has been implemented.

### `initRefAttributes()`

This method initializes ref attributes (of the form `&attribute` where attribute is assumed to be a function or dice roll). It is called automatically from `init()` and not intended to be called directly by authors.

### `elementInitializer()`

The `elementInitializer()` method is called by `init()` after `initRefAttribute()` so all attributes can be assumed to have a value. Objects with `__basic_object__` as their prototype can use this to provide their own custom initialization.

### `$(obj_id)`

Returns:

`ref` — reference to the object with the given id

Raises: if the given object id cannot be resolved

The `$` method is a shortcut to the metho of the same name in the `RezGame` instance this object is related to.

### `copyAssigningId(obj_id)`

Returns a copy of this object and gives the copy the specified id.

It creates a copy of the attributes of `this` and calls the relevant constructor function with the copied attributes and specified id. It then calls the `copy` event on the copy passing a map `{original: this}`. Then it sets the `copy_of` attribute of the copy to `this.id`. Lastly it calls `init()` on the copy.

### `copyWithAutoId()`

Automatically generates an id and then calls `copyAssigningId(obj_id)` with it.

### `willHandleEvent(event_name)`

Determine whether this object has a handle for the given event. Handlers are named "on_<event_name>".

### `runEvent(event_name, evt_info)`

Runs the handler for the given event passing `evt_info` along. It's expected that `evt_info` be a map.

### `getIn(path)`

Returns a nested attribute value. For use with tables.

The path is a string where segments of the path are separated by ".". The first segment must be the name of a table attribute. Further segments are used to look inside the structure of the table.

    @object wizard begin
      spells: {fire: {fireball: 0
                      cone_of_flame: 1}
              {earth: {stone_skin: 1
                       earthquake: 0}
              {water: {water_breathing: 0
                       create_water: 1}
              {air: {thunder: 1
                     static: 1}}}}}
    end

To retrieve the level of the stone_skin spell you could use

    $("wizard").getIn("spells.earth.stone_skin")

### `hasAttribute(name)`

Determines whether this object has an attribute with the given name.

### `getAttribute(name)`

Returns the attribute with the given name. For simple attribute types this is the value of the attribute however for functions and dice rolls you'll have to make an additional call. See `getAttributeValue()`.

### `getAttributeValue(name)`

Returns the value of the attribute with the given name. In the case of functions and dice rolls this will be the value of calling the function or rolling the dice.

### `setAttribute(name, value)`

Sets the value of the named attribute and tracks that this attribute has been changed.

### `putIn(path, value)`

Sets a nested value in a table attribute. See the example for `getIn(path)`:

    $("wizard").putIn("spells.air.thunder", 2)

This modifies the table attribute and stores the new value, tracking the change.

### `incAttribute(name, amount = 1)`

For a numeric attribute `name` increase its value by the specified amount.

### `decAttribute(name, amount = 1)`

For a numeric attribute `name` decrease its value by the specified amount.

### `applyEffect(effect_id, item_id)`

For elements that can be the target of effects add the specified effect coming from the specified item.

This method is intended to be overridden by objects with this prototype to supply the required behaviour.

### `removeEffect(effect_id, item_id)`

For elements that can be the target of effects remove the specified effect coming from the specified item.

This method is intended to be overridden by objects with this prototype to supply the required behaviour.

### `needsArchiving()`

Determines whether this object is the subject of changes that mean that it needs to be archived.

### `archiveDataContainer()`

Returns a data container into which this object can be archived.

### `dataWithArchivedAttributes(data)`

Annotates the `data` argument with a serialized version of the changed attributes of this object.

### `dataWithArchivedProperties(data)`

Annotates the `data` argument with a serialized version of the archivable properties of this object.

### `toJSON()`

Convert the object to a JSON representation of changed attributes and archivable properties.

### `loadData(data)`

Load attributes and properties of this object from the supplied `data`.

### `isGameObject(obj)`

## <a name="rez_actor">RezActor</a>

`RezActor` is the runtime counterpart of the authoring element `@actor`.

### `checkItem(inventory_id, slot_id, item_id)`

Called to check whether the actor accepts the given object into the specified inventory & slot.

Passes a `RezDecision` (default: yes) to an `accept_item` event handler defined by the actor.

### `move(location_id)`

Moves the actor to a new location.

If the actor is on-stage it moves them out of the current location.

If the actor was in a previous location they receive an event `leave:{location: <old_location_id>}` and the location receives an event `actor_leaves:{actor_id: <id>}`.

After moving the actor receives an event `enter:{location: <new_location_id>}` and the new location receives `actor_enters:{actor_id: <id>}`.

## <a name="rez_asset">RezAsset</a>

`RezAsset` is the runtime counterpart of the authoring element `@asset`.

### `tag()`

Depending upon whether the asset is an image, audio, or video file returns an appropriately formatted HTML tag for including it.

### `assetType()`

Determines the major MIME type, e.g. for "image/jpg" returns "image" or found "video/mp4" returns "video".

### `isImage()`

Determines if the asset is an image file.

### `isAudio()`

Determines if the asset is an audio file.

### `isVideo()`

Determines if the asset is a video file.

### `isText()`

Determines if the asset is a text file.

### `getDimensions()`

For image assets returns its dimensions formatted appropriate for including within a CSS style.

### `audioTag()`

Return an audio element tag. **Not implemented**

### `imageTag()`

Returns an image element tag.

### `videoTag()`

Return a video element tag. **Not implemented**

## <a name="rez_card">RezCard</a>

### `incRenderId()`

Used to disambiguate different renderings of the same card.

### `renderBlocks()`

Returns a map containing a rendering of all the cards whose id is listed in the "blocks:" attribute of the card.

### `customBindings()`

Returns a map containing the results of evaluating all of the bindings listed in the "bindings:" attribute of the card.

### `render()`

Returns the fully-evaluated markup after rendering the card. This is usually composed by the scene as part of its layout.

`RezCard` is the runtime counterpart of the authoring element `@card`.

## <a name="rez_decision">RezDecision</a>

### `new RezDecision(purpose, data = {})`

Return a new `RezDecision` object with the given purpose (why a decision is being made) and a map of associated decision information.

### `yes()`

Call `yes()` on a decision to set the decision value to `true`.

### `default_yes()`

Call `default_yes()` on a decision before passing it. If the callee doesn't assign a decision value then it will default to `true`.

### `no(reason = "none given")`

Call `no(reason)` on a decision to set the decision value to `false` and assign a reason for the decision not being aproved.

### `default_no()`

Call `default_no()` on a decision before passing it. It the callee doesn't assign a decision value then it will default to `false`.

### `wasMade()`

If one of `default_yes()` or `default_no()` is called on the decision. Or the callee uses one of `yes()` or `no()` then this will return true. Otherwise it will return false.

### `usedDefault()`

Return `true` the decision result came from a `default_yes()` or `default_no()`.

### `data()`

Returns the map of data associated with the decision.

### `setData(key, value)`

Adds a key/value pair to the associated decision information.

### `result()`

Return the decision result, `true`|`false`.

### `purpose()`

Returns the purpose string associated with the decision.

### `reason()`

Return the reason given when either `default_no(reason)` or `no(reason)` are called.

## <a name="rez_die">RezDie</a>

## new RezDie(count, sides, modifier = 0)

Return a new `RezDie` representing a die roll of a specified number of n-sided dice with an optional +/- modifier.

    new RezDie(3, 6) — 3d6+0
    new RezDie(2, 8, -1) - 2d8-1

### `between(min, max`)`

Returns a random number between `min` and `max` inclusive.

    between(1, 6) — random number 1-6

### `die()`

Return a random value based on the number of sides of the die.

### `roll()`

Returns a random value based on a complete die roll.

    die = new RezDie(3,6)
    die.roll — value between 3 and 18

## <a name="rez_dynamic_link">RezDynamicLink</a>

* `allow(response, target_id)`
* `deny(text, as_link)`
* `hide()`

## <a name="rez_effect">RezEffect</a>

`RezEffect` is the runtime counterpart of the authoring element `@effect`.

## <a name="rez_faction">RezFaction</a>

`RezFaction` is the runtime counterpart of the authoring element `@faction`.

## <a name="rez_game">RezGame</a>

`RezGame` is the runtime counterpart of the authoring element `@game`.

* `save()`
* `load(json)`
* `addGameObject(obj)`
* `getGameObject(id)`
* `getAll(target_type)`
* `getCurrentScene()`
* `setCurrentScene(new_scene_id)`
* `getTarget(target_id)`
* `container()`
* `interludeWithScene(interlude_scene_id)`
* `resumePrevScene()`

## <a name="rez_inventory">RezInventory</a>

`RezInventory` is the runtime counterpart of the authoring element `@inventory`.

* `slots()`
* `slotIsOccupied(slot_id)`
* `getContentsForSlot(slot_id)`
* `appendContentToSlot(slot_id, item_id)`
* `setContentsForSlot(slot_id, contents)`
* `countItemsInSlot(slot_id)`
* `isOwned()`
* `ownerId()`
* `owner()`
* `itemFitsInSlot(slot_id, item_id)`
* `slotAcceptsItem(slot_id, item_id)`
* `canAddItemForSlot(slot_id, item_id)`
* `addItemToSlot(slot_id, item_id)`
* `removeItemFromSlot(slot_id, item_id)`

## <a name="rez_item">RezItem</a>

`RezItem` is the runtime counterpart of the authoring element `@item`.

### API

* `size()`

## <a name="rez_list">RezList</a>

`RezList` is the runtime counterpart of the authoring element `@list`.

### API

* `nextForCycle(cycle_id)`
* `randomElement()`
* `randomWalk(walk_id)`
* `resetWalk(walk_id)`
* `values()`

## <a name="rez_plot">RezPlot</a>

`RezPlot` is the runtime counterpart of the authoring element `@plot`.

### API

* `isActive()`
* `isComplete()`
* `tick()`

## <a name="rez_scene">RezScene</a>

`RezScene` is the runtime counterpart of the authoring element `@scene`. Its main responsibility is to manage one or more `RezCard` objects representing `@cards` as they are played into the scene.

### API

* `getCurrentCard()`
* `getInitialCard()`
* `playCardWithId(<card_id>)`
* `reset()`

## <a name="rez_slot">RezSlot</a>

`RezSlot` is the runtime counterpart of the authoring element `@slot`.

### API

* `capacity()`

## <a name="rez_system">RezSystem</a>

`RezSystem` is the runtime counterpart of the authoring element `@system`.

## <a name="rez_zone">RezZone</a>

`RezZone` is the runtime counterpart of the authoring element `@zone`.

### API

* `addLocation(location)`
* `getLocation(location_id)`
