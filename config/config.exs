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
  server_node: :sloc1@MOW04DEV014, server_name: BuildServer,
  scripts_dir: "C:/AX/BuildScripts",
  log_dir: "C:/Logs",
  configurations:
    %{
      build_configuration:
        %{
          Fax:
            %{
              configuration_name: "Test",
              configuration_parameters:
                %{
                  "VCSFilePath" => "C:/Program Files/Microsoft Dynamics AX/60/Server/AXTest/bin/Application/FAX/Definition/VCSDef.xml",
                  "ApplicationSourceDir" => "C:/Program Files/Microsoft Dynamics AX/60/Server/AXTest/bin/Application/FAX",
                  "DropLocation" => "C:/AX/Build/Drop/Fax",
                  "BackupModelStoreFolder" => "C:/AX/Backup/Modelstore",
                  "CleanBackupFileName" => "C:/Program Files/Microsoft SQL Server/MSSQL12.MSSQLSERVER/MSSQL/Backup/AXR3.bak"
                }
            },
          Wax: %{configuration_name: nil},
          Lips: %{configuration_name: "lips"}
          },
      deploy_configuration:
        %{
          Fax:
            %{
              configuration_name: "FAX"
            },
          Wax: %{configuration_name: nil},
          Lips: %{configuration_name: "lips"}
        }
    }
