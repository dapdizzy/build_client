defmodule BuildClient do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    serverNode = Application.get_env(:build_client, :server_node)
    serverName = Application.get_env(:build_client, :server_name)

    IO.puts "Server node: #{serverNode}, Serve rname: #{serverName}"

    IO.puts "Connecting to server #{serverNode}"
    cr = Node.connect(serverNode)
    IO.puts "Connection result: #{inspect cr}"
    IO.puts "Connected nodes: #{inspect Node.list}"

    children = [
      worker(BuildClient.Server, [[]]),
      worker(BuildClient.Parser, [])
      # Define workers and child supervisors to be supervised
      # worker(BuildClient.Worker, [arg1, arg2, arg3]),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BuildClient.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
