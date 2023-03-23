defmodule Exonerate.Filter.AdditionalProperties do
  @moduledoc false

  defmacro filter(name, pointer, opts) do
    quote do
      require Exonerate.Context
      Exonerate.Context.filter(unquote(name), unquote(pointer), unquote(Tools.scrub(opts)))
    end
  end
end
