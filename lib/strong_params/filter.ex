defmodule StrongParams.Filter do
  @moduledoc false
  import Map, only: [put_new: 3, get: 3]
  import DeepMerge, only: [deep_merge: 2]

  alias StrongParams.Error

  def apply(params, filters) do
    required = Keyword.get(filters, :required, [])
    permited = Keyword.get(filters, :permited, [])

    required
    |> filter_required(params)
    |> filter_permited(permited, params)
  end

  defp filter_required(required, params) do
    apply_filters(%{}, required, params, :required)
  end

  defp filter_permited(%Error{} = error, _permited, _params), do: error

  defp filter_permited(initial, permited, params) do
    %{}
    |> apply_filters(permited, params, :permited)
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

  defp reduce_function({filter, filter_rest}, {result, params}, mode) when is_atom(filter) do
    params_value = get(params, to_string(filter), %{})
    filtered = apply_filters(%{}, filter_rest, params_value, mode)

    result
    |> add_to_result(filter, filtered, mode)
    |> respond_reduce_with(params)
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

  defp add_to_result(result, _key, :key_not_found, :permited), do: result

  defp add_to_result(%Error{errors: first_errors} = error, key, %Error{errors: errors}, _mode),
    do: %{error | errors: Map.put(first_errors, key, errors)}

  defp add_to_result(%{}, key, %Error{errors: errors} = error, _mode),
    do: %{error | errors: Map.new([{key, errors}])}

  defp add_to_result(%Error{} = error, _key, _value, _mode), do: error
  defp add_to_result(%{} = result, key, value, _mode), do: put_new(result, key, value)

  defp respond_reduce_with(result, params), do: {result, params}
end
