defmodule Egregor.Jobs.UpdateOracleContextJob do
  use Oban.Worker, queue: :batch, max_attempts: 2

  alias Egregor.Agents.OpenRouter
  alias Egregor.Oracle
  alias Egregor.Entries

  @system_prompt """
  Analise as últimas anotações pessoais do usuário e extraia padrões.

  Retorne APENAS JSON válido:
  {
    "vocabulary": {
      "frequent_words": ["palavra1", "palavra2"],
      "preferred_phrases": ["frase1"],
      "avoided_words": []
    },
    "obsessions": ["tema1", "tema2", "tema3"],
    "cycles": {
      "dominant_category_last_30_days": "NomeCategoria",
      "energy_pattern": "noturno|matutino|irregular"
    },
    "raw_summary": "Parágrafo de até 200 palavras descrevendo os padrões do usuário"
  }
  """

  @impl Oban.Worker
  def perform(_job) do
    entries = Entries.list_entries(limit: 30)
    current_context = Oracle.get_context()

    if length(entries) < 3 do
      :ok
    else
      entries_text =
        entries
        |> Enum.map(fn e -> "- [#{Enum.join(e.categories, ", ")}] #{e.raw_text}" end)
        |> Enum.join("\n")

      existing_summary = current_context.raw_summary || "(sem contexto anterior)"

      model = OpenRouter.model(:taxonomist)

      messages = [
        %{role: "system", content: @system_prompt},
        %{
          role: "user",
          content:
            "Contexto anterior:\n#{existing_summary}\n\nÚltimas anotações:\n#{entries_text}"
        }
      ]

      case OpenRouter.chat(model, messages, max_tokens: 600) do
        {:ok, content} -> parse_and_update(content)
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp parse_and_update(content) do
    cleaned =
      content
      |> String.trim()
      |> String.replace(~r/^```json\n?/, "")
      |> String.replace(~r/\n?```$/, "")

    case Jason.decode(cleaned) do
      {:ok, data} ->
        Oracle.update_context(%{
          vocabulary: data["vocabulary"] || %{},
          obsessions: data["obsessions"] || [],
          cycles: data["cycles"] || %{},
          raw_summary: data["raw_summary"]
        })

        :ok

      {:error, _} ->
        {:error, {:invalid_json, content}}
    end
  end
end
