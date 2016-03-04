defmodule BuildClient.Parser do
  def start_link do
    parse_user_input
  end

  def parse_user_input do
    IO.gets("Enter build command: ") |> parse
    parse_user_input
  end

  defp parse(s) do
    case pl = s |> String.rstrip(?\n) |> String.split(" ", trim: true) do
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
        IO.puts "Received: Command - #{command}, System - #{system}, CRON Schedule - #{cron_sched}"
      _ -> IO.puts "Invalid command format"
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
