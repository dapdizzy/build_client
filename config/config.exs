# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure for your application as:
#
#     config :build_client, key: :value
#
# And access this configuration in your application as:
#
#     Application.get_env(:build_client, :key)
#
# Or configure a 3rd-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env}.exs"
config :build_client,
  server_node: :s25@MOW04DEV014, server_name: BuildServer,
  scripts_dir: "C:/AX/BuildScripts",
  log_dir: "C:/Logs",
  configurations:
    %{
      build_configuration:
        %{
          Fax: "Test",
          Wax: nil,
          Lips: "lips"
          },
      deploy_configuration:
        %{
          Fax: "FAX",
          Wax: nil,
          Lips: "lips"
        }
    }
