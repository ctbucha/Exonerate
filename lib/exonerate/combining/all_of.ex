defmodule Exonerate.Combining.AllOf do
  @moduledoc false

  alias Exonerate.Cache
  alias Exonerate.Tools

  defmacro filter_from_cached(name, pointer, opts) do
    # note this needs to change if we are doing unevaluateds, since we must
    # evaluate ALL options

    call = Tools.pointer_to_fun_name(pointer, authority: name)
    schema_pointer = JsonPointer.to_uri(pointer)

    {calls, contexts} =
      __CALLER__.module
      |> Cache.fetch!(name)
      |> JsonPointer.resolve!(pointer)
      |> Enum.with_index(fn _, index ->
        pointer = JsonPointer.join(pointer, "#{index}")
        call = Tools.pointer_to_fun_name(pointer, authority: name)

        {quote do
           &(unquote({call, [], Elixir}) / 2)
         end,
         quote do
           require Exonerate.Context
           Exonerate.Context.from_cached(unquote(name), unquote(pointer), unquote(opts))
         end}
      end)
      |> Enum.unzip()

    Tools.maybe_dump(
      quote do
        defp unquote(call)(value, path) do
          require Exonerate.Tools

          Enum.reduce_while(
            unquote(calls),
            :ok,
            fn
              fun, :ok ->
                case fun.(value, path) do
                  :ok ->
                    {:cont, :ok}

                  error = {:error, _} ->
                    {:halt, error}
                end
            end
          )
        end

        unquote(contexts)
      end,
      opts
    )
  end
end
