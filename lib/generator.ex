defmodule Rez.Generator do
  alias Rez.Debug

  require EEx

  @moduledoc """
  `Rez.Generator` implements the generator which creates the skeleton sources
  for a new game.
  """

  @external_resource "node_modules/alpinejs/dist/cdn.min.js"
  @alpine_js File.read!("node_modules/alpinejs/dist/cdn.min.js")

  @external_resource "node_modules/bulma/css/bulma.min.css"
  @bulma_css File.read!("node_modules/bulma/css/bulma.min.css")

  EEx.function_from_file(:def, :render_hello, Path.expand("assets/templates/hello.rez.eex"), [
    :assigns
  ])

  EEx.function_from_file(:def, :render_game, Path.expand("assets/templates/source.rez.eex"), [
    :assigns
  ])

  EEx.function_from_file(:def, :render_stdlib, Path.expand("assets/templates/stdlib.rez.eex"), [
    :assigns
  ])

  def generate(args, options) when is_list(args) and is_map(options) do
    if Enum.count(args) < 1 do
      IO.puts("Must specify name of game to create")
    end

    overwrite = Map.get(options, :overwrite, false)

    author_name = Map.get(options, :author_name, "Author Name")
    author_email = Map.get(options, :author_email, "author.email@domain.foo")

    game_title = Map.get(options, :game_title, "Twisty Maze Adventure")
    game_homepage = Map.get(options, :game_homepage, "https://rez-lang.com/")

    sample_game = Map.get(options, :sample, false)

    [name | _args] = args

    # Create the main game directory in the current directory
    File.mkdir_p!(name)

    # Source path is where .rez files and EEX templates go
    source_path = Path.join(name, "src")
    File.mkdir_p!(source_path)

    # Dist path is where the compiler will build the game output
    dist_path = Path.join(name, "dist")
    File.mkdir_p!(dist_path)

    Debug.v_log("Generating game template")
    game_source_path = Path.join(source_path, "#{name}.rez")

    if !File.exists?(game_source_path) || overwrite do
      ifid = UUID.uuid1() |> String.upcase()
      created = DateTime.utc_now() |> DateTime.to_string()

      source =
        if sample_game do
          render_game(
            name: name,
            author_name: author_name,
            author_email: author_email,
            game_title: game_title,
            game_homepage: game_homepage,
            ifid: ifid,
            created: created
          )
        else
          render_hello(
            name: name,
            author_name: author_name,
            author_email: author_email,
            game_title: game_title,
            game_homepage: game_homepage,
            ifid: ifid,
            created: created
          )
        end

      File.write!(
        game_source_path,
        source
      )
    else
      Debug.v_log("Skipping game source write")
    end

    # Lib path is where user-written Javascript goes
    lib_path = Path.join(name, "lib")
    File.mkdir_p!(lib_path)

    Debug.v_log("Generate stdlib template")
    stdlib_path = Path.join(lib_path, "stdlib.rez")

    if !File.exists?(stdlib_path) || overwrite do
      File.write!(stdlib_path, render_stdlib([]))
    else
      Debug.v_log("Skipping stdlib source write")
    end

    # Assets path is where all static assets live
    assets_path = Path.join(name, "assets")
    File.mkdir_p!(assets_path)

    js_path = Path.join(assets_path, "js")
    File.mkdir_p!(js_path)
    File.write!(Path.join(js_path, "alpinejs.min.js"), @alpine_js)

    css_path = Path.join(assets_path, "css")
    File.mkdir_p!(css_path)
    File.write!(Path.join(css_path, "bulma.min.css"), @bulma_css)

    image_path = Path.join(assets_path, "img")
    File.mkdir_p!(image_path)

    movie_path = Path.join(assets_path, "mov")
    File.mkdir_p!(movie_path)

    sound_path = Path.join(assets_path, "snd")
    File.mkdir_p!(sound_path)
  end
end
