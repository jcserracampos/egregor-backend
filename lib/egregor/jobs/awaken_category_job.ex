defmodule Egregor.Jobs.AwakenCategoryJob do
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Egregor.Repo
  alias Egregor.Categories
  alias Egregor.Categories.Category
  alias Egregor.Agents.OpenRouter

  @system_prompt """
  Uma categoria de anotações pessoais atingiu 10 entradas e deve "acordar".
  Gere um símbolo visual único para ela — pode ser um emoji composto, caractere unicode especial, ou combinação de símbolos (máximo 3 caracteres).
  O símbolo deve evocar a essência da categoria de forma sutil e não-literal.
  Retorne APENAS o símbolo, sem explicação.
  """

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"category_id" => category_id}}) do
    category = Repo.get!(Category, category_id)

    if category.awakened do
      :ok
    else
      model = OpenRouter.model(:taxonomist)

      messages = [
        %{role: "system", content: @system_prompt},
        %{role: "user", content: "Categoria: #{category.name}"}
      ]

      case OpenRouter.chat(model, messages, max_tokens: 10) do
        {:ok, symbol} ->
          symbol = String.trim(symbol)
          Categories.awaken(category, symbol)
          :ok

        {:error, reason} ->
          {:error, reason}
      end
    end
  end
end
