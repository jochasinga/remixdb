defmodule Remixdb.TcpServer do

  def start_link do
    spawn_link(fn ->
      port = 6379
      {:ok, socket} = :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true])
      IO.puts "Accepting connections on port: #{port}"
      Process.register self(), :remixdb_tcp_server
      loop_acceptor socket
    end)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    Remixdb.Client.start_link client
    loop_acceptor socket
  end
end

defmodule Remixdb.Server do
  def start do
    spawn_link(fn ->
      Remixdb.TcpServer.start_link
      Remixdb.KeyHandler.start_link
      receive  do
        :shutdown ->
          IO.puts "shutting down"
          true
      end
    end)
  end

  # def terminate(:normal, _) do
  #   IO.puts "Remixdb.Server terminating"
  #   :ok
  # end
end

