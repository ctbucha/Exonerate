defmodule Exonerate.Type.Object do
  @moduledoc false

  @behaviour Exonerate.Type

  alias Exonerate.Tools
  alias Exonerate.Combining
  alias Exonerate.Type.Object.Iterator

  @modules %{
    "minProperties" => Exonerate.Filter.MinProperties,
    "maxProperties" => Exonerate.Filter.MaxProperties,
    "required" => Exonerate.Filter.Required,
    "dependencies" => Exonerate.Filter.Dependencies,
    "dependentRequired" => Exonerate.Filter.DependentRequired
  }

  @outer_filters Map.keys(@modules)

  @combining_filters Combining.filters() ++ ["dependentSchemas"]

  defmacro filter(authority, pointer, opts) do
    if opts[:tracked] do
      quote do
        require Exonerate.Type.Object.Tracked
        Exonerate.Type.Object.Tracked.filter(unquote(authority), unquote(pointer), unquote(opts))
      end
    else
      __CALLER__
      |> Tools.subschema(authority, pointer)
      |> build_filter(authority, pointer, opts)
      |> Tools.maybe_dump(opts)
    end
  end

  @empty_map_only [%{"unevaluatedProperties" => false}, %{"additionalProperties" => false}]
  # empty map optimization
  defp build_filter(context, authority, pointer, opts) when context in @empty_map_only do
    pointer = JsonPointer.join(pointer, Map.keys(context))
    call = Tools.call(authority, pointer, opts)

    quote do
      defp unquote(call)(object, path) when object === %{}, do: :ok

      defp unquote(call)(object, path) when is_map(object) do
        require Exonerate.Tools
        Exonerate.Tools.mismatch(object, unquote(pointer), path)
      end
    end
  end

  defp build_filter(context, authority, pointer, opts) do
    filter_clauses =
      outer_filters(context, authority, pointer, opts) ++
        seen_filters(context, authority, pointer, opts) ++
        unseen_filters(context, authority, pointer, opts) ++
        iterator_filter(context, authority, pointer, opts)

    if needs_seen?(context) do
      quote do
        defp unquote(Tools.call(authority, pointer, opts))(object, path) when is_map(object) do
          seen = MapSet.new()

          with unquote_splicing(filter_clauses) do
            :ok
          end
        end
      end
    else
      quote do
        defp unquote(Tools.call(authority, pointer, opts))(object, path) when is_map(object) do
          with unquote_splicing(filter_clauses) do
            :ok
          end
        end
      end
    end
  end

  @seen_filters ~w(allOf anyOf if oneOf dependentSchemas $ref)
  @unseen_filters @combining_filters -- @seen_filters

  def needs_seen?(context) do
    is_map_key(context, "unevaluatedProperties") and
      Enum.any?(@seen_filters, &is_map_key(context, &1))
  end

  defp outer_filters(context, authority, pointer, opts) do
    for filter <- @outer_filters, is_map_key(context, filter) do
      filter_call =
        Tools.call(authority, JsonPointer.join(pointer, Combining.adjust(filter)), opts)

      quote do
        :ok <- unquote(filter_call)(object, path)
      end
    end
  end

  defp seen_filters(context, authority, pointer, opts) do
    needs_seen = needs_seen?(context)

    opts =
      if needs_seen do
        Keyword.put(opts, :tracked, :object)
      else
        opts
      end

    for filter <- @seen_filters, is_map_key(context, filter) do
      filter_call =
        Tools.call(authority, JsonPointer.join(pointer, Combining.adjust(filter)), opts)

      if needs_seen do
        quote do
          [
            {:ok, new_seen} <- unquote(filter_call)(object, path),
            seen = MapSet.union(seen, new_seen)
          ]
        end
      else
        [
          quote do
            :ok <- unquote(filter_call)(object, path)
          end
        ]
      end
    end
    |> Enum.flat_map(&Function.identity/1)
  end

  defp unseen_filters(context, authority, pointer, opts) do
    for filter <- @unseen_filters, is_map_key(context, filter) do
      filter_call =
        Tools.call(authority, JsonPointer.join(pointer, Combining.adjust(filter)), opts)

      quote do
        :ok <- unquote(filter_call)(object, path)
      end
    end
  end

  defp iterator_filter(context, authority, pointer, opts) do
    List.wrap(
      case {Iterator.needed?(context), needs_seen?(context)} do
        {true, true} ->
          iterator_call = Tools.call(authority, JsonPointer.join(pointer, ":iterator"), opts)

          quote do
            :ok <- unquote(iterator_call)(object, path, seen)
          end

        {true, _} ->
          iterator_call = Tools.call(authority, JsonPointer.join(pointer, ":iterator"), opts)

          quote do
            :ok <- unquote(iterator_call)(object, path)
          end

        _ ->
          nil
      end
    )
  end

  defmacro accessories(authority, pointer, opts) do
    if opts[:tracked] do
      quote do
        require Exonerate.Type.Object.Tracked

        Exonerate.Type.Object.Tracked.accessories(
          unquote(authority),
          unquote(pointer),
          unquote(opts)
        )
      end
    else
      __CALLER__
      |> Tools.subschema(authority, pointer)
      |> build_accessories(authority, pointer, opts)
      |> Tools.maybe_dump(opts)
    end
  end

  defp build_accessories(context, _, _, _) when context in @empty_map_only do
    []
  end

  defp build_accessories(context, name, pointer, opts) do
    iterator_accessory(context, name, pointer, opts) ++
      filter_accessories(context, name, pointer, opts) ++
      tracked_accessories(context, name, pointer, opts)
  end

  defp iterator_accessory(context, name, pointer, opts) do
    List.wrap(
      if Iterator.needed?(context) do
        quote do
          require Exonerate.Type.Object.Iterator
          Exonerate.Type.Object.Iterator.filter(unquote(name), unquote(pointer), unquote(opts))

          Exonerate.Type.Object.Iterator.accessories(
            unquote(name),
            unquote(pointer),
            unquote(opts)
          )
        end
      end
    )
  end

  @outer_modules Map.put(@modules, "dependentSchemas", Exonerate.Filter.DependentSchemas)

  defp filter_accessories(context, name, pointer, opts) do
    filters =
      if opts[:tracked] do
        @outer_filters
      else
        @outer_filters ++ ["dependentSchemas"]
      end

    for filter <- filters, is_map_key(context, filter), not Combining.filter?(filter) do
      module = @outer_modules[filter]
      pointer = JsonPointer.join(pointer, filter)

      quote do
        require unquote(module)
        unquote(module).filter(unquote(name), unquote(pointer), unquote(opts))
      end
    end
  end

  @combining_modules Map.put(
                       Combining.modules(),
                       "dependentSchemas",
                       Exonerate.Filter.DependentSchemas
                     )

  defp tracked_accessories(context, name, pointer, opts) do
    List.wrap(
      if needs_seen?(context) do
        for filter <- @seen_filters, is_map_key(context, filter) do
          module = @combining_modules[filter]
          pointer = JsonPointer.join(pointer, filter)
          opts = Keyword.merge(opts, tracked: :object, only: "object")

          quote do
            require unquote(module)
            unquote(module).filter(unquote(name), unquote(pointer), unquote(opts))
          end
        end
      end
    )
  end
end
