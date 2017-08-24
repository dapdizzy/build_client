defmodule BuildClient.Parser do
  def start_link(server, commands, systems) do
    {:ok, agent} =
      Agent.start_link(
        fn -> %ParserState
        {
          server: server,
          commands: commands,
          systems: systems,
          systems_mapping: create_systems_mapping(systems)
        } end)
    agent |> start_command_loop
  end

  defp create_systems_mapping(systems) do
    for s <- systems, into: %{}, do: {atom_to_upper_string(s), s}
  end

  defp atom_to_upper_string(atom) do
    atom |> Atom.to_string |> String.upcase
  end

  def start_command_loop(agent) do
    IO.puts "\nHelp\n"
    agent |> get_server |> BuildClient.Client.get_help |> IO.puts
    agent |> parse_user_input
  end

  def parse_user_input(agent) do
    IO.gets("Enter build command: ") |> parse(agent)
    agent |> parse_user_input
  end

  defp is_valid_command(agent, command) do
    # commands = agent |> Agent.get(&1, :commands)
    agent |> get_commands |> Enum.member?(command)
  end

  defp get_commands(agent) do
    agent |> Agent.get(&extract_commands/1)
  end

  defp get_systems(agent) do
    agent |> Agent.get(&(&1.systems))
  end

  defp get_server(agent) do
    agent |> Agent.get(&(&1.server))
  end

  defp get_systems_mapping(agent) do
    agent |> Agent.get(&(&1.systems_mapping))
  end

  defp lookup_system_name(systems_mapping, system_name) do
    case systems_mapping[system_name] do
      nil ->
        {:wrong_system, system_name}
      system ->
        {:ok, system}
    end
  end

  defp parse_system(agent, system_string) do
    agent |> get_systems_mapping |> lookup_system_name(system_string |> String.upcase)
  end

  defp parse_system!(agent, system_name) do
    case agent |> parse_system(system_name) do
      {:wrong_system, _system_string} ->
        IO.puts "Wrong system name"
        IO.write "Valid values are: "
        agent |> get_systems |> Enum.join(", ") |> IO.write
        IO.puts ""
        throw :done
      {:ok, system_atom} ->
        system_atom
    end
  end

  defp extract_commands(%ParserState{} = agent_state) do
    agent_state.commands
  end

  defp is_valid_format([_h|_t]) do
    true
  end

  defp is_valid_format(_) do
    false
  end

  defp parse(s, agent) do
    pl = s |> String.rstrip(?\n) |> String.split(" ", trim: true)
    try do
      format_validation_result =
      case pl |> is_valid_format do
        true -> :go_ahead
        false -> throw(:invalid_command_format)
      end
      case format_validation_result do
        :go_ahead ->
          case agent |> is_valid_command(pl |> hd) do
            true -> :go_ahead
            _ -> throw(:invalid_command)
          end
        _ -> raise "Invalid format validation result" #throw(:unbelieveable)
      end
      case pl do
        ["h"] ->
          IO.puts "\nHelp\n"
          agent |> get_server |> BuildClient.Client.get_help |> IO.puts
        ["help"] ->
          IO.puts "\nHelp\n"
          agent |> get_server |> BuildClient.Client.get_help |> IO.puts
        ["h", command] ->
          agent |> get_server |> BuildClient.Client.get_help(command) |> IO.puts
        ["help", command] ->
          agent |> get_server |> BuildClient.Client.get_help(command) |> IO.puts
        ["list_commands"|_t] ->
          "Commands: " |> IO.write
          agent |> get_commands |> Enum.join(", ") |> IO.write
          IO.puts ""
        ["list_systems"|_t] ->
          "Systems: " |> IO.write
          agent |> get_systems |> Enum.join(", ") |> IO.write
          IO.puts ""
        ["get_build_configuration", system_name] ->
          system = case agent |> parse_system(system_name) do
            {:wrong_system, _system_name} ->
              IO.puts "Wrong system name"
              IO.write "Valid values are: "
              agent |> get_systems |> Enum.join(", ") |> IO.write
              IO.puts ""
              throw :done
            {:ok, systen_atom} ->
              systen_atom
          end
          case agent |> get_server |> BuildClient.Client.get_build_configuration(system) do
            {:configuration, %{} = server_configuration} ->
              IO.puts "Build configuration for #{system}:"
              server_configuration
              |> Map.merge(BuildClient.Client.get_system_client_configuration_parameters(system, :build_configuration))
              |> BuildClient.Client.configuration_to_list |> BuildClient.Client.list_to_string
              |> IO.puts
            {:unknown_system, explanation} ->
              IO.puts "Unknown system: #{explanation}"
          end
        ["get_build_info", system_name] ->
          system =
          case agent |> parse_system(system_name) do
            {:wrong_system, _system_name} ->
              IO.puts "Wrong system name"
              IO.write "Valid values are: "
              agent |> get_systems |> Enum.join(", ") |> IO.write
              IO.puts ""
              throw :done
            {:ok, system_atom} ->
              system_atom
          end
          :ok = agent |> get_server |> BuildClient.Client.get_build_info(system)
          # Moved to the Client Serve rcallback
          # case agent |> get_server |> BuildClient.Client.get_build_info(system) do
          #   %{} = map ->
          #     latest_build =
          #     case map[:latest_build] do
          #       nil -> "No build available"
          #       build -> build
          #     end
          #     last_successful_build =
          #     case map[:last_successful_build] do
          #       nil -> "No build available"
          #       build -> build
          #     end
          #     IO.puts "Latest build: #{latest_build}"
          #     IO.puts "Last successful build: #{last_successful_build}"
          #   :no_info ->
          #     IO.puts "No information is available"
          #   _ ->
          #     IO.puts "Something went wrong with the request..."
          # end
        ["get_configuration", system_name] ->
          system =
          case agent |> parse_system(system_name) do
            {:wrong_system, _system_string} ->
              IO.puts "Wrong system name"
              IO.write "Valid values are: "
              agent |> get_systems |> Enum.join(", ") |> IO.write
              IO.puts ""
              throw :done
            {:ok, system_atom} ->
              system_atom
          end
          IO.puts "Configuration for system #{system}"
          case system |> BuildClient.Client.get_configuration do
            {:configuration, %{} = configuration} ->
              configuration_string = configuration |> BuildClient.Client.configuration_to_list |> BuildClient.Client.list_to_string
              # |> String.replace("/", "\\")
              |> IO.puts
              # "Configuration received:\n#{configuration_string}"
              # fileName = "DeployParameters#{get_dateTime_string}.txt"
              # configuration_string |> BuildClient.Client.create_deploy_configuration(fileName)
              # IO.puts "Outputetd configuration to #{fileName}"
            {:unknown_system, explanation} ->
              IO.puts "Unknown system: #{explanation}"
          end
        ["deploy", system_name] ->
          system = agent |> parse_system!(system_name)
          case system |> BuildClient.Client.get_configuration do
            {:configuration, %{} = configuration} ->
              configuration |>
              Map.merge(BuildClient.Client.get_system_client_configuration_parameters(system, :deploy_configuration)) |>
              BuildClient.Client.configuration_to_list |>
              BuildClient.Client.list_to_string |>
              # String.replace("/", "\\") |>
              BuildClient.Client.create_deploy_configuration()
              l = spawn_link BuildClient.Client, :run_deploy_script, []
              IO.puts "Deploy script has been spawned with PID #{inspect l}"
            {:unknown_system, explanation} ->
              IO.puts "Unknown system: #{explanation}"
          end
        ["build", system_name | options] ->
          system = agent |> parse_system!(system_name)
          agent |> get_server |> BuildClient.Client.start_build(system, {BuildClient, node()}, options)
        [full_action = "schedule_" <> action, system_string, schedule | options] ->
          case action do
            "deploy" -> :ok
            "build" -> :ok
            _ -> throw :invalid_command
          end
          system =
          case agent |> parse_system(system_string) do
            {:wrong_system, _system_string} ->
              IO.puts "Wrong system name"
              IO.write "Valid values are: "
              agent |> get_systems |> Enum.join(", ") |> IO.write
              IO.puts ""
              throw :done
            {:ok, system_atom} ->
              system_atom
          end
          IO.puts "Scheduling #{action} #{system} on #{schedule}"
          case schedule |> BuildClient.Client.user_schedule_to_cron do
            {:cron_schedule, cron_schedule} ->
              case agent |> get_server |>
                BuildClient.Client.request_schedule_action(String.to_atom(full_action), system, cron_schedule, {BuildClient, node()}, options) do
                :ok ->
                  IO.puts "Deploy #{system} was scheduled at #{schedule}"
                {:failed, message} ->
                  IO.puts message
                _ ->
                  IO.puts "Unsupported reply from build server. Probably, something went wrong..."
              end
            {:invalid_format, message} ->
              IO.puts message
          end
        ["schedule_ping", schedule] ->
          case schedule |> BuildClient.Client.user_schedule_to_cron do
            {:cron_schedule, cron_schedule} ->
              case agent |> get_server |>
                BuildClient.Client.schedule_ping(cron_schedule, {BuildClient, node()}) do
                :ok ->
                  IO.puts "Schedule ping request sent to server"
                _ ->
                  IO.puts "Unsupported reply from build server. Probably, something went wrong..."
              end
            {:invalid_format, message} ->
              IO.puts message
          end
        ["remove_schedule", schedule] ->
          cron_schedule = schedule |> BuildClient.Client.cron_schedule!
          case cron_schedule |> BuildClient.Client.remove_schedule do
            {:ok, deleted_schedules} ->
              deleted_schedules_list = for deleted_schedule <- deleted_schedules, into: [], do: "#{deleted_schedule.command} on #{deleted_schedule.schedule}"
              IO.puts ~s/The following jobs scheduled on #{schedule} have been removed:\n#{deleted_schedules_list |> Enum.join("\n")}/
            :nothing_is_scheduled ->
              IO.puts "Nothing is scheduled on #{schedule}"
            _ -> raise "Could not remove schedule on #{schedule}"
          end
        ["clear_schedule"] ->
          case agent |> get_server |> BuildClient.Client.clear_schedule do
            :ok -> IO.puts "Your schedule has been cleared"
            _ -> IO.puts "Something went wrong...\nYour should probably contant your AX Build Administrator, but that's up to You."
          end
        ["my_client"] ->
          IO.write "Your client is: "
          client = agent |> get_server |> BuildClient.Client.my_client
          IO.write "#{inspect client}"
          IO.puts ""
        ["my_schedule"] ->
          your_schedule = agent |> get_server |> BuildClient.Client.my_schedule
          IO.puts your_schedule
          IO.puts ""
        # [command, system, cron_sched] ->
        #   IO.puts "Received: Command - #{command}, System - #{system}, Schedule - #{cron_sched}"
        _ -> throw :invalid_command_format
      end
    catch
      :done ->
        :done
      :invalid_command_format ->
        IO.puts "Invalid command format\n"
        agent |> get_server |> BuildClient.Client.get_help |> IO.puts
      :invalid_command ->
        IO.puts "Invalid command\n"
        IO.puts "Valid commands are:\n"
        agent |> get_server |> BuildClient.Client.list_commands |> Enum.each(&IO.puts/1)
    end
    pl
  end

  def get_dateTime_string do
    {{year, month, day}, {h, m, s}} = :calendar.local_time
    "#{year}#{month |> rjust}#{day |> rjust}#{h |> rjust}#{m |> rjust}#{s |> rjust}"
  end

  defp rjust(v, l \\2, c \\ ?0) do
    v |> to_string |> String.rjust(l, c)
  end
end
