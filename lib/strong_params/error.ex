defmodule StrongParams.Error do
  @moduledoc """
  This module defines a `t:StrongParams.Error.t/0` struct that stores filtering errors.

  When using `Phoenix` action_fallback the fallback module will receive a tuple of `{:error, %StrongParams.Error{}}`

  ```elixir
  defmodule YourPhoenixApp.Fallback do

    def call(conn, %StrongParams.Error{}) do
      send_resp(conn, 400, "Your custom msg")
    end
  end
  ```
  """

  @type errors_map :: %{
          optional(atom) => binary,
          optional(atom) => errors_map
        }

  @type t :: %__MODULE__{
          type: binary,
          errors: errors_map
        }

  defstruct [:type, :errors]
end
