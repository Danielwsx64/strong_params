# StrongParams

[![GitHub Workflow Status](https://img.shields.io/github/workflow/status/Finbits/strong_params/CI?style=flat-square)](https://github.com/Finbits/strong_params/actions?query=workflow%3ACI)
[![Hex.pm](https://img.shields.io/hexpm/v/strong_params?style=flat-square)](https://hex.pm/packages/strong_params)
[![Hex.pm](https://img.shields.io/hexpm/l/strong_params?style=flat-square)](https://hex.pm/packages/strong_params)
[![Hex.pm](https://img.shields.io/hexpm/dt/strong_params?style=flat-square)](https://hex.pm/packages/strong_params)
[![codecov](https://img.shields.io/codecov/c/github/Finbits/strong_params?style=flat-square)](https://codecov.io/gh/Finbits/strong_params)

Inspired by Ruby on Rails Strong Parameters. It filters request params keeping only explicitly enumerated parameters.

In addition, parameters can be marked as required and flow through a controller fallback flow to end up as a 400 Bad Request with no effort.

## Installation

Add `StrongParams` to your application

mix.exs

```elixir
def deps do
  [
    {:strong_params, "~> 0.4.2"}
  ]
end
```

Update deps

```sh
mix deps.get
```

## Usage

`StrongParams` uses macros to apply the parameters filter. You must `use` _StrongParams_
in each controller you want filter parameters. The better way is using _StrongParams_
in you Phoenix App entrypoint inside `controller/0` block (it must be add after
use `Phoenix.Controller`).

/lib/your_phoenix_app.ex

```elixir
defmodule YourPhoenixApp do
  ...

  def controller do
    quote do
      use Phoenix.Controller, namespace: YourPhoenixApp
      use StrongParams

      ...

    end
  end
end
```

Then you can use macro `filter_for/2` inside your controller to apply the filters
for each action.

```elixir
defmodule YourPhoenixApp.UserController do
  use YourPhoenixApp, :controller

  alias YourPhoenixApp.User

  filter_for(:create, required: [:name, :email], permitted: [:nickname])

  def create(conn, %{name: _, email: _} = params) do

    user = %User{}
      |> User.changeset(params)
      |> Repo.insert()

    render(conn, user: user)
  end

end
```

In above example, once `filter_for/2` is defined for action `create` the second
argument received in action will be the filtered request parameters. The map `params`
has atomized keys, once the filter is defined as `atoms` (the lib don't create new atoms).

If some parameter enumerated as required is missing in received request the `Plug.Conn`
will be halted with status code `400` and a generic error message. If you add an
action fallback you can handle the filter error:

```elixir
defmodule YourPhoenixApp.UserController do
  use YourPhoenixApp, :controller

  action_fallback(YourPhoenixApp.Fallback)

  filter_for(:create, required: [:name, :email], permitted: [:nickname])

  ...

end


defmodule YourPhoenixApp.Fallback do
  alias StrongParams.Error

  def call(conn, %Error{errors: errors}) do
    send_resp(conn, 400, "Your custom msg #{inpect(errors)}")
  end
end
```

You must call `filter_for/2` for each action you want to filter the params.

```elixir
filter_for(:create, required: [:name, :email], permitted: [:nickname])
filter_for(:update, permitted: [:name, :email, :nickname])
```

## Contributing

[Contributing Guide](CONTRIBUTING.md)

## License

[Apache License, Version 2.0](LICENSE) © [Finbits](https://github.com/Finbits)
