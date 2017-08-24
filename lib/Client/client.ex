defmodule BuildClient.Client do

  # Server interaction API

  def my_client(server \\ get_server_name) do
    server |> GenServer.call({:my_client, node() |> get_host_name})
  end

  def my_schedule(server \\ get_server_name) do
    server |> GenServer.call({:my_schedule, node() |> get_host_name})
  end

  def remove_schedule(server \\ get_server_name, schedule) do
    server |> GenServer.call({:remove_schedule, schedule, node() |> get_host_name})
  end

  def clear_schedule(server \\ get_server_name) do
    server |> GenServer.call({:clear_schedule, node() |> get_host_name})
  end

  def connect(server \\ get_server_name, client) do
    server |> GenServer.call({:connect, client})
  end

  def get_build_info(server \\ get_server_name, system) do
    server
      |> GenServer.call(
        {:get_build_info, system,
          BuildClient.Client.get_system_client_configuration_parameters(system, :deploy_configuration),
          node()
        })
  end

  def get_help(server \\ get_server_name, command \\ nil) do
    case command do
      nil -> server |> GenServer.call(:get_help)
      _ -> server |> GenServer.call({:get_help, command})
    end
  end

  def list_commands(server \\ get_server_name) do
    server |> GenServer.call(:list_commands)
  end

  def list_systems(server \\ get_server_name) do
    server |> GenServer.call(:list_systems)
  end

  def has_system(server \\ get_server_name, system) do
    server |> GenServer.call({:has_system, system})
  end

  def get_configuration(server \\ get_server_name, system) do
    #IO.puts "Looking for configuration for system #{system}"
    server |> GenServer.call({:get_configuration, system})
  end

  def get_client_configuration(system, configuration_type) when configuration_type === :build_configuration or configuration_type === :deploy_configuration do
    Application.get_env(:build_client, :configurations)[configuration_type][system].configuration_parameters
  end

  def get_build_configuration(server \\ get_server_name, system) do
    server |> GenServer.call({:get_build_configuration, system})
  end

  def request_schedule_action(server \\ get_server_name, action, system, schedule, build_client, options \\ []) do
    server |> GenServer.call({action, system, schedule, build_client, options})
  end

  def start_build(server \\ get_server_name, system, build_client, options \\ []) do
    server |> GenServer.call({:build, system, build_client, options})
  end

  def schedule_ping(server \\ get_server_name, schedule, client) do
    server |> GenServer.call({:schedule_ping, schedule, client})
  end

  defp get_server_name do
    serverNode = Application.get_env(:build_client, :server_node)
    serverName = Application.get_env(:build_client, :server_name)
    {serverName, serverNode}
  end

  def user_schedule_to_cron(schedule) do
    sched =
    case schedule |> String.split("_", trim: true) do
      ["morning"] ->
        {:sched, {:time, {:hours, 4}}}
      [c1, c2] ->
        case {extract_sched(c1), extract_sched(c2)} do
          {{:date, _date_sched} = ds, {:time, _time_sched} = ts} ->
            {:sched, {ds, ts}}
          {{:time, _time_sched} = ts, {:date, _date_sched} = ds} ->
            {:sched, {ds, ts}}
          {:invalid_format, _message} = err ->
            {:error, err}
        end
      [c] ->
        case c |> extract_sched do
          {:date, _date_sched} = ds ->
            {:sched, ds}
          {:time, _time_sched} = ts ->
            IO.puts "Got time-only schedule"
            {:sched, ts}
          {:invalid_format, _message} = err ->
            {:error, err}
        end
      _ ->
        {
          :error,
          {:invalid_format,
          "Invalid schedule format, supported formats are:\nDate formats:\n#{supported_date_formats |> format_to_string}\nTime formats:\n#{supported_time_formats |> format_to_string}\nOr any combination of valid date and time formats separated by space."}
        }
    end
    case sched do
      {:error, err_info} -> err_info
      {:sched, sched_info} ->
        case sched_info do
          {:date, _ds_info} = ds ->
            cond do
              ds |> validate_sched ->
                {:cron_schedule, ds |> user_sched_to_cron |> sched_list_to_cron_string}
              true -> {:invalid_format, invalid_format_string}
            end
          {:time, _ts_info} = ts ->
            IO.puts "Got time schedule info"
            cond do
              ts |> validate_sched ->
                {:cron_schedule, ts |> user_sched_to_cron |> sched_list_to_cron_string}
              true -> {:invalid_format, invalid_format_string}
            end
          {{:date, _ds_info} = ds, {:time, _ts_info} = ts} ->
            cond do
              (ds |> validate_sched) and (ts |> validate_sched) ->
                {:cron_schedule, merge_cron_scheds(ds |> user_sched_to_cron, ts |> user_sched_to_cron) |> sched_list_to_cron_string}
              true -> {:invalid_format, invalid_format_string}
            end
          _ ->
            {:invalid_format, invalid_format_string}
        end
      _ ->
        {:invalid_format, invalid_format_string}
    end
  end

  def cron_schedule!(user_schedule) do
    case user_schedule |> user_schedule_to_cron do
      {:cron_schedule, cron_schedule} -> cron_schedule
      {:invalid_format, message} -> raise message
      _ -> raise "Could not convert user format #{user_schedule} to CRON format"
    end
  end

  defp invalid_format_string do
  "Invalid schedule format, supported formats are:
  Date formats:
  #{supported_date_formats_string}
  Time formats:
  #{supported_time_formats_string}
  Or any combination of valid date and time formats separated by space."
  end

  defp supported_date_formats_string do
    supported_date_formats |> format_to_string
  end

  defp supported_time_formats_string do
    supported_time_formats |> format_to_string
  end

  defp normalize_cron_item(nil) do
    "*"
  end

  defp normalize_cron_item(ci) do
    "#{ci}"
  end

  defp sched_list_to_cron_string(sched_list) do
    (for x <- sched_list, into: [], do: "#{normalize_cron_item(x)}")
    |> Enum.join(" ")
  end

  defp user_sched_to_cron({:time, {:hours, hour}}) do
    [0, hour, nil, nil, nil]
  end

  defp user_sched_to_cron({:time, {:hours, hour, :minutes, minute}}) do
    [minute, hour, nil, nil, nil]
  end

  defp user_sched_to_cron({:date, {:day, day}}) do
    [nil, nil, day, nil, nil]
  end

  defp user_sched_to_cron({:date, {:day, day, :month, month}}) do
    [nil, nil, day, month, nil]
  end

  defp user_sched_to_cron({:date, {:day, day, :month, month, :year, _year}}) do
    [nil, nil, day, month, nil]
  end

  defp merge_cron_item(nil, nil) do
    nil
  end

  defp merge_cron_item(nil, x) do
    x
  end

  defp merge_cron_item(x, nil) do
    x
  end

  defp merge_cron_item(x, _y) do
    x
  end

  defp merge_cron_scheds(sc1, sc2) do
    merge_cron_scheds_tail(sc1, sc2, [])
  end

  defp merge_cron_scheds_tail([], [], res) do
    res |> Enum.reverse
  end

  defp merge_cron_scheds_tail([h1|t1], [h2|t2], res) do
    merge_cron_scheds_tail(t1, t2, [merge_cron_item(h1, h2)|res])
  end

  defp supported_date_formats do
    [
      "xxd - day, i.e., 11d - for 11-th day of month",
      "xxdyym - day and month, i.e., 15d07m - for 15-th of July",
      #"xxdyymzz|zzzzy - day, month, year, i.e., 17d05m",
      "dd - day, i.e., 07 for 7-th day of month",
      "dd.mm - day and month, i.e., 08.08 for 8-th of August"
      # "__.__.__|____ day, month, year"
    ]
  end

  defp supported_time_formats do
    [
      "xxh - hour, i.e., 04 - for 4 a.m.",
      "xxhyym - hours and minutes, i.e., 03h30m - for 3:30 a.m.",
      "hh - hour, i.e., 23 - for 23:00",
      "hh:mm - hours and minutes, i.e., 23:30"
    ]
  end

  defp format_to_string(format, separator \\ "\n") do
    format |> Enum.join(separator)
  end

  defp to_integer(s) do
    case s |> Integer.parse do
      {integer, _remainder} ->
        integer
      :error -> raise "Cannot convert #{s} to integer"
      :no_return -> raise "Cound not convert #{s} to integer"
    end
  end

  def extract_sched(p) do
    IO.puts "Parsing #{p}"
    cond do
      (
      IO.puts "Trying xxd"
      case Regex.named_captures(~r/^(?<day>[0-9]{1,2})[d]{1}$/, p) do
        %{} = m ->
          r = {:day, m["day"] |> to_integer}
          true
        _ ->
          false
      end
      )
        -> {:date, r}
      (
      IO.puts "Trying xxdyym"
      case Regex.named_captures(~r/^(?<day>[0-9]{1,2})[d]{1}(?<month>[0-9]{1,2})[m]{1}$/, p) do
        %{} = m ->
          r = {:day, m["day"] |> to_integer, :month, m["month"] |> to_integer}
          true
        _ ->
          false
      end
      )
        -> {:date, r}
      # (
      # case Regex.named_captures(~r/^(?<day>[0-9]{1,2})[d]{1}(?<month>[0-9]{1,2})[m]{1}(?<year>(?:\d{4}|\d{2}))[y]{1}$/, p) do
      #   %{} = m ->
      #     r = {:day, m["day"], :month, m["month"], :year, m["year"]}
      #     true
      #   _ ->
      #     false
      # end
      # )
      #   -> {:date, r}
      (
      IO.puts "Trying dd"
      case Regex.named_captures(~r/^(?<day>[0-9]{1,2})$/, p) do
        %{} = m ->
          r = {:day, m["day"] |> to_integer}
          true
        _ ->
          false
      end
      )
        -> {:date, r}
      (
      IO.puts "Trying dd.mm"
      case Regex.named_captures(~r/^(?<day>[0-9]{1,2})[.]{1}(?<month>[0-9]{1,2})$/, p) do
        %{} = m ->
          r = {:day, m["day"] |> to_integer, :month, m["month"] |> to_integer}
          true
        _ ->
          false
      end
      )
        -> {:date, r}
      # (
      # case Regex.named_captures(~r/^(?<day>[0-9]{1,2})[.]{1}(?<month>[0-9]{1,2})[.]{1}(?<year>(?:\d{4}|\d{2}))$/, p) do
      #   %{} = m ->
      #     r = {:day, m["day"], :month, m["month"], :year, m["year"]}
      #     true
      #   _ ->
      #     false
      # end
      # )
      #   -> {:date, r}
      # (
      # case Regex.named_captures(~r/^(?<h>[0-9]{1,2})$/, p) do
      #   %{} = m ->
      #     r = {:hours, m["h"] |> to_integer}
      #     true
      #   _ ->
      #     false
      # end
      # )
      #   -> {:time, r}
      (
      IO.puts "Trying hh:mm"
      case Regex.named_captures(~r/^(?<h>[0-9]{1,2})[:](?<m>[0-9]{1,2})$/, p) do
        %{} = m ->
          r = {:hours, m["h"] |> to_integer, :minutes, m["m"] |> to_integer}
          true
        _ ->
          false
      end
      )
        -> {:time, r}
      (
      IO.puts "Trying xxh"
      case Regex.named_captures(~r/^(?<h>[0-9]{1,2})[h]{1}$/, p) do
        %{} = m ->
          r = {:hours, m["h"] |> to_integer}
          true
        _ ->
          false
      end
      )
        -> {:time, r}
      (
      IO.puts "Trying xxhyym"
      case Regex.named_captures(~r/^(?<h>[0-9]{1,2})[h]{1}(?<m>[0-9]{1,2})[m]{1}$/, p) do
        %{} = m ->
          IO.puts "Matched xxhyym"
          r = {:hours, m["h"] |> to_integer, :minutes, m["m"] |> to_integer}
          IO.puts "r = #{inspect r}"
          true
        _ ->
          false
      end
      )
        -> {:time, r}
      true ->
        {:invalid_format, invalid_format_string}
    end
  end

  def validate_sched({:date, {:day, day}}) when day > 0 and day <= 31 do
    true
  end

  def validate_sched({:date, {:day, day, :month, month}}) when day > 0 and day <= 31 and month > 0 and month <= 12 do
    true
  end

  def validate_sched({:date, {:day, day, :month, month, :year, _year}})
  when day > 0 and day <= 31 and month > 0 and month <= 12
  do
    true
  end

  def validate_sched({:time, {:hours, hours}}) when hours >= 0 and hours <= 23 do
    true
  end

  def validate_sched({:time, {:hours, hours, :minutes, minutes}}) when hours >= 0 and hours <= 23 and minutes >= 0 and minutes < 60 do
    true
  end

  def validate_sched(_) do
    false
  end

  def configuration_to_list(configuration = %{}) do
    for {k, v} <- configuration, into: [], do: "#{k}=#{v |> invert_slashes(k)}\r\n"
  end

  defp invert_slashes(val, key) do
    # Invert slashes for all entries, except TFS URLs where they are approproate
    cond do
      not is_binary(val) ->
        val
      not Regex.match?(~r/TFS/, key) ->
        val |> String.replace("/", "\\")
      true ->
        val
    end
    # case Regex.match?(~r/TFS/, key) do
    #   true -> val
    #   false -> val |> String.replace("/", "\\")
    # end
  end

  def list_to_string(l) do
    for i <- l, into: "", do: "#{i}"
  end

  def create_deploy_configuration(configuration_string, filename \\ "DeployParameters.txt") do
    Application.get_env(:build_client, :scripts_dir) |> Path.join(filename) |> File.write!(configuration_string, [:binary, {:encoding, :utf8}])
  end

  def create_build_configuration(configuration_string, filename \\ "BuildParameters.txt") do
    Application.get_env(:build_client, :scripts_dir) |> Path.join(filename) |> File.write!(configuration_string, [:binary, {:encoding, :utf8}])
  end

  def run_deploy_script do
    logDir = Application.get_env(:build_client, :scripts_dir)
    logDir |> File.cd!
    deployLogDir = logDir |> Path.join("Log#{BuildClient.Parser.get_dateTime_string}")
    deployLogDir |> File.mkdir!
    logFileName = deployLogDir |> Path.join("DeployAXOutput.log")
    cl = "powershell .\\DeployAX.ps1 > #{logFileName}"
    |> String.to_char_list
    IO.puts "Calling os.cmd with the following args #{inspect cl}"
    cl |> :os.cmd
  end

  def run_build_script do
    scriptsDir = Application.get_env(:build_client, :scripts_dir)
    scriptsDir |> File.cd!
    logDir = Application.get_env(:build_client, :log_dir)
    buildLogDir = logDir |> Path.join("BuildLog#{BuildClient.Parser.get_dateTime_string}")
    buildLogDir |> File.mkdir!
    logFileName = buildLogDir |> Path.join("BuildAXOutput.log")
    cl = "powershell .\\BuildAX.ps1 > #{logFileName}"
    |> String.to_char_list
    IO.puts "Calling os.cmd with the following args #{inspect cl}"
    cl |> :os.cmd
  end

  defp set_current_client_configuration(configuration_name) do
    scripts_dir = Application.get_env(:build_client, :scripts_dir)
    scripts_dir |> File.cd!
    "powershell .\\Set-CurrentAXClientConfiguration.ps1 #{configuration_name}"
    |> String.to_char_list
    |> :os.cmd
  end

  defp get_system_configurtation(system, configuration_type)
  when configuration_type === :build_configuration
  or configuration_type === :deploy_configuration do
    Application.get_env(:build_client, :configurations)[configuration_type][system][:configuration_name]
  end

  defp get_system_configurtation(_system, configuration_type) do
    raise "Invalid configuration type #{configuration_type}"
  end

  def get_system_client_configuration_parameters(system, configuration_type)
  when configuration_type === :build_configuration
  or configuration_type == :deploy_configuration
  do
    Application.get_env(:build_client, :configurations)[configuration_type][system] |> Map.get(:configuration_parameters, %{})
  end

  def get_system_client_configuration_parameters(_system, configuration_type) do
    raise "Invalid configuration type #{configuration_type}"
  end

  def set_system_configuration(system, configuration_type) do
    system |> get_system_configurtation(configuration_type)
    |> set_current_client_configuration
  end

  defp get_host_name(node_name) do
    node_name |> to_string |> String.split("@") |> List.last
  end
end
