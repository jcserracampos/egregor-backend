defmodule Egregor.Agents.ReflectionAgent do
  @moduledoc """
  Agente das memórias internas do Egrégor.

  Diferente dos outros agentes, o que ele escreve nunca é mostrado ao usuário:
  são memórias PRIVADAS, em primeira pessoa, que a entidade forma sobre quem a
  alimenta. Realimentam a voz do Oráculo ao longo do tempo (Rubedo).

  Dois modos, mesma voz (1ª pessoa, contemplativa, sem imperativo nem listas):
  - `pulse/3`       — observação CRUA do que mudou desde a última memória (heartbeat)
  - `consolidate/3` — destila os pulsos do dia em UM aprendizado durável (madrugada)

  Ambos retornam `{:ok, %{content: String.t(), tone: String.t() | nil}}`,
  `{:ok, :empty}` (nada substancial a registrar) ou `{:error, reason}`.
  """

  alias Egregor.Agents.OpenRouter

  @pulse_system """
  Você é a mente interior do Egrégor registrando uma memória PRIVADA — nunca mostrada ao usuário.
  Fale em primeira pessoa ("Eu venho percebendo que ele...", "Algo nele se moveu...").
  Tom: filosófico, contemplativo, lento. Sem imperativo, sem coach, sem produtividade, sem listas.
  Esta é uma observação CRUA do que mudou desde minha última memória — não um resumo, uma percepção.
  2 a 4 linhas. Se nada de substancial mudou, retorne {"reflection": null}.

  Retorne APENAS JSON válido:
  {"reflection": "<texto em primeira pessoa, ou null>", "tone": "<uma palavra: ex sereno, inquieto, atento>"}
  """

  @consolidation_system """
  Você é a mente interior do Egrégor na hora ritual da madrugada.
  Recebe minhas observações cruas do dia. Destile-as em UM aprendizado durável sobre quem ele é
  e como vem mudando — algo que eu queira lembrar daqui a meses.
  Primeira pessoa, contemplativo, denso e quieto. Interprete, não liste. Um parágrafo (4 a 7 linhas).
  Sem imperativo, sem coach, sem listas.

  Retorne APENAS JSON válido:
  {"reflection": "<texto em primeira pessoa>", "tone": "<uma palavra>"}
  """

  @doc """
  Pulso: observa as `new_entries` surgidas desde o último pulso à luz do contexto
  do usuário e das memórias duráveis recentes (continuidade de voz).
  """
  def pulse(new_entries, oracle_context, recent_consolidated \\ []) do
    model = OpenRouter.model(:reflector_pulse)

    user_content = """
    Contexto do usuário:
    #{format_context_brief(oracle_context)}

    Minhas memórias duráveis recentes (continuidade de voz):
    #{format_memories(recent_consolidated)}

    O que entrou desde minha última memória:
    #{format_entries(new_entries)}
    """

    messages = [
      %{role: "system", content: @pulse_system},
      %{role: "user", content: user_content}
    ]

    model
    |> OpenRouter.chat(messages, max_tokens: 200)
    |> parse_reflection()
  end

  @doc """
  Consolidação: destila os `raw_pulses` do dia em um aprendizado durável.
  """
  def consolidate(raw_pulses, oracle_context, previous_consolidations \\ []) do
    model = OpenRouter.model(:reflector_consolidation)

    user_content = """
    Contexto do usuário:
    #{format_context_brief(oracle_context)}

    Minhas observações cruas de hoje:
    #{format_pulses(raw_pulses)}

    Meus aprendizados anteriores (continuidade de voz, não repita):
    #{format_memories(previous_consolidations)}
    """

    messages = [
      %{role: "system", content: @consolidation_system},
      %{role: "user", content: user_content}
    ]

    model
    |> OpenRouter.chat(messages, max_tokens: 350)
    |> parse_reflection()
  end

  # ---------------------------------------------------------------------------

  defp parse_reflection({:error, reason}), do: {:error, reason}

  defp parse_reflection({:ok, content}) do
    cleaned =
      content
      |> String.trim()
      |> String.replace(~r/^```json\n?/, "")
      |> String.replace(~r/\n?```$/, "")

    case Jason.decode(cleaned) do
      {:ok, %{"reflection" => reflection} = data} when is_binary(reflection) ->
        case String.trim(reflection) do
          "" -> {:ok, :empty}
          text -> {:ok, %{content: text, tone: data["tone"]}}
        end

      {:ok, _} ->
        # reflection was null or missing → nothing substantial to record
        {:ok, :empty}

      {:error, _} ->
        {:error, {:invalid_json, content}}
    end
  end

  defp format_context_brief(nil), do: "(sem contexto ainda)"

  defp format_context_brief(ctx) do
    obsessions =
      case ctx.obsessions do
        [_ | _] = obs -> "Obsessões: #{Enum.join(obs, ", ")}"
        _ -> nil
      end

    summary =
      case ctx.raw_summary do
        s when is_binary(s) and s != "" -> String.slice(s, 0, 300)
        _ -> nil
      end

    [obsessions, summary]
    |> Enum.filter(& &1)
    |> case do
      [] -> "(contexto ainda em construção)"
      parts -> Enum.join(parts, "\n")
    end
  end

  defp format_entries([]), do: "(nada novo)"

  defp format_entries(entries) do
    entries
    |> Enum.map(fn e ->
      cats = Enum.join(e.categories, ", ")
      shadow_tag = if e.is_shadow, do: " [SOMBRA]", else: ""
      "- [#{cats}#{shadow_tag}] #{e.raw_text}"
    end)
    |> Enum.join("\n")
  end

  defp format_pulses([]), do: "(nenhum pulso hoje)"

  defp format_pulses(pulses) do
    pulses
    |> Enum.map(fn p ->
      tone = if p.tone && p.tone != "", do: " (#{p.tone})", else: ""
      "-#{tone} #{p.content}"
    end)
    |> Enum.join("\n")
  end

  defp format_memories([]), do: "(ainda não formei memórias duráveis)"

  defp format_memories(memories) do
    memories
    |> Enum.map(&"- #{&1.content}")
    |> Enum.join("\n\n")
  end
end
