defmodule BuildClient.Server do
  use GenServer

  # Client API
  def start_link(state) do
    IO.puts "Starting deploy client server with state: #{inspect state}"
    GenServer.start_link(__MODULE__, state, name: BuildClient)
  end

  # Server Callbacks
  def init(state) do
    IO.puts "Deploy client server started with state: #{inspect state}"
    {:ok, state}
  end

  def handle_call({:start_deploy, system, configuration, _options}, _from, state) do
    configuration |>
    BuildClient.Client.configuration_to_list |>
    BuildClient.Client.list_to_string |>
    String.replace("/", "\\") |>
    BuildClient.Client.create_deploy_configuration()
    l = spawn_link BuildClient.Client, :run_deploy_script, []
    IO.puts "Deploy script has been spawned with PID #{inspect l}"
    {:reply, :ok, state}
  end
end
