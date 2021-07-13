defmodule Exonerate.Filter.Minimum do
  @behaviour Exonerate.Filter
  @derive Exonerate.Compiler
  @derive {Inspect, except: [:context]}

  alias Exonerate.Type.Integer
  alias Exonerate.Type.Number
  alias Exonerate.Validator

  import Validator, only: [fun: 2]

  defstruct [:context, :minimum, :parent]

  def parse(artifact = %type{}, %{"minimum" => minimum}) when type in [Integer, Number] do
    %{artifact |
      filters: [%__MODULE__{context: artifact.context, minimum: minimum, parent: type} | artifact.filters]}
  end

  def compile(filter = %__MODULE__{parent: Integer}) do
    {[quote do
      defp unquote(fun(filter, []))(integer, path)
        when is_integer(integer) and integer < unquote(filter.minimum) do
          Exonerate.mismatch(integer, path, guard: "minimum")
      end
    end], []}
  end

  def compile(filter = %__MODULE__{parent: Number}) do
    {[quote do
      defp unquote(fun(filter, []))(number, path)
        when is_number(number) and number < unquote(filter.minimum) do
          Exonerate.mismatch(number, path, guard: "minimum")
      end
    end], []}
  end
end
