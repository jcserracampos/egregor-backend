defmodule Egregor.Agents.FilamentNamer do
  @moduledoc """
  Agente Nomeador de Filamentos — destila um nome curto e evocativo para uma cadeia de ideias.

  Recebe os textos das entries de um filamento (em ordem cronológica) e produz um nome
  de 3-5 palavras que captura a essência da evolução daquela ideia ao longo do tempo.
  Tom: hermético, conciso, não-analítico.
  """

  alias Egregor.Agents.OpenRouter

  @system_prompt """
  Você recebe uma cadeia de anotações pessoais em ordem cronológica — são a mesma ideia
  ressurgindo e se transformando ao longo do tempo.

  Sua tarefa: gerar um nome para essa cadeia.

  Regras:
  - 3 a 5 palavras no máximo
  - Tom hermético, evocativo, não descritivo
  - Capture a essência da transformação, não o conteúdo literal
  - Use substantivos e adjetivos, evite verbos
  - Sem artigos definidos no início (não "A jornada", mas "Jornada da sombra")
  - Retorne APENAS o nome, sem aspas, sem explicação, sem pontuação final

  Exemplos de bons nomes:
  - "Raiz da barbearia afro"
  - "Identidade que retorna"
  - "Ouro latente no caos"
  - "Voz antes do silêncio"
  """

  def name(entries) when entries == [], do: {:ok, nil}

  def name(entries) do
    model = OpenRouter.model(:filament_namer)

    chain_text =
      entries
      |> Enum.with_index(1)
      |> Enum.map(fn {entry, i} ->
        date = Calendar.strftime(entry.inserted_at, "%d/%m/%Y")
        "#{i}. [#{date}] #{String.slice(entry.raw_text, 0, 200)}"
      end)
      |> Enum.join("\n")

    messages = [
      %{role: "system", content: @system_prompt},
      %{role: "user", content: "Cadeia de ideias:\n#{chain_text}"}
    ]

    case OpenRouter.chat(model, messages, max_tokens: 30) do
      {:ok, content} -> {:ok, String.trim(content)}
      error -> error
    end
  end
end
