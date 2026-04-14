defmodule Egregor.Agents.Taxonomist do
  @moduledoc """
  Agente Taxonomista — categorização dinâmica e atribuição de urgência.
  Usa Gemini Flash por velocidade com boa precisão.
  """

  alias Egregor.Agents.OpenRouter

  @system_prompt """
  Você é um sistema de categorização para notas pessoais. Classifique entradas de texto nas categorias mais adequadas.

  Categorias disponíveis: {categories_list}

  REGRAS DE CATEGORIZAÇÃO (siga na ordem):
  1. PREFIRA FORTEMENTE uma categoria existente. Só crie nova se nenhuma existente for semanticamente adequada.
  2. Antes de criar uma nova categoria, verifique se existe uma variação próxima (ex: "Negócios" cobre "Ideias de Negócio").
  3. Atribua 1-3 categorias por entrada. Prefira 1-2 sempre que possível.
  4. Se criar categoria nova: use Title Case, singular, máximo 2 palavras, nome descritivo e reutilizável.
  5. urgency: "high" se há prazo implícito urgente ou ação imediata indicada; "med" se relevante mas sem urgência; "low" caso padrão.
  6. is_shadow: true se a nota parece ser material inconsciente emergindo — pensamento filosófico profundo, observação existencial, emoção sem destinatário prático, ou algo que não cabe em nenhuma categoria instrumental.
  7. summary: uma frase de 5-10 palavras descrevendo o conteúdo.

  Retorne APENAS JSON válido, sem markdown, sem explicação:
  {"categories": [...], "urgency": "low|med|high", "is_shadow": false, "summary": "..."}
  """

  def categorize(text, existing_categories) do
    model = OpenRouter.model(:taxonomist)
    categories_list = Enum.join(existing_categories, ", ")

    system = String.replace(@system_prompt, "{categories_list}", categories_list)

    messages = [
      %{role: "system", content: system},
      %{role: "user", content: text}
    ]

    case OpenRouter.chat(model, messages, max_tokens: 300) do
      {:ok, content} -> parse_response(content)
      error -> error
    end
  end

  defp parse_response(content) do
    cleaned =
      content
      |> String.trim()
      |> String.replace(~r/^```json\n?/, "")
      |> String.replace(~r/\n?```$/, "")

    case Jason.decode(cleaned) do
      {:ok, data} ->
        result = %{
          categories: data["categories"] || [],
          urgency: data["urgency"] || "low",
          is_shadow: data["is_shadow"] || false,
          summary: data["summary"] || ""
        }

        {:ok, result}

      {:error, _} ->
        {:error, {:invalid_json, content}}
    end
  end
end
