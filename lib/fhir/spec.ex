defmodule FHIR.Spec do
  @moduledoc """
  Functions for working with FHIR's machine-readable specifications.
  """

  @doc """
  Classify a given definition from the FHIR schema with metadata we need to
  convert it to Elixir structures
  """
  @spec tag_definition(FHIR.version(), {String.t(), map()}) ::
          {String.t(), {:simple, :atom} | {:module, map()}}
  def tag_definition(_version, {name, %{"type" => "integer"}}), do: {name, {:simple, :integer}}
  def tag_definition(_version, {name, %{"type" => "number"}}), do: {name, {:simple, :float}}

  def tag_definition(_version, {name, %{"type" => type}}),
    do: {name, {:simple, String.to_atom(type)}}

  # A special case in the FHIR schema, but we can treat as a string for our purposes
  def tag_definition(_version, {"xhtml", _}), do: {"xhtml", {:simple, :string}}

  # A special case in the FHIR schema, will end up being a map field that specifically gets structs
  def tag_definition(_version, {"ResourceList", _}), do: {"ResourceList", {:simple, :map}}

  def tag_definition(version, {name, other}) do
    module_name = Module.concat([FHIR, version, normalize_base_name(name)])
    {name, {:module, Map.put(other, "name", module_name)}}
  end

  @doc """
  Convert from FHIR's format for base names (which contains capitals and underscores) to
  an elixir-style module name.
  """
  @spec normalize_base_name(String.t()) :: String.t()
  def normalize_base_name(name), do: String.replace(name, "_", "")
end
