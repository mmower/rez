# Rez

A language, compiler, and runtime system for creating interaction fiction games with HTML

By Matt Mower <self@mattmower.com>

* Version 0.9 — 13 Nov 2022
* Version 0.8 — 24 Oct 2022

## Intro

Rez is a tool for writing interactive fiction games with HTML, that is games that are constructed from HTML markup, images, movies, and sounds. Typically, most of a players interaction with a these game is through clicking links that represent the actions the player can take.

To write a game with Rez you create one or more `.rez` source files containing the definition of the game. The rez compiler then translates these into HTML+ javascript+assets required to play the game in the browser.

A Rez game is written using the Rez language which is mostly declarative with Javascript callbacks used to implement game-specific behaviours. Even an author with limited Javascript ability can go far with Rez.

It might be fair to think of Rez as a kind of [Twine](https://twinery.org/) on steroids. Twine describes itself as an "open source tool for telling interactive, nonlinear stories." Rez aims to be for HTML-based hypermedia games what Twine is for interactive story-telling.

Where Twine really shines is in making it relatively easy for non-developers to get started. By constrast, at the cost of shutting out those who aren't willing to learn a little Javascript and adding some (hopefully justified) complexity, Rez offers a much richer toolkit and should shine when creating games, rather than stories.

There are other tools such as Ink, Dialog, Inform, and TADS that can, to a greater or lesser extent solve the same problems as Rez however they each came with compromises I was unwilling to make, for example being Z-machine based or depending on a parser.

The ideal Rez user right now is probably creating a game that is ambitious for Twine, is probably using a Twee compiler rather than the Twine visual editor, and is not afraid of writing some Javascript code.

## Installation

Rez is written in the Elixir programming language and requires both Elixir and Erlang to be installed.

Rez uses Handlebars.js for it's template language and requires the Handlebars
compiler to be available on the system path for converting templates during game
compilation.

https://handlebarsjs.com/installation/

Rez was written expecting Handlebars.js v4.7.7 and is not tested with any other
version.

### MacOS

    download latest rez escript binary
    brew install erlang
    brew install elixir
    npm install -g handlebars

### Other OS

    I'm hoping users of other platforms will give me the steps required to get it working for their platform.

## Usage

### Creating A New Game

To create a new game:

    rez new <game-name> --author-name="My name" --author-email="My email" --game-title="What my game is called" --game-homepage="URL for more info about my game"

This creates a new game directory with the same name as the game name and populates it with a template game and its dependencies.

### Compiling

A Rez game is compiled into a set of HTML, Javascript, and CSS files that represent the game.

From the game directory:

    rez compile src/<file.rez>

This will build the game in the `dist` folder including assets (such as audio or image files).

The resulting files can be archived for distribution either hosted on a server or potentially turned into an Eletron application.

Note that, at present, no attempt is made to minimise or optimise the resulting JS or CSS assets.
