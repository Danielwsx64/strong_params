defmodule StrongParams.Filter do
  import Map, only: [put_new: 3, get: 3]
  import DeepMerge, only: [deep_merge: 2]

  alias StrongParams.Error

  def apply(params, filters, _opts \\ []) do
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

  def apply_filters(%Error{} = error, _filters, _params, :permited), do: error

  def apply_filters(initial, filters, params, mode) do
    {result, _params} = Enum.reduce(filters, {initial, params}, &reduce_function(&1, &2, mode))

    result
  end

  defp reduce_function(filter, {result, params}, mode) when is_atom(filter) do
    params_value = get_from(params, to_string(filter))

    result
    |> add_to_result(filter, params_value, mode)
    |> respond_reduce_with(params)
  end

  defp reduce_function({filter, filter_rest}, {result, params}, mode) when is_atom(filter) do
    params_value = get_from(params, to_string(filter))
    filtered = apply_filters(%{}, filter_rest, params_value, mode)

    result
    |> add_to_result(filter, filtered, mode)
    |> respond_reduce_with(params)
  end

  defp add_to_result(%Error{errors: errors} = error, key, :key_not_found, :required),
    do: %{error | errors: [{key, "is required"} | errors]}

  defp add_to_result(%{}, key, :key_not_found, :required),
    do: %Error{type: "required", errors: [{key, "is required"}]}

  defp add_to_result(result, _key, :key_not_found, :permited), do: result

  defp add_to_result(%Error{errors: first_errors} = error, key, %Error{errors: errors}, _mode),
    do: %{error | errors: [{key, errors} | first_errors]}

  defp add_to_result(%{}, key, %Error{errors: errors} = error, _mode),
    do: %{error | errors: [{key, errors}]}

  defp add_to_result(%Error{} = error, _key, _value, _mode), do: error
  defp add_to_result(%{} = result, key, value, _mode), do: put_new(result, key, value)

  defp get_from(params, key), do: get(params, key, :key_not_found)

  defp respond_reduce_with(result, params), do: {result, params}
end
