defmodule StrongParams do
  @moduledoc """
  It filters request params keeping only explicitly enumerated parameters.
  """

  @doc """
  Macro to add filter for action parameters.

  It adds a `Plug` to filter request params before `Phoenix` call the respective
  controller action. This macro must be called inside a Phoenix controller implementation.

  The first given argument must be a valid action name. The second must be a `Keyword`
  with the list of required and permitted parameters. The `Keyword` may have both lists or
  just one of them:

    * `:permitted` - List of parameters to keep. If some of listed parameters is missing no error is returned.
    * `:required` - List of parameters that are required. In case of missing parameters a error will be returned with a map enumerating the missing parameters.

  ```elixir
  filter_for(:index, required: [:name, :email], permitted: [:nickname])
  ```

  For nested parameters you must use a keyword.

  Exemple:

  ```elixir
  filter_for(:index, required: [:name, :email, address: [:street, :city]], permitted: [:nickname])

  # Expected filtered parameters
  %{
     name: "Johnny Lawrence",
     nickname: "John",
     email: "john@mail.com",
     address: %{
       street: "5º Avenue",
       city: "NY"
     }
  }
  ```

  For a list of params you must use a nested list

  Example:

  ```elixir
  filter_for(:create, required: [:name, attachments: [[:name]]])

  # Expected filtered parameters
  %{
     name: "Johnny Lawrence",
     attachments: [
       %{name: "file.jpg"},
       %{name: "doc.pdf"}
     ]
   }
  ```

  ## Cast value

  `Ecto.Type` is used to the casting, so `ecto` needs to be
  available as a dependency in your app.

  Add to your `mix.exs`.

  ```elixir
  {:ecto, "~> x.x"}
  ```

  To cast values you must provide a tuple {field, type}

  Example:

  ```elixir
  filter_for(:create, required: [{:id, Ecto.UUID}, {:date, :date}])

  # Expected filtered parameters
  %{
     id: "11268bd3-5e41-4e6f-bf28-f3e167f87767",
     date: ~D[2021-11-29]
   }
  ```

  Any custom `Ecto.Type` or [ecto primitive types](https://hexdocs.pm/ecto/Ecto.Schema.html#module-primitive-types)
  are valid types.

  """

  @type parameters_list :: [atom | [{atom, parameters_list()}]]
  @type filters ::
          [required: parameters_list, permitted: parameters_list]
          | [required: parameters_list]
          | [permitted: parameters_list]

  @spec filter_for(atom, filters()) :: any
  defmacro filter_for(filter_action, filters) do
    guard =
      {:{}, [],
       [
         :==,
         [line: __CALLER__.line],
         [{:{}, [], [:action, [line: __CALLER__.line], nil]}, filter_action]
       ]}

    filters = Keyword.put(filters, :caller, __CALLER__.module)

    quote do
      @plugs {unquote(StrongParams.FilterPlug), unquote(filters), unquote(guard)}
    end
  end

  defmacro __using__(_opts) do
    quote do
      @before_compile StrongParams

      import StrongParams
    end
  end

  defmacro __before_compile__(env) do
    controller_fallback = Module.get_attribute(env.module, :phoenix_fallback)

    Module.register_attribute(env.module, :strong_params_controller_fallback, persist: true)

    quote do
      @strong_params_controller_fallback unquote(controller_fallback)
    end
  end
end
