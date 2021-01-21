defmodule StrongParams do
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
