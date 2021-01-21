defmodule StrongParams.FilterPlugTest do
  use ExUnit.Case, async: true

  alias Plug.Conn
  alias StrongParams.FilterPlug

  describe "init/1" do
    test "keep options" do
      opts = [required: [:name], permited: [:alias], caller: :module]

      assert FilterPlug.init(opts) == opts
    end
  end

  describe "call/2" do
    setup do
      {:ok, conn: Phoenix.ConnTest.build_conn()}
    end

    test "apply params filter" do
      conn = %Conn{
        params: %{
          "name" => "Johnny Lawrence",
          "description" => "user description",
          "role" => "admin"
        }
      }

      opts = [required: [:name, :description]]

      result = FilterPlug.call(conn, opts)

      assert result.params == %{description: "user description", name: "Johnny Lawrence"}
    end

    test "when has error and fallback isn't set halt connection with status 400", %{conn: conn} do
      defmodule WithOutFallback do
        Module.register_attribute(__MODULE__, :strong_params_controller_fallback, persist: true)

        @strong_params_controller_fallback [:unregistered]
      end

      opts = [required: [:name], caller: WithOutFallback]

      result = FilterPlug.call(conn, opts)

      assert result.state == :sent
      assert result.status == 400
      assert result.halted == true
      assert result.resp_body == "Bad Request. Missing required parameters."
    end

    test "use fallback when it is set", %{conn: conn} do
      defmodule WithModuleFallback do
        import Plug.Conn
        Module.register_attribute(__MODULE__, :strong_params_controller_fallback, persist: true)

        @strong_params_controller_fallback [{:module, WithModuleFallback}]

        def init(opts), do: opts

        def call(conn, error), do: send_resp(conn, :bad_request, inspect(error))
      end

      opts = [required: [:name], caller: WithModuleFallback]

      result = FilterPlug.call(conn, opts)

      assert result.state == :sent
      assert result.status == 400

      assert result.resp_body ==
               "%StrongParams.Error{errors: %{name: \"is required\"}, type: \"required\"}"
    end

    test "use fallback function when it is set", %{conn: conn} do
      defmodule WithFunctionFallback do
        import Plug.Conn
        Module.register_attribute(__MODULE__, :strong_params_controller_fallback, persist: true)

        @strong_params_controller_fallback [{:function, :call}]

        def init(opts), do: opts

        def call(conn, error), do: send_resp(conn, :bad_request, inspect(error))
      end

      opts = [required: [:name], caller: WithFunctionFallback]

      result = FilterPlug.call(conn, opts)

      assert result.state == :sent
      assert result.status == 400

      assert result.resp_body ==
               "%StrongParams.Error{errors: %{name: \"is required\"}, type: \"required\"}"
    end

    test "ignore halted conn", %{conn: conn} do
      opts = [required: [:name], controller_fallback: :unregistered]

      conn = %{conn | halted: true}

      result = FilterPlug.call(conn, opts)

      assert result == conn
    end
  end
end
