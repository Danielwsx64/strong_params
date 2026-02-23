defmodule StrongParams.Filter do
  @moduledoc false

  alias StrongParams.Error

  defguardp is_cast_type(type) when is_atom(type) or is_tuple(type)

  @forbidden_msg "is not a permitted parameter"
  @invalid_msg "is invalid"
  @required_msg "is required"

  def apply(params, filters) do
    required = Keyword.get(filters, :required, [])
    permitted = Keyword.get(filters, :permitted, [])
    must_check_forbidden = Keyword.get(filters, :forbidden_params_err, false)

    required
    |> filter_required(params)
    |> filter_permitted(permitted, params)
    |> check_forbidden_params(params, must_check_forbidden)
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

  defp check_forbidden_params(filtered, params, true) when not is_struct(filtered) do
    with :ok <- check_forbidden(:ok, params, filtered) do
      filtered
    end
  end

  defp check_forbidden_params(result, _params, _must_check_fbdn), do: result

  defp check_forbidden(previous_err, params, filtered) do
    Enum.reduce(params, previous_err, fn {key, value}, err_acc ->
      case(fetch_key_value(key, filtered)) do
        {:ok, filtered_value} -> deep_check_forbidden(err_acc, value, filtered_value, key)
        :error -> add_forbidden_error(err_acc, key)
      end
    end)
  end

  defp deep_check_forbidden(previous_err, params, filtered, key) when is_map(params) do
    case check_forbidden(:ok, params, filtered) do
      :ok -> previous_err
      new_error -> add_forbidden_error(previous_err, key, new_error)
    end
  end

  defp deep_check_forbidden(previous_err, [h | _t] = list, filtered, key) when is_map(h) do
    list
    |> Enum.with_index()
    |> Enum.reduce(:ok, fn {params, index}, acc ->
      check_forbidden(acc, params, Enum.at(filtered, index))
    end)
    |> case do
      :ok -> previous_err
      new_error -> add_forbidden_error(previous_err, key, new_error)
    end
  end

  defp deep_check_forbidden(previous_err, _params, _filtered, _key), do: previous_err

  defp apply_filters(initial, filters, params, mode) do
    {result, _params} = Enum.reduce(filters, {initial, params}, &reduce_function(&1, &2, mode))

    result
  end

  defp deep_merge(original, override) when is_map(original) and is_map(override) do
    Map.merge(original, override, &resolve_conflict/3)
  end

  defp resolve_conflict(_key, original, override) when is_map(original) and is_map(override) do
    deep_merge(original, override)
  end

  defp resolve_conflict(_key, original, override) when is_list(original) and is_list(override) do
    original
    |> Enum.zip(override)
    |> Enum.map(fn {left, right} -> deep_merge(left, right) end)
  end

  defp resolve_conflict(_key, _original, override), do: override

  defp reduce_function(filter, {result, params}, mode) when is_atom(filter) do
    params_value = get_key(params, filter, :key_not_found)

    result
    |> add_to_result(filter, params_value, mode)
    |> respond_reduce_with(params)
  end

  defp reduce_function({filter, type}, {result, params}, mode)
       when is_atom(filter) and is_cast_type(type) do
    casted_value =
      params
      |> get_key(filter, :key_not_found)
      |> cast_value(type)

    result
    |> add_to_result(filter, casted_value, mode)
    |> respond_reduce_with(params)
  end

  defp reduce_function({filter, filter_rest}, {result, params}, mode) when is_atom(filter) do
    params_value = get_key(params, filter, :key_not_found)

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

  defp reduce_function(filters, {%{}, [] = params}, :required) when is_list(filters) do
    filters
    |> Enum.reduce(%{}, &reduce_empty_required_list/2)
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

  defp reduce_empty_required_list(key, acc) when is_atom(key) do
    add_to_result(acc, key, :key_not_found, :required)
  end

  defp reduce_empty_required_list({key, _value}, acc) when is_atom(key) do
    reduce_empty_required_list(key, acc)
  end

  defp add_to_result(%Error{errors: errors} = error, key, :key_not_found, :required) do
    %{error | errors: Map.put(errors, key, @required_msg)}
  end

  defp add_to_result(_result, key, :key_not_found, :required) do
    %Error{type: "required", errors: Map.new([{key, @required_msg}])}
  end

  defp add_to_result(result, _key, :key_not_found, :permitted), do: result

  defp add_to_result(%Error{errors: errors} = error, key, :invalid_value, _mode) do
    %{error | errors: Map.put(errors, key, @invalid_msg)}
  end

  defp add_to_result(_result, key, :invalid_value, _mode) do
    %Error{type: "invalid", errors: Map.new([{key, @invalid_msg}])}
  end

  defp add_to_result(%Error{errors: first_errors} = error, key, %Error{errors: errors}, _mode) do
    %{error | errors: Map.put(first_errors, key, errors)}
  end

  defp add_to_result(_result, key, %Error{errors: errors} = error, _mode) do
    %{error | errors: Map.new([{key, errors}])}
  end

  defp add_to_result(%Error{} = error, _key, _value, _mode), do: error
  defp add_to_result(result, key, value, _mode), do: Map.put_new(result, key, value)

  defp add_forbidden_error(previous, key, new_err \\ nil)

  defp add_forbidden_error(:ok = _previous, key, nil) do
    %Error{type: "forbidden", errors: %{key => @forbidden_msg}}
  end

  defp add_forbidden_error(%Error{errors: errors} = error, key, nil) do
    %{error | errors: Map.put(errors, key, @forbidden_msg)}
  end

  defp add_forbidden_error(previous, _key, :ok), do: previous

  defp add_forbidden_error(:ok, key, %Error{errors: errors}) do
    %Error{type: "forbidden", errors: %{key => errors}}
  end

  defp add_forbidden_error(%Error{errors: parent_errors} = error, key, %Error{errors: errors}) do
    %{error | errors: Map.put(parent_errors, key, errors)}
  end

  defp respond_reduce_with(result, params), do: {result, params}

  defp fetch_key_value(key, filtered) do
    with {:ok, key_as_atom} <- to_existing_atom(key) do
      Map.fetch(filtered, key_as_atom)
    end
  end

  defp to_existing_atom(string) do
    {:ok, String.to_existing_atom(string)}
  rescue
    _any -> :error
  end

  defp get_key(%{} = map, key, default) do
    case Map.fetch(map, to_string(key)) do
      {:ok, value} -> value
      :error -> Map.get(map, key, default)
    end
  end

  defp get_key(_map, _key, default), do: default

  defp cast_value(:key_not_found, _type), do: :key_not_found

  if Code.ensure_loaded?(Ecto) do
    defp cast_value(value, type) do
      case Ecto.Type.cast(type, value) do
        {:ok, casted_value} -> casted_value
        {:error, _reason} -> :invalid_value
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
