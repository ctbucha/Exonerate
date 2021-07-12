defmodule Exonerate.Filter.Items do
  @behaviour Exonerate.Filter
  @derive Exonerate.Compiler

  alias Exonerate.Validator
  defstruct [:context, :schema, :type]

  def parse(artifact = %{context: context}, %{"items" => s}) when is_map(s) do
    fun = fun(artifact)

    schema = Validator.parse(context.schema,
      ["items" | context.pointer],
      authority: context.authority)

    %{artifact |
      needs_enum: true,
      enum_pipeline: [{fun, []} | artifact.enum_pipeline],
      enum_init: Map.put(artifact.enum_init, :index, 0),
      filters: [%__MODULE__{context: artifact.context, schema: schema, type: :map} | artifact.filters]}
  end

  def parse(artifact = %{context: context}, %{"items" => s}) when is_list(s) do
    fun = fun(artifact)

    schemas = Enum.map(0..(length(s) - 1),
      &Validator.parse(context.schema,
        ["#{&1}", "items" | context.pointer],
        authority: context.authority))

    %{artifact |
      needs_enum: true,
      enum_pipeline: [{fun, []} | artifact.enum_pipeline],
      enum_init: Map.put(artifact.enum_init, :index, 0),
      filters: [%__MODULE__{context: artifact.context, schema: schemas, type: :list} | artifact.filters]}
  end

  def compile(filter = %__MODULE__{schema: schema, type: :map}) do
    {[], [
      quote do
        defp unquote(fun(filter))(acc, {path, item}) do
          unquote(fun(filter))(item, Path.join(path, to_string(acc.index)))
          acc
        end
        unquote(Validator.compile(schema))
      end
    ]}
  end

  def compile(filter = %__MODULE__{schema: schemas, type: :list}) do
    {trampolines, children} = schemas
    |> Enum.with_index()
    |> Enum.map(fn {schema, index} ->
      {quote do
        defp unquote(fun(filter))(acc = %{index: unquote(index)}, {path, item}) do
          unquote(fun(filter, index))(item, Path.join(path, unquote("#{index}")))
          acc
        end
      end,
      Validator.compile(schema)}
    end)
    |> Enum.unzip()

    {[], trampolines ++ [
      quote do
        defp unquote(fun(filter))(acc = %{index: _}, {_path, _item}), do: acc
      end
    ]++ children}
  end

  defp fun(filter_or_artifact = %_{}) do
    filter_or_artifact.context
    |> Validator.jump_into("items")
    |> Validator.to_fun
  end

  defp fun(filter_or_artifact = %_{}, index) do
    filter_or_artifact.context
    |> Validator.jump_into("items")
    |> Validator.jump_into("#{index}")
    |> Validator.to_fun
  end
end
