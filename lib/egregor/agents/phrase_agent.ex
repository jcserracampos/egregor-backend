defmodule Egregor.Agents.PhraseAgent do
  @moduledoc """
  Agente A Frase — geração da frase do momento ao abrir o app.
  Cache de 1 frase por hora. Varia por período do dia.
  """

  alias Egregor.Agents.OpenRouter
  alias Egregor.Time

  @prompts %{
    morning: """
    Gere uma frase única de 1-2 linhas para a manhã. Tom: orientado à ação, energia, possibilidade.
    Baseie-se no estado atual do acervo do usuário.
    Referências permitidas: filosofia (estoicismo, hermetismo, budismo zen, existencialismo), literatura, sabedoria popular não-clichê.
    PROIBIDO: qualquer frase de coach de Instagram, motivação superficial, frases genéricas.
    Retorne APENAS a frase, sem aspas, sem explicação.
    """,
    afternoon: """
    Gere uma frase única de 1-2 linhas para a tarde. Tom: observacional, analítico.
    Baseie-se no estado atual do acervo do usuário.
    Referências permitidas: filosofia, literatura, sabedoria popular não-clichê.
    PROIBIDO: motivação superficial, frases genéricas.
    Retorne APENAS a frase, sem aspas, sem explicação.
    """,
    evening: """
    Gere uma frase única de 1-2 linhas para a noite. Tom: reflexivo, contemplativo.
    Baseie-se no estado atual do acervo do usuário.
    Referências permitidas: filosofia, literatura, poesia.
    PROIBIDO: motivação superficial, frases genéricas.
    Retorne APENAS a frase, sem aspas, sem explicação.
    """,
    night: """
    Gere uma frase única de 1-2 linhas para a madrugada. Tom: profundo, quieto, oracular — lento e denso.
    Baseie-se no estado atual do acervo do usuário.
    Referências permitidas: filosofia esotérica, hermetismo, poesia, sabedoria ancestral.
    PROIBIDO: motivação superficial, frases genéricas.
    Retorne APENAS a frase, sem aspas, sem explicação.
    """
  }

  def generate(archive_summary) do
    model = OpenRouter.model(:phrase)
    period = current_period()
    prompt = @prompts[period]

    messages = [
      %{role: "system", content: prompt},
      %{role: "user", content: "Estado atual do acervo: #{archive_summary}"}
    ]

    OpenRouter.chat(model, messages, max_tokens: 100)
  end

  defp current_period, do: Time.period()
end
