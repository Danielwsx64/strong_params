defmodule StrongParams.FilterPlug do
  import Plug.Conn

  alias StrongParams.{Error, Filter}

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%{halted: true} = conn, _opts), do: conn

  def call(%{params: params} = conn, opts) do
    params
    |> Filter.apply(opts)
    |> update_conn(conn, opts)
  end

  defp update_conn(%Error{} = error, conn, opts) do
    caller = Keyword.get(opts, :caller)

    caller
    |> apply(:__info__, [:attributes])
    |> Keyword.get(:strong_params_controller_fallback, [:unregistered])
    |> case do
      [:unregistered] ->
        conn
        |> send_resp(:bad_request, "Bad Request. Missing required parameters.")
        |> halt()

      [{:module, plug}] ->
        plug.call(conn, error)

      [{:function, func}] ->
        apply(caller, func, [conn, error])
    end
  end

  defp update_conn(%{} = params, conn, _opts), do: %{conn | params: params}
end
