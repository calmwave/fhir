defmodule FHIR.Helper do
  @moduledoc """
  Helper functions to be used during the handling of the FHIR data.
  """

  @doc """
  Filter a FHIR bundle response, which might contain many kinds of resources, and return only
  the entries of a given type.
  """
  @spec resources_by_type(FHIR.R4.Bundle.t(), String.t()) :: list()
  def resources_by_type(bundle, type) do
    bundle.entry
    |> Enum.map(& &1.resource)
    |> Enum.filter(&(&1.resource_type == type))
  end
end
