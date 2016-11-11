defmodule Plug.Adapters.Cowboy.Handler do
  @moduledoc false
  @connection Plug.Adapters.Cowboy.Conn
  @already_sent {:plug_conn, :sent}

  def init(req, {plug, opts}) do
    {__MODULE__, req, {plug, opts}}
  end

  def upgrade(req, env, __MODULE__, {plug, opts}, _timeout, _hibernate) do
    conn = @connection.conn(req)
    try do
      %{adapter: {@connection, req}} =
        conn
        |> plug.call(opts)
        |> maybe_send(plug)

      {:ok, req, Map.put_new(env, :result, :ok)}
    catch
      :error, value ->
        stack = System.stacktrace()
        exception = Exception.normalize(:error, value, stack)
        reason = {{exception, stack}, {plug, :call, [conn, opts]}}
        terminate(reason, req, stack)
      :throw, value ->
        stack = System.stacktrace()
        reason = {{{:nocatch, value}, stack}, {plug, :call, [conn, opts]}}
        terminate(reason, req, stack)
      :exit, value ->
        stack = System.stacktrace()
        reason = {value, {plug, :call, [conn, opts]}}
        terminate(reason, req, stack)
    after
      receive do
        @already_sent -> :ok
      after
        0 -> :ok
      end
    end
  end

  defp maybe_send(%Plug.Conn{state: :unset}, _plug),      do: raise Plug.Conn.NotSentError
  defp maybe_send(%Plug.Conn{state: :set} = conn, _plug), do: Plug.Conn.send_resp(conn)
  defp maybe_send(%Plug.Conn{} = conn, _plug),            do: conn
  defp maybe_send(other, plug) do
    raise "Cowboy adapter expected #{inspect plug} to return Plug.Conn but got: #{inspect other}"
  end

  defp terminate(reason, _req, _stack) do
    exit(reason)
  end
end
