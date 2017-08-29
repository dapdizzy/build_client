defmodule BuildClient.Server do
  use GenServer

  # Client API
  def start_link(server, commands, systems) do
    # IO.puts(
    # """
    # Starting deploy client with the following options:
    # server: #{inspect server}, commands: #{inspect commands}, systems: #{inspect systems}
    # """)
    # IO.puts "Starting deploy client server with state: #{inspect state}"
    GenServer.start_link(__MODULE__, %ServerState{server: server, commands: commands, systems: systems}, name: BuildClient)
  end

  # Server Callbacks
  def init(%ServerState{server: server, commands: _commands, systems: _systems} = state) do
    # IO.puts(
    # """
    # Initializing deploy client server with the following options:
    # server: #{inspect server}
    # commands: #{inspect commands}
    # systems: #{inspect systems}
    # """)
    # IO.puts "Deploy client server started with state: #{inspect state}"

    IO.puts "Establishing server connectivity"
    :ok = server |> BuildClient.Client.connect({BuildClient, node()})
    IO.puts "Connected"

    ensure_scripts_present

    {:ok, state}
  end



  def handle_call({:start_deploy, system, configuration, _options}, _from, %ServerState{} = state) do
    configuration |>
    Map.merge(BuildClient.Client.get_system_client_configuration_parameters(system, :deploy_configuration)) |>
    BuildClient.Client.configuration_to_list |>
    BuildClient.Client.list_to_string |>
    # String.replace("/", "\\") |>
    BuildClient.Client.create_deploy_configuration()
    system |> BuildClient.Client.set_system_configuration(:deploy_configuration)
    l = spawn_link BuildClient.Client, :run_deploy_script, []
    IO.puts "Deploy script for #{system} has been spawned with PID #{inspect l}"
    {:reply, :ok, state}
  end

  def handle_call({:start_build, system, configuration, _options}, _from, %ServerState{} = state) do
    configuration |>
    Map.merge(BuildClient.Client.get_system_client_configuration_parameters(system, :build_configuration)) |>
    BuildClient.Client.configuration_to_list |>
    BuildClient.Client.list_to_string |>
    # String.replace("/", "\\") |>
    BuildClient.Client.create_build_configuration()
    system |> BuildClient.Client.set_system_configuration(:build_configuration)
    l = spawn_link BuildClient.Client, :run_build_script, []
    IO.puts "Build script for #{system} has been spawned with PID #{inspect l}"
    {:reply, :ok, state}
  end

  def handle_call(:ping, from, state) do
    IO.puts "Ping received from #{inspect from}"
    {:reply, :pong, state}
  end

  def handle_call({:build_info, build_info}, _from, state) do
    case build_info do
      %{latest_build: latest_build, last_successful_build: last_successful_build} ->
        IO.puts "Latest build: #{latest_build}\nLast successful build: #{last_successful_build}"
      %{latest_build: latest_build} ->
        IO.puts "Latest build: #{latest_build}"
      _ ->
        IO.puts "No information available"
    end
    {:reply, :ok, state}
  end

  # Helpers

  defp ensure_scripts_present do
    scripts_dir = Application.get_env(:build_client, :scripts_dir, "")
    unless scripts_dir |> File.exists?, do: raise "Scripts directory (#{scripts_dir}) does not exist"
    case scripts_dir |> File.ls do
      {:ok, list} ->
        if list |> Enum.empty? do
          server_scripts_share = BuildClient.Client.get_scripts_share()
          IO.puts "Client scripts folder (#{scripts_dir}) is empty. Going to copy scripts from the server scripts share (#{server_scripts_share})"
          copy_scripts server_scripts_share, scripts_dir
        end
      {:error, reason} -> raise "#{reason}"
    end
  end

  defp copy_scripts(from, to) do
    ~s|robocopy "#{from}" "#{to}" /s /z|
      |> String.to_char_list
      |> :os.cmd
  end

end
