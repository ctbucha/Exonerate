defmodule :"not with boolean schema true-gpt-3.5" do
  def validate(%{"not" => true}) do
    :ok
  end

  def validate(_) do
    :error
  end
end
