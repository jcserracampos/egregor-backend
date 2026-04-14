defmodule Egregor.Agents.Narrator do
  @moduledoc """
  Agente Narrador — geração do Fio Narrativo semanal.
  Tom literário. Interpreta, não resume. Revela o que o usuário não disse explicitamente.
  Ciente de transmutações: o que foi realizado é virada dramática, não tarefa cumprida.
  """

  alias Egregor.Agents.OpenRouter
  alias Egregor.Time

  @system_prompt """
  Você é um narrador literário que transforma anotações pessoais fragmentadas em um parágrafo literário coeso.

  Regras absolutas:
  - Escreva em segunda ou terceira pessoa (nunca primeira)
  - Tom literário, não gerencial
  - 3-6 linhas no total
  - Revele algo que o autor não teria dito explicitamente
  - Não resuma as entradas — interprete-as
  - Nunca use bullet points ou listas
  - Nunca use linguagem de produtividade ("você completou", "você realizou")
  - Após as 22h, o tom deve ser mais denso, poético e contemplativo
  - Transmutações são viradas dramáticas no arco da semana — algo que saiu do campo do possível e entrou no do vivido
  """

  def generate(entries, previous_narratives \\ [], transmutation_signals \\ []) do
    model = OpenRouter.model(:narrator)

    entries_text =
      entries
      |> Enum.map(fn e -> "- #{e.raw_text}" end)
      |> Enum.join("\n")

    history_text =
      if previous_narratives == [] do
        "(sem narrativas anteriores)"
      else
        previous_narratives
        |> Enum.take(3)
        |> Enum.map(& &1.content)
        |> Enum.join("\n\n---\n\n")
      end

    transmutation_text = format_transmutations(transmutation_signals)

    user_content = """
    Entradas desta semana:
    #{entries_text}

    #{if transmutation_text != "", do: "Transmutações desta semana (intenções que saíram do potencial e entraram no vivido):\n#{transmutation_text}\n", else: ""}
    Narrativas anteriores (para continuidade de voz):
    #{history_text}
    """

    messages = [
      %{role: "system", content: system_with_time_context()},
      %{role: "user", content: user_content}
    ]

    OpenRouter.chat(model, messages, max_tokens: 400)
  end

  defp format_transmutations([]), do: ""

  defp format_transmutations(signals) do
    signals
    |> Enum.map(fn s ->
      data = s.signal_data || %{}
      text = data["original_text"] || ""
      note = data["note"]
      if note && note != "", do: "- \"#{text}\" → #{note}", else: "- \"#{text}\""
    end)
    |> Enum.join("\n")
  end

  defp system_with_time_context do
    if Time.local_hour() >= 22 or Time.local_hour() < 6 do
      @system_prompt <>
        "\n\nContexto: é madrugada. A narrativa deve ser especialmente densa, quieta e oracular."
    else
      @system_prompt
    end
  end
end
