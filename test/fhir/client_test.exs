defmodule FHIR.ClientTest do
  use ExUnit.Case, async: true

  describe "read/3" do
    test "makes a request and parses the response" do
      response_mock = fn %Finch.Request{path: path, host: host}, _ ->
        assert host == "read.example.com"
        assert path == "/Encounter/123"

        {:ok, %{status: 200, body: ~s({"resourceType": "Encounter"})}}
      end

      assert {:ok, %FHIR.R4.Encounter{}} =
               FHIR.Query.read(
                 "https://read.example.com/",
                 FHIR.R4.Encounter,
                 "123",
                 request_function: response_mock
               )
    end
  end

  describe "search/2" do
    test "makes a request and parses the response" do
      response_mock = fn %Finch.Request{path: path, host: host}, _ ->
        assert host == "search.example.com"
        assert path == "/Encounter"

        {:ok, %{status: 200, body: ~s({"resourceType": "Bundle"})}}
      end

      assert {:ok, %FHIR.R4.Bundle{}} =
               FHIR.Query.search(
                 "https://search.example.com/",
                 %FHIR.R4.Encounter.Search{},
                 request_function: response_mock
               )
    end
  end
end
