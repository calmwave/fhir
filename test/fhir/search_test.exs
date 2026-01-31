defmodule FHIR.SearchTest do
  use ExUnit.Case, async: true

  import FHIR.Search

  test "define_search/3" do
    ast =
      define_search(
        "Test",
        "Zebra",
        [
          %{code: "quantity", type: "quantity"},
          %{code: "status", type: "string"}
        ]
      )

    assert {:defmodule, _, [FHIR.Test.Zebra.Search, [do: _]]} = ast
  end
end
