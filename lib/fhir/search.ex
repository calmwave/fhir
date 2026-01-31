defmodule FHIR.Search do
  @moduledoc """
  Functions for metaprogramming modules based on FHIR Search endpoints.
  """

  @typedoc """
  A definition of one search parameter. Each parameter has a code (HTTP query param name) and a type.
  """
  @type parameter_def :: %{code: String.t(), type: String.t()}

  @doc """
  Load a search parameter file for the given version and use it to define
  structs and modules for each included search endpoint.
  """
  @spec generate_searches(FHIR.version(), String.t()) :: list()
  def generate_searches(version, search_file) do
    search_param_data =
      search_file
      |> File.read!()
      |> Jason.decode!()
      |> Map.get("entry")

    search_param_data
    |> Enum.flat_map(fn %{"resource" => %{"base" => bases, "type" => type, "code" => code}} ->
      Enum.map(bases, fn base ->
        %{base: base, type: type, code: code}
      end)
    end)
    |> Enum.group_by(& &1.base)
    |> Enum.map(fn {base, parameters} ->
      Code.eval_quoted(define_search(version, base, parameters))
    end)
  end

  @doc """
  Returns the AST for a defmodule for a given FHIR search endpoint.
  """
  @spec define_search(FHIR.version(), String.t(), map()) :: Macro.t()
  def define_search(version, base, parameters) do
    module_name = Module.concat([FHIR, version, base, "Search"])

    quote do
      defmodule unquote(module_name) do
        use Ecto.Schema

        @timestamps_opts [type: :utc_datetime_usec]
        @primary_key false
        embedded_schema do
          unquote(Enum.map(parameters, &define_field/1))

          # _include is the special reserved field in a search to tell FHIR to expand related resources inline
          field(:_include, {:array, :string})
        end

        unquote(Enum.map(parameters, &struct_key_to_query_key_head/1))
        def struct_key_to_query_key(:_include), do: "_include"

        def base, do: unquote(base)
        def version, do: unquote(version)

        def changeset(data \\ %__MODULE__{}, attrs) do
          data
          |> Ecto.Changeset.cast(attrs, Map.keys(attrs))
        end

        def convert_to_query_list(data) when is_struct(data, unquote(module_name)) do
          data
          |> Map.from_struct()
          |> Enum.flat_map(fn {struct_key, values} ->
            Enum.map(List.wrap(values), fn value ->
              {struct_key_to_query_key(struct_key), value}
            end)
          end)
          |> Enum.reject(fn {_, value} -> is_nil(value) end)
        end
      end
    end
  end

  @doc """
  Return AST for defining one function head of struct_key_to_query_key, which converts from elixir struct
  keys to the HTTP query param name.
  """
  @spec struct_key_to_query_key_head(parameter_def()) :: Macro.t()
  def struct_key_to_query_key_head(%{code: code, type: "reference"}) do
    quote do
      def struct_key_to_query_key(unquote(code_to_field_name("#{code}_id"))), do: unquote(code)
    end
  end

  def struct_key_to_query_key_head(%{code: code}) do
    quote do
      def struct_key_to_query_key(unquote(code_to_field_name(code))), do: unquote(code)
    end
  end

  @doc """
  Return AST for defining one field in the search structure.
  """
  @spec define_field(parameter_def()) :: Macro.t()
  def define_field(%{type: type, code: code}) when type in ["token", "string"] do
    quote do
      field(unquote(code_to_field_name(code)), :string)
    end
  end

  def define_field(%{type: "date", code: code}) do
    quote do
      field(unquote(code_to_field_name(code)), :date)
    end
  end

  def define_field(%{type: "reference", code: code}) do
    quote do
      field(unquote(code_to_field_name("#{code}_id")), :string)
    end
  end

  def define_field(%{type: type, code: code}) when type in ["quantity", "number"] do
    quote do
      field(unquote(code_to_field_name(code)), :float)
    end
  end

  def define_field(%{type: "uri", code: code}) do
    quote do
      field(unquote(code_to_field_name(code)), :string)
    end
  end

  def define_field(%{code: "near"}) do
    # A special case unique type-- for geo searches
    quote do
      field(:near, :map)
    end
  end

  def define_field(%{type: "composite"}) do
    # These are a little more complex. Will tackle when needed.
    quote do
    end
  end

  @doc """
  Given a FHIR-style search parameter code, convert to an elixir struct key.
  """
  @spec code_to_field_name(String.t()) :: atom()
  def code_to_field_name(code) do
    code
    |> String.replace("-", "_")
    |> Macro.underscore()
    |> String.to_atom()
  end
end
