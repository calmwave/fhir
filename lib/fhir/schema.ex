defmodule FHIR.Schema do
  @moduledoc """
  Functions for metaprogramming modules based on FHIR resources.
  """

  require Logger

  @doc """
  Load a schema definition file for the given version and use it to define
  structs and modules for each included definition.
  """
  @spec generate_schemas(FHIR.version(), String.t()) :: list()
  def generate_schemas(version, schema_file) do
    schema =
      schema_file
      |> File.read!()
      |> Jason.decode!()

    definitions =
      schema["definitions"]
      |> Enum.map(&FHIR.Spec.tag_definition(version, &1))
      |> Enum.into(%{})

    for {name, {type, definition}} <- definitions do
      if type == :module do
        Code.eval_quoted(define_module(version, name, definition, definitions))
      end
    end
  end

  @doc """
  Returns the AST for a defmodule for a given FHIR resource.
  """
  @spec define_module(FHIR.version(), String.t(), map(), map()) :: Macro.t()
  def define_module(
        version,
        fhir_resource_name,
        %{
          "name" => name,
          "properties" => properties
        },
        definitions
      ) do
    quote do
      defmodule unquote(name) do
        use Ecto.Schema
        @timestamps_opts [type: :utc_datetime_usec]
        @derive Jason.Encoder
        @primary_key false
        @type t :: %__MODULE__{
                unquote_splicing(Enum.map(properties, &type_definition(&1, definitions)))
              }
        embedded_schema do
          unquote(Enum.map(properties, &field_definition(&1, definitions)))
        end

        def base, do: unquote(fhir_resource_name)
        def version, do: unquote(version)

        unquote(Enum.map(properties, &property_name_to_struct_key_head/1))
      end
    end
  end

  def define_module(
        _version,
        _fhir_resource_name,
        %{
          "name" => name
        },
        _definitions
      ) do
    Logger.warning("#{name} has no properties in schema.")

    quote do
    end
  end

  @doc """
  Same as `field_definition/3`, but takes a tuple of map and field metadata
  as the first argument.
  """
  @spec field_definition({String.t(), map()}, map()) :: Macro.t()
  def field_definition({name, definition}, definitions),
    do: field_definition(name, definition, definitions)

  @doc """
  Given a field name, field metadata, and a map of
  %{fhir_type_name => fhir_type_definition} (for associations), return an AST
  that defines that field in the schema struct.
  """
  @spec field_definition(String.t(), map(), map()) :: Macro.t()
  def(
    field_definition(
      property_name,
      %{"type" => "array", "items" => %{"$ref" => ref}},
      definitions
    )
  ) do
    case lookup_ref(ref, definitions) do
      {:simple, type} ->
        quote do
          field(unquote(property_name_to_atom(property_name)), {:array, unquote(type)})
        end

      {:module, %{"name" => name}} ->
        quote do
          embeds_many(unquote(property_name_to_atom(property_name)), unquote(name))
        end
    end
  end

  def field_definition(
        property_name,
        %{"type" => "array", "items" => %{"enum" => _values}},
        _definitions
      ) do
    quote do
      field(unquote(property_name_to_atom(property_name)), {:array, :string})
    end
  end

  def field_definition(property_name, %{"type" => "number"}, _definitions) do
    quote do
      field(unquote(property_name_to_atom(property_name)), :float)
    end
  end

  def field_definition(property_name, %{"type" => type}, _definitions) do
    quote do
      field(unquote(property_name_to_atom(property_name)), unquote(String.to_atom(type)))
    end
  end

  def field_definition(property_name, %{"const" => const}, _definitions) do
    quote do
      field(unquote(property_name_to_atom(property_name)), :string, default: unquote(const))
    end
  end

  def field_definition(property_name, %{"enum" => values}, _definitions) do
    values =
      Enum.map(values, fn v ->
        {String.to_atom(v), v}
      end)

    quote do
      field(unquote(property_name_to_atom(property_name)), Ecto.Enum, values: unquote(values))
    end
  end

  def field_definition(property_name, %{"$ref" => ref}, definitions) do
    case lookup_ref(ref, definitions) do
      {:simple, type} ->
        quote do
          field(unquote(property_name_to_atom(property_name)), unquote(type))
        end

      {:module, %{"name" => name}} ->
        quote do
          embeds_one(unquote(property_name_to_atom(property_name)), unquote(name))
        end
    end
  end

  @doc """
  Return an AST for a function head that converts a FHIR API property name to its elixir form.
  """
  @spec property_name_to_struct_key_head({String.t(), any()}) :: Macro.t()
  def property_name_to_struct_key_head({property_name, _}) do
    quote do
      def property_name_to_struct_key(unquote(property_name)),
        do: unquote(property_name_to_atom(property_name))
    end
  end

  @doc """
  Return the elixir atom form of a property name
  """
  @spec property_name_to_atom(String.t()) :: atom()
  def property_name_to_atom(property_name),
    do:
      property_name
      |> Macro.underscore()
      |> String.to_atom()

  @doc """
  Take a JSON schema "ref" value (`ref`) and return the corresponding type definition from `definitions`.
  """
  def lookup_ref(ref, definitions) do
    Map.get(definitions, String.replace(ref, "#/definitions/", ""))
  end

  # Helpers to emit a t() for each module so we can
  # leverage Dialyzer. For now, we emit the bare minumum that
  # makes Dialyzer happy until the point where we can revisit this
  # module.

  defp type_definition({property_name, _definition}, _definitions) do
    {property_name_to_atom(property_name), :any}
  end
end
