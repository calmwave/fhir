defmodule FHIR.Client.ResourceSchemafierTest do
  use ExUnit.Case, async: true

  import FHIR.Client.ResourceSchemafier

  @resource %{
    "resourceType" => "Encounter",
    "id" => "123",
    "meta" => %{
      "id" => "456"
    },
    "location" => [
      %{
        "id" => "789"
      }
    ]
  }

  @wrapped_resource %{
    "resource" => @resource
  }

  @enum_resource %{
    "resourceType" => "ActivityDefinition",
    "id" => "123",
    "status" => "active"
  }

  describe "schemafy" do
    test "a bundle entry returns an unwrapped resource" do
      assert %FHIR.R4.Encounter{id: "123"} = schemafy(@wrapped_resource, "R4")
    end

    test "returns a resource struct" do
      assert %FHIR.R4.Encounter{
               id: "123",
               meta: %FHIR.R4.Meta{
                 id: "456"
               },
               location: [
                 %FHIR.R4.EncounterLocation{
                   id: "789"
                 }
               ]
             } = schemafy(@resource, "R4")
    end

    test "can handle an enum" do
      assert %FHIR.R4.ActivityDefinition{
               id: "123",
               status: :active
             } = schemafy(@enum_resource, "R4")
    end

    test "can handle a list" do
      assert [
               %FHIR.R4.Encounter{},
               %FHIR.R4.Encounter{}
             ] = schemafy([@resource, @resource], "R4")
    end
  end
end
