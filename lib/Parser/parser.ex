defmodule BuildClient.Parser do
  def start_link(server, commands, systems) do
    {:ok, agent} = Agent.start_link(fn -> %ServerState{server: server, commands: commands, systems: systems} end)
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

  defp extract_commands(%ServerState{} = agent_state) do
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
        ["get_configuration", system] ->
          IO.puts "Asked for configuration for system #{system}"
          case system |> String.to_atom |> BuildClient.Client.get_configuration do
            {:configuration, %{} = configuration} ->
              configuration_string = configuration |> BuildClient.Client.configuration_to_list |> BuildClient.Client.list_to_string
              |> String.replace("/", "\\")
              IO.puts "Configuration received:\n#{configuration_string}"
              fileName = "DeployParameters#{get_dateTime_string}.txt"
              configuration_string |> BuildClient.Client.create_deploy_configuration(fileName)
              IO.puts "Outputetd configuration to #{fileName}"
            {:unknown_system, explanation} ->
              IO.puts "Unknown system: #{explanation}"
          end
        ["deploy", system] ->
          case system |> String.to_atom |> BuildClient.Client.get_configuration do
            {:configuration, %{} = configuration} ->
              configuration |>
              BuildClient.Client.configuration_to_list |>
              BuildClient.Client.list_to_string |>
              String.replace("/", "\\") |>
              BuildClient.Client.create_deploy_configuration()
              l = spawn_link BuildClient.Client, :run_deploy_script, []
              IO.puts "Deploy script has been spawned with PID #{inspect l}"
            {:unknown_system, explanation} ->
              IO.puts "Unknown system: #{explanation}"
          end
        ["schedule_deploy", system, schedule | options] ->
          IO.puts "Scheduling deploy #{system} on #{schedule}"
          case schedule |> BuildClient.Client.user_schedule_to_cron do
            {:cron_schedule, cron_schedule} ->
              case BuildClient.Client.request_schedule_deploy(system, cron_schedule, {BuildClient, node()}, options) do
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
        [command, system, cron_sched] ->
          IO.puts "Received: Command - #{command}, System - #{system}, Schedule - #{cron_sched}"
        _ -> IO.puts "Invalid command format"
      end
    catch
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
