defmodule FHIR.Query do
  @moduledoc false

  def validate_opts(opts) do
    # Check that base_url is included and is a string
    with {:base_url, {base_url, opts}} when is_binary(base_url) <-
           {:base_url, Keyword.pop(opts, :base_url)},
         # Check that base_url is parseable
         {:base_url_parse, {:ok, base_url}} <- {:base_url_parse, URI.new(base_url)},
         {request_function, opts} <- Keyword.pop(opts, :request_function, &Finch.request/2),
         {_token, opts} <- Keyword.pop(opts, :token, nil),
         # Check that we don't have any opts left over (typo check)
         {:excess_opts_check, []} <- {:excess_opts_check, opts} do
      %{base_url: base_url, request_function: request_function}
    else
      {:base_url, {nil, _}} ->
        {:error, "FHIR Client option base_url is required and must be a string"}

      {:base_url_parse, {_, result}} ->
        {:error, "couldn't parse base_url: #{result}"}

      {:excess_opts_check, kw} ->
        {:error, "unrecognized options: #{inspect(Keyword.keys(kw))}"}

      other ->
        other
    end
  end

  @doc """
  Make a FHIR search request.

  - `search` is a FHIR search struct (i.e. FHIR.{some_version}.{some_resource}.Search)
  """
  def search(base_url, search, more_opts \\ []) do
    more_opts = Keyword.put(more_opts, :base_url, base_url)
    token = Keyword.get(more_opts, :token)
    request_function = Keyword.get(more_opts, :request_function)

    resource = search.__struct__.base()
    version = search.__struct__.version()
    params = search.__struct__.convert_to_query_list(search)

    url =
      URI.parse(base_url)
      |> URI.append_path("/#{resource}")
      |> URI.append_query(URI.encode_query(params))
      |> URI.to_string()

    get(url, version, token, request_function)
  end

  @doc """
  Make a FHIR read request.

  - `schema_module` is a FHIR schema module (i.e. FHIR.{some_version}.{some_resource}).
  - `id` is the ID of the resource to read.
  """
  def read(base_url, schema_module, id, more_opts \\ []) do
    more_opts = Keyword.put(more_opts, :base_url, base_url)
    token = Keyword.get(more_opts, :token)
    request_function = Keyword.get(more_opts, :request_function)

    resource = schema_module.base()
    version = schema_module.version()

    url =
      URI.parse(base_url)
      |> URI.append_path("/#{resource}/#{id}")
      |> URI.to_string()

    get(url, version, token, request_function)
  end

  @doc """
  Make an HTTP GET request again `url` and decode the response as a FHIR version
  `version` response.
  """
  @spec get(String.t(), FHIR.version(), String.t()) :: {:ok, map()} | {:error, term()}
  def get(url, version, token, request_function \\ nil) do
    # The way `read` calls us, there will always be a request function argument passed in
    # but that might be `nil`, so use this somewhat unusual way to get a default value
    # instead of putting it straight into the argument as a default.
    request_function = request_function || (&Finch.request/2)

    url
    |> then(&Finch.build(:get, &1, headers(token)))
    |> then(&request_function.(&1, FHIR.Client.Finch))
    |> case do
      {:ok, %{status: 200, body: body}} ->
        decode_response(body, version)

      other ->
        other
    end
  end

  defp headers(nil), do: []

  defp headers(token) do
    [{"Authorization", "Bearer #{token}"}, {"Accept", "application/json"}]
  end

  @doc """
  Take a string of JSON as `body` and a FHIR `version`, return a schema struct.
  """
  @spec decode_response(String.t(), FHIR.version()) :: {:ok, map()} | {:error, term()}
  def decode_response(body, version) do
    case Jason.decode(body) do
      {:ok, resource} ->
        {:ok, FHIR.Client.ResourceSchemafier.schemafy(resource, version)}

      other ->
        other
    end
  end
end
