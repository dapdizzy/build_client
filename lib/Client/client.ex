defmodule BuildClient.Client do
  def list_systems do
    get_server_name |> GenServer.call(:list_systems)
  end

  def has_system(system) do
    get_server_name |> GenServer.call({:has_system, system})
  end

  def get_configuration(system) do
    IO.puts "Looking for configuration for system #{system}"
    get_server_name |> GenServer.call({:get_configuration, system})
  end

  def request_schedule_deploy(system, schedule, options \\ []) do
    case get_server_name |> GenServer.call({:schedule_deploy, system, schedule, options}) do
      :ok ->
        IO.puts "Deploy of #{system} successfully scheduled on #{schedule}"
      {:failed, reason} ->
        IO.puts reason
    end
  end

  defp get_server_name do
    serverNode = Application.get_env(:build_client, :server_node)
    serverName = Application.get_env(:build_client, :server_name)
    {serverName, serverNode}
  end

  defp user_schedule_to_cron(schedule) do
    sched =
    case schedule |> String.split(" ", trim: true) do
      [c1, c2] ->
        case {extract_sched(c1), extract_sched(c2)} do
          {{:date, date_sched} = ds, {:time, time_sched} = ts} ->
            {:sched, {ds, ts}}
          {{:time, time_sched} = ts, {:date, date_sched} = ds} ->
            {:sched, {ds, ts}}
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
          {:date, ds_info} ->
            cond do
              ds_info |> validate_sched ->

            end
        end
    end
  end

  defp user_sched_to_cron({:time, {:hour, hour}}) do
    "0 #{hour} * * *"
  end

  defp user_sched_to_cron(:time, {:hour, hour, :minute, minute}) do
    "#{minute} #{hour} * * *"
  end

  defp user_sched_to_cron({:date, {:day, day}}) do
    "* * #{day} * *"
  end

  defp user_sched_to_cron({:date, {:day, day, :month, month}}) do
    "* * #{day}, #{month} *"
  end

  defp supported_date_formats do
    [
      "__d - day",
      "__d__m - day and month",
      "__d__m__|____y - day, month ,year",
      "__ - day",
      "__.__ - day and month",
      "__.__.__|____ day, month, year"
    ]
  end

  defp supported_time_formats do
    [
      "__h - hour",
      "__h__m - hours and minutes",
      "__ - hours",
      "__:__ - hours and minutes"
    ]
  end

  defp format_to_string(format, separator \\ "\n") do
    format |> String.join(separator)
  end

  def extract_sched(p) do
    cond do
      (
      case Regex.named_captures(~r/^(?<day>[0-9]{1,2})[d]{1}$/, p) do
        %{} = m ->
          r = {:day, m["day"]}
          true
        _ ->
          false
      end
      )
        -> {:date, r}
      (
      case Regex.named_captures(~r/^(?<day>[0-9]{1,2})[d]{1}(?<month>[0-9]{1,2})[m]{1}$/, p) do
        %{} = m ->
          r = {:day, m["day"], :month, m["month"]}
          true
        _ ->
          false
      end
      )
        -> {:date, r}
      (
      case Regex.named_captures(~r/^(?<day>[0-9]{1,2})[d]{1}(?<month>[0-9]{1,2})[m]{1}(?<year>(?:\d{4}|\d{2}))[y]{1}$/, p) do
        %{} = m ->
          r = {:day, m["day"], :month, m["month"], :year, m["year"]}
          true
        _ ->
          false
      end
      )
        -> {:date, r}
      (
      case Regex.named_captures(~r/^(?<day>[0-9]{1,2})$/, p) do
        %{} = m ->
          r = {:day, m["day"]}
          true
        _ ->
          false
      end
      )
        -> {:date, r}
      (
      case Regex.named_captures(~r/^(?<day>[0-9]{1,2})[.]{1}(?<month>[0-9])$/, p) do
        %{} = m ->
          r = {:day, m["day"], :month, m["month"]}
          true
        _ ->
          false
      end
      )
        -> {:date, r}
      (
      case Regex.named_captures(~r/^(?<day>[0-9]{1,2})[.]{1}(?<month>[0-9]{1,2})[.]{1}(?<year>(?:\d{4}|\d{2}))$/, p) do
        %{} = m ->
          r = {:day, m["day"], :month, m["month"], :year, m["year"]}
          true
        _ ->
          false
      end
      )
        -> {:date, r}
      (
      case Regex.named_captures(~r/^(?<h>[0-9]{1,2})$/, p) do
        %{} = m ->
          r = {:hours, m["h"]}
          true
        _ ->
          false
      end
      )
        -> {:time, r}
      (
      case Regex.named_captures(~r/^(?<h>[0-9]{1,2})[:](?<m>[0-9]{1,2})$/, p) do
        %{} = m ->
          r = {:hours, m["h"], :minutes, m["minutes"]}
          true
        _ ->
          false
      end
      )
        -> {:time, r}
      true ->
        {:invalid_format, "Invalid schedule format"}
    end
  end

  def validate_sched({:date, {:day, day}}) when day > 0 and day < 31 do
    true
  end

  def validate_sched({:date, {:day, day, :month, month}}) when day > 0 and day < 31 and month > 0 and month < 12 do
    true
  end

  def validate_sched({:date, {:day, day, :month, month, :year, year}})
  when day > 0 and day < 31 and month > 0 and month < 12
  do
    true
  end

  def validate_sched({:time, {:hours, hours}}) when hours > 0 and hours <= 23 do
    true
  end

  def validate_sched({:time, {:hours, hours, :minutes, minutes}}) when hours > 0 and hours <= 23 and minutes > 0 and minutes < 60 do
    true
  end

  def validate_sched(_) do
    false
  end

  def configuration_to_list(configuration = %{}) do
    for {k, v} <- configuration, into: [], do: "#{k}=#{v}\r\n"
  end

  def list_to_string(l) do
    for i <- l, into: "", do: "#{i}"
  end

  def create_deploy_configuration(configuration_string, filename \\ "DeplyParameters.txt") do
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
end
