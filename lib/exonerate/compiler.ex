defprotocol Exonerate.Compiler do
  @spec compile(Exonerate.Type.artifact, keyword) :: {guarded_body :: [Macro.t], children :: [Macro.t]}
  @doc """
  analyzes the type artifact generated by the parser stage of the type parser, then emits
  a tuple of two code AST segments:
  1 - the `guarded body` which is the part, put behind an object guard, that is the type-specific filter.  These
      should all, in principle, have the same function header.
  2 - `children`, which are functions representing internal dependencies.
  """
  def compile(type_struct)
  def compile(type_struct, opts)
end

defimpl Exonerate.Compiler, for: Any do
  alias Exonerate.Tools

  def compile(struct, opts \\ [])

  alias Exonerate.Type.String
  alias Exonerate.Filter.Format

  @spec compile(struct()) :: {[Macro.t], [Macro.t]}
  # empty filter exception for String.
  def compile(%s{filters: [%Format{format: "binary"}]}, _) when s == String, do: {[], []}
  def compile(%s{filters: []}, []) when s != String, do: {[], []}
  def compile(artifact = %module{filters: filters}, _) do
    {guards, children} = filters
    |> Enum.map(&Exonerate.Compiler.compile/1)
    |> Enum.unzip

    {Tools.flatten(guards) ++ [module.compile(artifact)], Tools.flatten(children)}
  end
  def compile(artifact = %module{}, _) do
    module.compile(artifact)
  end
end
