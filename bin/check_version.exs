package = :strong_params
current_version = "#{Application.spec(package, :vsn)}" 
package_url = String.to_charlist(Hex.State.fetch!(:api_url) <> "/packages/#{package}")

{:ok, {_, _, response}} =
  :httpc.request(:get, {package_url, [{~c"User-Agent", ~c"version_checker_script"}]}, [], [])

latest_version =
  response
  |> Jason.decode!()
  |> Map.fetch!("releases")
  |> Enum.map(&Map.fetch!(&1, "version"))
  |> Enum.sort(fn a, b -> Version.compare(a, b) == :gt end)
  |> List.first()

unless Version.compare(current_version, latest_version) == :gt do
  Mix.shell().error(
    "New version should be greater than '#{latest_version}' got '#{current_version}'"
  )

  exit({:shutdown, 1})
end
