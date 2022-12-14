# Rez

A language, compiler, and runtime system for creating interaction fiction games with HTML

By Matt Mower &lt;self@mattmower.com&gt;

* Version 0.9 — 13 Nov 2022
* Version 0.8 — 24 Oct 2022

## Intro

Rez is a tool for creating HTML-based interactive fiction games.

What do we mean by that? It's for games that are made using HTML markup, images, movies, and sounds where players interact through clicking links representing actions they can take.

Simpler examples of such games are choice based stories for which many authors use [Twine](https://twinery.org/). Rez is designed for a slightly more technical audience that want to create more ambitious games.

Rez offers: asset management, actors & behaviours (both through Javascript callbacks and AI behaviour trees), items & inventory management, maps & locations, factions & relationships, scenes, plots, systems, and more.

Rez uses a flexible template-based rendering system with a scene/card system that makes it easy to create any interface you want. It includes the [Bulma](https://bulma.io/) CSS framework and [Alpine.JS](https://alpinejs.dev/) for modern layout and dynamic UI and uses [Handlebars](https://handlebarsjs.com/) for dynamic content.

See the [online documentation](https://github.com/mmower/rez/blob/main/docs/REZ.md) for a complete description of the language and runtime.

## Getting Started

To write a game with Rez you create one or more `.rez` source files containing the definition of the game. The rez compiler then translates these into HTML+ javascript+assets required to play the game in the browser.

A Rez game is written using the Rez language which is mostly declarative with Javascript callbacks used to implement game-specific behaviours. Even an author with limited Javascript ability can go far with Rez.

It might be fair to think of Rez as a kind of [Twine](https://twinery.org/) on steroids. Twine describes itself as an "open source tool for telling interactive, nonlinear stories." Rez aims to be for HTML-based hypermedia games what Twine is for interactive story-telling.

Where Twine really shines is in making it relatively easy for non-developers to get started. By constrast, at the cost of shutting out those who aren't willing to learn a little Javascript and adding some (hopefully justified) complexity, Rez offers a much richer toolkit and should shine when creating games, rather than stories.

There are other tools such as Ink, Dialog, Inform, and TADS that can, to a greater or lesser extent solve the same problems as Rez however they each came with compromises I was unwilling to make, for example being Z-machine based or depending on a parser.

The ideal Rez user right now is probably creating a game that is ambitious for Twine, is probably using a Twee compiler rather than the Twine visual editor, and is not afraid of writing some Javascript code.

## Installation

Rez is written in the Elixir programming language and requires both Elixir and Erlang to be installed. Rez currently targets Elixir v1.14 (OTP25) but should be compilable using v1.13.

Rez uses Handlebars.js for it's template language and requires the Handlebars
compiler to be available on the system path for converting templates during game
compilation. Rez was written expecting Handlebars.js v4.7.7.

### macOS

Installation on macOS depends on [Homebrew](https://brew.sh/) and [ASDF](https://asdf-vm.com/). If you install ASDF directly the homebrew dependency is unnecessary.

    # Get Rez
    git clone git@github.com:mmower/rez.git
    # We use ASDF for tool dependency management
    brew install asdf
    # Will bring in nodejs, erlang, and elixir
    asdf install
    # Will install handlebars, Bulma, and Alpine
    npm install
    # Copy handlebars binary into your path, e.g. /usr/local/bin
    cp node_modules/handlebars/bin/handlebars /usr/local/bin/
    # Install Elixir deps
    mix deps.get
    # Creates the `rez` compiler binary
    ./build_escript
    # Check the binary works
    ./rez --version (should report v0.9.1)
    # Copy to a folder in your path
    cp rez ~/bin/

### Windows

  1. **Install Elixir and Erlang.**

     Download the Elixir web installer from https://elixir-lang.org/install.html#windows and install v1.14.2 or newer (the installer will give you a choice of versions during install). Installing Elixir will also install the appropriate version of Erlang by default. If you have a prior install of Erlang, you may need to check that it's compatible with latest Elixir.
    
     Verify your install in Powershell with
    
         > elixir -v
         Erlang/OTP 25 [erts-13.0.4] [source] [64-bit] [smp:16:16] [ds:16:16:10] [async-threads:1] [jit:ns]
         Elixir 1.14.2 (compiled with Erlang/OTP 25)
   
  2. **Install Node.**

     Install [NodeJS 19](https://nodejs.org/).  A optional version manager like [NVM for Windows](https://github.com/coreybutler/nvm-windows) can make this easier.
     
  3. **Clone the repo.**
  
         > git clone git@github.com:mmower/rez.git
         > cd rez
      
  4. **Install dependencies.**
  
         > npm install
         > mix deps.get
      
  5. **Build the rez compiler binary.**
  
     From Powershell:
     
         > $env:BUILD_MODE = 'escript'; $env:MIX_ENV = 'prod'; mix escript.build
     
     Verify your build:
     
         > .\rez --version

  6. **Put rez in your path.**

     Edit your environment variables and add the repo to your PATH. Now you should be able to run `rez` from any directory in your shell, undecorated. Check that you can print the version from the root directory:

         > cd \; rez version

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

    rez compile [--verbose 0-4] src/<file.rez>

This will build the complete game in the `dist` folder including all assets referenced in the game.

The resulting files can be archived for distribution either hosted on a server or potentially turned into an Eletron application.

Note that, at present, no attempt is made to minimise or optimise the resulting JS or CSS assets.
