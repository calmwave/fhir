defmodule FHIR do
  @moduledoc """
  Library which implements a client for FHIR APIs as well as tools for working
  with resources in a FHIR-like shape.

  We create two complete sets of structs:
  - FHIR.{version}.{resource_name} -- structs which have the shape of the given FHIR resource
  - FHIR.{version}.{resource_name}.Search -- structs are used to represent a FHIR search, with
      fields for each allowed search filter
  """
  require FHIR.Schema

  @typedoc """
  A FHIR specification version (e.g. R4, STU3, etc).
  """
  @type version :: String.t()

  @typedoc """
  A module corresponding to a FHIR resource.
  """
  @type resource_module :: module()

  @typedoc """
  A struct representing a FHIR resource.
  """
  @type resource :: struct()

  @typedoc """
  A struct representing a set of FHIR search parameters.
  """
  @type search :: struct()

  @spec_directory Path.join(["json_schemas"])
  @versions ["R4"]

  # We use metaprogramming to convert FHIR's machine-readable documentation into code that covers
  # the full spec.

  # Puts the json schema specs for the given versions from the FHIR documentation server and
  # expands them into /json_schemas/
  FHIR.SchemaDownloader.download_and_extract!(@versions, @spec_directory)

  IO.puts("FHIR compiler: starting code generation.")

  # Generate modules for each schema in each version
  for version <- @versions do
    IO.puts("FHIR compiler: generate schema for version #{version}.")

    schema_file = Path.join([@spec_directory, version, "fhir.schema.json"])
    # Mark all schema files as dependencies of compilation so we'll recompile if they change
    @external_resource schema_file

    FHIR.Schema.generate_schemas(version, schema_file)
  end

  # Generate modules for each Search-able Resource in each version
  for version <- @versions do
    IO.puts("FHIR compiler: generate searches for version #{version}.")

    search_file = Path.join([@spec_directory, version, "search-parameters.json"])
    # Mark all schema files as dependencies of compilation so we'll recompile if they change
    @external_resource search_file

    FHIR.Search.generate_searches(version, search_file)
  end

  IO.puts("FHIR compiler: all done.")
end
