defmodule StrongParamsTest do
  use ExUnit.Case

  defmodule Fallback do
    def init(opts), do: opts

    def call(conn, error) do
      conn
      |> Plug.Conn.send_resp(400, inspect(error))
      |> Plug.Conn.halt()
    end
  end

  defmodule WithOutFallbackController do
    use Phoenix.Controller, namespace: StrongParams
    use StrongParams

    filter_for(:index, required: [:name])

    def index(conn, params) do
      send_resp(conn, :ok, inspect(params))
    end

    def create(conn, params) do
      send_resp(conn, :ok, inspect(params))
    end
  end

  defmodule FunctionFallbackController do
    use Phoenix.Controller, namespace: StrongParams
    use StrongParams

    action_fallback(:fallback_func)

    filter_for(:create, required: [:name])

    def fallback_func(conn, error), do: Fallback.call(conn, error)
  end

  defmodule ModuleFallbackController do
    use Phoenix.Controller, namespace: StrongParams
    use StrongParams

    action_fallback(Fallback)

    filter_for(:create, required: [:name])
  end

  defmodule TwoFiltersController do
    use Phoenix.Controller, namespace: StrongParams
    use StrongParams

    filter_for(:index, required: [:name])
    filter_for(:create, required: [:alias])

    action_fallback(Fallback)

    def index(conn, params) do
      send_resp(conn, :ok, inspect(params))
    end

    def create(conn, params) do
      send_resp(conn, :ok, inspect(params))
    end
  end

  test "persist module attribute" do
    assert :attributes
           |> WithOutFallbackController.__info__()
           |> Keyword.get(:strong_params_controller_fallback) == [:unregistered]

    assert :attributes
           |> ModuleFallbackController.__info__()
           |> Keyword.get(:strong_params_controller_fallback) == [
             {:module, StrongParamsTest.Fallback}
           ]

    assert :attributes
           |> FunctionFallbackController.__info__()
           |> Keyword.get(:strong_params_controller_fallback) == [{:function, :fallback_func}]
  end

  describe "filter_for/2" do
    setup do
      {:ok,
       conn:
         Phoenix.ConnTest.build_conn(:get, "/")
         |> Plug.Conn.fetch_query_params()
         |> Plug.Conn.put_private(:stack, [])}
    end

    test "add FilterPlug to given action", %{conn: conn} do
      conn = %{conn | params: %{"name" => "Johnny Lawrence"}}

      result = WithOutFallbackController.call(conn, :index)

      assert result.halted == false
      assert result.state == :sent
      assert result.status == 200
      assert result.params == %{name: "Johnny Lawrence"}
      assert result.resp_body == "%{name: \"Johnny Lawrence\"}"
    end

    test "keep conn params when action has no filters set", %{conn: conn} do
      conn = %{conn | params: %{"name" => "Johnny Lawrence"}}

      result = WithOutFallbackController.call(conn, :create)

      assert result.halted == false
      assert result.state == :sent
      assert result.status == 200
      assert result.params == %{"name" => "Johnny Lawrence"}
      assert result.resp_body == "%{\"name\" => \"Johnny Lawrence\"}"
    end

    test "respond with default error when controller has no fallback set", %{conn: conn} do
      result = WithOutFallbackController.call(conn, :index)

      assert result.halted == true
      assert result.state == :sent
      assert result.status == 400
      assert result.params == %{}
      assert result.resp_body == "Bad Request. Missing required parameters."
    end

    test "use fallback to handle filter error", %{conn: conn} do
      result = ModuleFallbackController.call(conn, :create)

      assert result.halted == true
      assert result.state == :sent
      assert result.status == 400
      assert result.params == %{}

      assert result.resp_body ==
               "%StrongParams.Error{errors: [name: \"is required\"], type: \"required\"}"
    end

    test "use fallback function to handle filter error", %{conn: conn} do
      result = FunctionFallbackController.call(conn, :create)

      assert result.halted == true
      assert result.state == :sent
      assert result.status == 400
      assert result.params == %{}

      assert result.resp_body ==
               "%StrongParams.Error{errors: [name: \"is required\"], type: \"required\"}"
    end

    test "multiples filters seted", %{conn: conn} do
      conn = %{conn | params: %{"name" => "Johnny Lawrence"}}

      index_result = TwoFiltersController.call(conn, :index)
      create_result = TwoFiltersController.call(conn, :create)

      assert index_result.halted == false
      assert index_result.state == :sent
      assert index_result.status == 200
      assert index_result.params == %{name: "Johnny Lawrence"}
      assert index_result.resp_body == "%{name: \"Johnny Lawrence\"}"

      assert create_result.halted == true
      assert create_result.state == :sent
      assert create_result.status == 400
      assert create_result.params == %{"name" => "Johnny Lawrence"}

      assert create_result.resp_body ==
               "%StrongParams.Error{errors: [alias: \"is required\"], type: \"required\"}"
    end
  end
end
