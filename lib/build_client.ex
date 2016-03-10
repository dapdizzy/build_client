defmodule BuildClient do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    serverNode = Application.get_env(:build_client, :server_node)
    serverName = Application.get_env(:build_client, :server_name)

    # IO.puts "Server node: #{serverNode}, Serve rname: #{serverName}"

    IO.puts "Connecting to server #{serverNode}"
    case cr = Node.connect(serverNode) do
      true -> IO.puts "Successfuly connected"
      false -> raise "Failed to connect to server. Contact your AX Build Admnistrator."
      :ignore -> raise "Seem like the server node is not alive. Contact your AX Build Administrator."
      _ -> raise "Weird connection result. Contact your AX Build Administrator."
    end
    # IO.puts "Connection result: #{inspect cr}"
    IO.puts "Connected nodes: #{inspect Node.list}"

    server = {serverName, serverNode}
    commands = server |> BuildClient.Client.list_commands
    systems = server |> BuildClient.Client.list_systems

    children = [
      worker(BuildClient.Server, [server, commands, systems]),
      worker(BuildClient.Parser, [server, commands, systems])
      # Define workers and child supervisors to be supervised
      # worker(BuildClient.Worker, [arg1, arg2, arg3]),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BuildClient.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
