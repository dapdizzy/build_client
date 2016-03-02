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

  defp get_server_name do
    serverNode = Application.get_env(:build_client, :server_node)
    serverName = Application.get_env(:build_client, :server_name)
    {serverName, serverNode}
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
