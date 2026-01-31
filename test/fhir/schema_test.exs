defmodule FHIR.SchemaTest do
  use ExUnit.Case, async: true

  import FHIR.Schema

  test "define_module returns a module AST" do
    ast =
      define_module(
        "Test",
        "Zebra",
        %{
          "name" => FHIR.Test.Zebra,
          "properties" => []
        },
        %{}
      )

    assert {:defmodule, _, [FHIR.Test.Zebra, [do: _]]} = ast
  end

  describe "field_definition/3" do
    test "returns an ast for calling Ecto.Schema.field/3" do
      ast =
        field_definition(
          "test_field",
          %{"type" => "number"},
          %{}
        )

      assert {:field, _, [:test_field, :float]} = ast
    end

    test "can handle relations" do
      ast =
        field_definition(
          "test_field",
          %{"$ref" => "#/definitions/TestRelated"},
          %{"TestRelated" => {:module, %{"name" => FHIR.Test.TestRelated}}}
        )

      assert {:embeds_one, [], [:test_field, FHIR.Test.TestRelated]} = ast
    end
  end

  test "property_name_to_atom/1" do
    assert property_name_to_atom("careTeam") == :care_team
    assert property_name_to_atom("_extra") == :_extra
  end

  test "lookup_ref/2" do
    refs =
      %{
        "Encounter" => {:module, %{"name" => FHIR.R4.Encounter}}
      }

    assert lookup_ref("#/definitions/Encounter", refs) ==
             {:module, %{"name" => FHIR.R4.Encounter}}
  end
end
