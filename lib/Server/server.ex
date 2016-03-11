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
  def init(%ServerState{server: _server, commands: _commands, systems: _systems} = state) do
    # IO.puts(
    # """
    # Initializing deploy client server with the following options:
    # server: #{inspect server}
    # commands: #{inspect commands}
    # systems: #{inspect systems}
    # """)
    # IO.puts "Deploy client server started with state: #{inspect state}"
    {:ok, state}
  end



  def handle_call({:start_deploy, system, configuration, _options}, _from, %ServerState{} = state) do
    configuration |>
    BuildClient.Client.configuration_to_list |>
    BuildClient.Client.list_to_string |>
    # String.replace("/", "\\") |>
    BuildClient.Client.create_deploy_configuration()
    system |> set_system_configuration(:deploy_configuration)
    l = spawn_link BuildClient.Client, :run_deploy_script, []
    IO.puts "Deploy script for #{system} has been spawned with PID #{inspect l}"
    {:reply, :ok, state}
  end

  def handle_call({:start_build, system, configuration, _options}, _from, %ServerState{} = state) do
    configuration |>
    BuildClient.Client.configuration_to_list |>
    BuildClient.Client.list_to_string |>
    # String.replace("/", "\\") |>
    BuildClient.Client.create_build_configuration()
    system |> set_system_configuration(:build_configuration)
    l = spawn_link BuildClient.Client, :run_build_script, []
    IO.puts "Build script for #{system} has been spawned with PID #{inspect l}"
    {:reply, :ok, state}
  end

  def handle_call(:ping, from, state) do
    IO.puts "Ping received from #{inspect from}"
    {:reply, :pong, state}
  end

end
