# use Mix.Config
import Config

if Mix.env() == :dev do
  config :mix_test_watch, clear: true, extra_extensions: [".rez"]
end
