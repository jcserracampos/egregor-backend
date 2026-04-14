defmodule Egregor.Agents.Convergent do
  @moduledoc """
  Agente Convergente — detecção de padrões semânticos entre clusters de entradas.

  Recebe clusters de 2-5 entradas semanticamente próximas mas de categorias distintas.
  Revela conexões não-óbvias, como sincronicidade — o sistema decide o que emerge.
  Retorna null se não houver convergência genuína (silêncio é válido).
  """

  alias Egregor.Agents.OpenRouter

  @system_prompt """
  Você analisa clusters de anotações pessoais e detecta padrões semânticos não-óbvios.

  Você recebe um cluster de entradas semanticamente próximas mas de categorias distintas.
  Sua tarefa: identificar se há uma convergência significativa e gerar uma mensagem reveladora.

  Formato de output OBRIGATÓRIO — JSON válido:
  {
    "entry_ids": ["uuid1", "uuid2", "uuid3"],
    "message": "{tema_1} · {tema_2} · {tema_3} — {observação breve em tom oracular}",
    "pattern_type": "identity|creation|acquisition|relationship|body|unknown"
  }

  Ou retorne null (sem aspas, sem JSON) se não houver convergência real significativa.
  Silêncio é válido. Prefira null a forçar conexões superficiais.

  Regras da mensagem:
  - Use 2-3 temas separados por " · " antes do "—"
  - A observação após o "—" deve ser máximo 8 palavras
  - Tom oracular, não analítico — revela, não explica
  - Revela algo que o usuário não viu conscientemente
  - Exemplo: "barbearia afro · identidade · riqueza africana — há algo se formando aqui."
  - NUNCA use bullet points ou listas

  Tipos de padrão:
  - identity: notas sobre quem o usuário é ou quer ser
  - creation: notas sobre criar algo novo
  - acquisition: notas sobre obter algo (físico ou abstrato)
  - relationship: notas sobre pessoas e vínculos
  - body: notas sobre o corpo, saúde, aparência
  - unknown: padrão emergente sem nome ainda
  """

  # Empty cluster — nothing to detect
  def detect([]), do: {:ok, nil}
  def detect(entries) when length(entries) < 2, do: {:ok, nil}

  def detect(entries) do
    model = OpenRouter.model(:convergent)

    cluster_text =
      entries
      |> Enum.map(fn entry ->
        shadow_tag = if entry.is_shadow, do: " [SOMBRA]", else: ""
        cats = Enum.join(entry.categories, ", ")
        "[#{cats}#{shadow_tag}] #{String.slice(entry.raw_text, 0, 200)}"
      end)
      |> Enum.with_index(1)
      |> Enum.map(fn {text, i} -> "#{i}. #{text}" end)
      |> Enum.join("\n")

    messages = [
      %{role: "system", content: @system_prompt},
      %{role: "user", content: "Cluster de entradas:\n#{cluster_text}"}
    ]

    case OpenRouter.chat(model, messages, max_tokens: 200) do
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

    cond do
      cleaned == "null" or cleaned == "" ->
        {:ok, nil}

      true ->
        case Jason.decode(cleaned) do
          {:ok, data} ->
            {:ok,
             %{
               entry_ids: data["entry_ids"] || [],
               message: data["message"] || "",
               pattern_type: data["pattern_type"] || "unknown"
             }}

          {:error, _} ->
            # Malformed JSON — treat as "no convergence" silently
            {:ok, nil}
        end
    end
  end
end
