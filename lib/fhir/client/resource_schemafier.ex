defmodule FHIR.Client.ResourceSchemafier do
  @moduledoc """
  Functions for converting from elixir maps, lists, and other values to FHIR resource structures.
  """

  @doc """
  Convert a plain map representing a raw FHIR JSON reply and convert it to a set of nested structs.
  """
  @spec schemafy(list() | map(), FHIR.version()) :: FHIR.resource()
  def schemafy(list, version) when is_list(list) do
    Enum.map(list, &schemafy(&1, version))
  end

  def schemafy(%{"resource" => resource}, version), do: schemafy(resource, version)

  def schemafy(%{"resourceType" => type} = resource, version) do
    schema_module = Module.concat([FHIR, version, type])

    schemafy_map_resource(schema_module, resource)
  end

  defp schemafy_map_resource(schema_module, resource) do
    resource
    |> Enum.map(fn {api_key, value} ->
      struct_key = schema_module.property_name_to_struct_key(api_key)
      {struct_key, schemafy_value(schema_module, struct_key, value)}
    end)
    |> then(fn values ->
      struct(schema_module, values)
    end)
  end

  @doc """
  Convert a single field value based on its type and parent resource (which determines spec version).
  """
  @spec schemafy_value(FHIR.resource_module(), atom(), :any) :: :any
  def schemafy_value(schema_module, struct_key, value) do
    type = schema_module.__schema__(:type, struct_key)
    version = schema_module.version()

    do_schemafy_value(version, type, value)
  end

  defp do_schemafy_value(
         version,
         :map,
         %{"resourceType" => resource_type} = value
       ) do
    schema_module = Module.concat([FHIR, version, resource_type])
    schemafy_map_resource(schema_module, value)
  end

  defp do_schemafy_value(
         _version,
         {:parameterized, {Ecto.Embedded, %{cardinality: :one, related: schema_module}}},
         value
       ) do
    schemafy_map_resource(schema_module, value)
  end

  defp do_schemafy_value(
         _version,
         {:parameterized, {Ecto.Embedded, %{cardinality: :many, related: schema_module}}},
         value
       ) do
    Enum.map(value, &schemafy_map_resource(schema_module, &1))
  end

  defp do_schemafy_value(_version, :float, value), do: value

  defp do_schemafy_value(_version, :boolean, value), do: value

  defp do_schemafy_value(_version, :string, value), do: value

  defp do_schemafy_value(_version, {:array, _}, value), do: value

  defp do_schemafy_value(_version, {:parameterized, {Ecto.Enum, %{on_load: mapping}}}, value) do
    Map.get(mapping, value)
  end
end
