defmodule StrongParams.Filter do
  @moduledoc false
  import Map, only: [put_new: 3, get: 3]
  import DeepMerge, only: [deep_merge: 2]

  alias StrongParams.Error

  defguardp is_cast_type(type) when is_atom(type) or is_tuple(type)

  def apply(params, filters) do
    required = Keyword.get(filters, :required, [])
    permitted = Keyword.get(filters, :permitted, [])

    required
    |> filter_required(params)
    |> filter_permitted(permitted, params)
  end

  defp filter_required(required, params) do
    apply_filters(%{}, required, params, :required)
  end

  defp filter_permitted(%Error{} = error, _permitted, _params), do: error

  defp filter_permitted(initial, permitted, params) do
    %{}
    |> apply_filters(permitted, params, :permitted)
    |> deep_merge(initial)
  end

  defp apply_filters(initial, filters, params, mode) do
    {result, _params} = Enum.reduce(filters, {initial, params}, &reduce_function(&1, &2, mode))

    result
  end

  defp reduce_function(filter, {result, params}, mode) when is_atom(filter) do
    params_value = get(params, to_string(filter), :key_not_found)

    result
    |> add_to_result(filter, params_value, mode)
    |> respond_reduce_with(params)
  end

  defp reduce_function({filter, type}, {result, params}, mode)
       when is_atom(filter) and is_cast_type(type) do
    casted_value =
      params
      |> get(to_string(filter), :key_not_found)
      |> cast_value(type)

    result
    |> add_to_result(filter, casted_value, mode)
    |> respond_reduce_with(params)
  end

  defp reduce_function({filter, filter_rest}, {result, params}, mode) when is_atom(filter) do
    params_value = get(params, to_string(filter), :key_not_found)

    partial_result =
      case {params_value, mode} do
        {:key_not_found, :permitted} ->
          result

        {:key_not_found, :required} ->
          add_to_result(result, filter, apply_filters(%{}, filter_rest, %{}, mode), mode)

        {nil, _mode} ->
          add_to_result(result, filter, apply_filters(%{}, filter_rest, %{}, mode), mode)

        _other ->
          add_to_result(result, filter, apply_filters(%{}, filter_rest, params_value, mode), mode)
      end

    respond_reduce_with(partial_result, params)
  end

  defp reduce_function(filters, {%{}, params}, mode)
       when is_list(filters) and is_list(params) do
    params
    |> Enum.reduce_while([], &reduce_params_list(&1, &2, filters, mode))
    |> case do
      list when is_list(list) -> Enum.reverse(list)
      error -> error
    end
    |> respond_reduce_with(params)
  end

  defp reduce_function(filters, {%{}, params}, _mode) when is_list(filters),
    do: {%Error{type: "type", errors: "Must be a list"}, params}

  defp reduce_params_list(params, list, filters, mode) do
    case apply_filters(%{}, filters, params, mode) do
      %Error{} = error -> {:halt, error}
      result -> {:cont, [result | list]}
    end
  end

  defp add_to_result(%Error{errors: errors} = error, key, :key_not_found, :required),
    do: %{error | errors: Map.put(errors, key, "is required")}

  defp add_to_result(%{}, key, :key_not_found, :required),
    do: %Error{type: "required", errors: Map.new([{key, "is required"}])}

  defp add_to_result(result, _key, :key_not_found, :permitted), do: result

  defp add_to_result(%Error{errors: errors} = error, key, :invalid_value, _mode),
    do: %{error | errors: Map.put(errors, key, "is invalid")}

  defp add_to_result(%{}, key, :invalid_value, _mode),
    do: %Error{type: "invalid", errors: Map.new([{key, "is invalid"}])}

  defp add_to_result(%Error{errors: first_errors} = error, key, %Error{errors: errors}, _mode),
    do: %{error | errors: Map.put(first_errors, key, errors)}

  defp add_to_result(%{}, key, %Error{errors: errors} = error, _mode),
    do: %{error | errors: Map.new([{key, errors}])}

  defp add_to_result(%Error{} = error, _key, _value, _mode), do: error
  defp add_to_result(%{} = result, key, value, _mode), do: put_new(result, key, value)

  defp respond_reduce_with(result, params), do: {result, params}

  defp cast_value(:key_not_found, _type), do: :key_not_found

  if Code.ensure_loaded?(Ecto) do
    defp cast_value(value, type) do
      case Ecto.Type.cast(type, value) do
        {:ok, casted_value} -> casted_value
        :error -> :invalid_value
      end
    end
  else
    defp cast_value(_value, _type) do
      raise ArgumentError, """
      In order to cast a value you need to have ecto available as a dependency.

      Please add :ecto to your dependencies:

        {:ecto, "~> x.x"}

      """
    end
  end
end
