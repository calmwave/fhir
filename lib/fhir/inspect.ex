#
#  Some of our data structs can be enormous and are expanded in-line in error messages. This
#  results in them being truncated, dropping useful data like stack traces. The Inspect
#  protocol(s) here ensure that this doesn't happen.
#
defimpl Inspect, for: FHIR.R4.Bundle do
  def inspect(_bundle, _opts) do
    "#<An FHIR R4 bundle>"
  end
end
