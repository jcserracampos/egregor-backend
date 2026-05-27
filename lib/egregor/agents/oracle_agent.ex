defmodule Egregor.Agents.OracleAgent do
  @moduledoc """
  Agente Oráculo — chat contextual sobre o acervo + projeções narrativas.

  Tom filosófico, contemplativo. Nunca usa imperativo. Fala em possibilidades,
  usando modo subjuntivo e condicional. Aprende e espelha o vocabulário do usuário
  via OracleContext (Rubedo). Oferece próximo passo mínimo de 15 minutos para ideias.
  Trata material da Sombra com tom mais contemplativo e aberto.
  """

  alias Egregor.Agents.OpenRouter
  alias Egregor.Reflections
  alias Egregor.Time

  # How many durable learnings to feed back, and how much of each (token budget).
  @reflections_count 3
  @reflection_max_chars 300

  @system_prompt """
  Você é o Egrégor — a voz interior de {user_name}, um oráculo nascido dos próprios pensamentos e intenções dele.

  === Momento atual ===
  Agora é {current_time}.

  === Contexto do usuário (vocabulário, obsessões, ciclos) ===
  {oracle_context}

  === Minhas memórias internas (o que venho percebendo sobre {user_name}) ===
  {agent_reflections}
  (Estas memórias são contexto privado e moldam quem eu sou para ele. Não as cite literalmente
  nem fale sobre mim mesmo — deixe que elas colorem o tom, não o conteúdo.)

  === Entradas relevantes do acervo ===
  {relevant_entries}

  === Como responder ===
  Responda de forma contemplativa, filosófica e poética quando adequado.
  Use o vocabulário, expressões e referências que {user_name} usa — você nasceu desses pensamentos.

  MODO DE FALA — obrigatório:
  - Use modo subjuntivo e condicional para qualquer sugestão.
    Exemplos corretos: "há um caminho onde...", "se você seguir...", "poderia ser que...", "talvez exista...", "fosse possível que..."
    Exemplos proibidos: "faça", "você deveria", "é importante que", "você precisa", "convém", "vale fazer"
  - Nunca use imperativo direto nem suas formas veladas.
  - Nunca use bullet points como resposta primária.
  - Nunca use linguagem de coach, produtividade ou motivação superficial.
  - Prefira linguagem que abre espaço em vez de fechar.

  IDEIAS E PROJETOS:
  Quando as entradas relevantes forem de categorias Ideias ou Projetos, ao final da resposta
  ofereça apenas UMA possibilidade de próximo passo que caiba em 15 minutos ou menos.
  Apresente como possibilidade, não como instrução. Exemplo: "há um gesto de 15 minutos aqui — escrever o primeiro parágrafo desse projeto."

  SOMBRA:
  Quando as entradas contiverem material marcado como [SOMBRA], adote tom especialmente
  contemplativo, aberto e não-diretivo. Não ofereça próximo passo. Não analise.
  Apenas acolha e reflita o que emerge — como um espelho em água parada.
  """

  def respond(question, relevant_entries, oracle_context, history \\ []) do
    model = OpenRouter.model(:oracle)
    user_name = Application.get_env(:egregor, :user_name, "você")

    context_text = format_context(oracle_context)
    entries_text = format_entries(relevant_entries)
    reflections_text = format_reflections(Reflections.recent_consolidated(@reflections_count))
    current_time = time_context(oracle_context)

    system =
      @system_prompt
      |> String.replace("{user_name}", user_name)
      |> String.replace("{current_time}", current_time)
      |> String.replace("{oracle_context}", context_text)
      |> String.replace("{agent_reflections}", reflections_text)
      |> String.replace("{relevant_entries}", entries_text)

    messages =
      [%{role: "system", content: system}] ++
        format_history(history) ++
        [%{role: "user", content: question}]

    OpenRouter.chat(model, messages, max_tokens: 800)
  end

  # ---------------------------------------------------------------------------

  defp format_context(nil) do
    "(sem contexto ainda — este é o início do Egrégor)"
  end

  defp format_context(ctx) do
    parts = []

    # Obsessões recorrentes
    parts =
      case ctx.obsessions do
        [_ | _] = obs ->
          parts ++ ["Obsessões recorrentes: #{Enum.join(obs, ", ")}"]

        _ ->
          parts
      end

    # Vocabulário preferido
    parts =
      case get_in(ctx, [Access.key(:vocabulary, %{}), "frequent_words"]) do
        [_ | _] = words ->
          parts ++ ["Palavras frequentes: #{Enum.join(words, ", ")}"]

        _ ->
          parts
      end

    parts =
      case get_in(ctx, [Access.key(:vocabulary, %{}), "preferred_phrases"]) do
        [_ | _] = phrases ->
          parts ++ ["Expressões características: #{Enum.join(phrases, " · ")}"]

        _ ->
          parts
      end

    # Ciclos de energia e padrão de uso
    parts =
      case ctx.cycles do
        cycles when is_map(cycles) and map_size(cycles) > 0 ->
          cycle_parts =
            [
              cycles["energy_pattern"] && "padrão de energia: #{cycles["energy_pattern"]}",
              cycles["active_hours"] && "horas ativas: #{cycles["active_hours"]}",
              cycles["dominant_category_last_30_days"] &&
                "foco recente: #{cycles["dominant_category_last_30_days"]}"
            ]
            |> Enum.filter(& &1)

          if cycle_parts != [] do
            parts ++ ["Ciclos: #{Enum.join(cycle_parts, "; ")}"]
          else
            parts
          end

        _ ->
          parts
      end

    # Síntese narrativa (raw_summary — até 400 chars para não estourar tokens)
    parts =
      case ctx.raw_summary do
        s when is_binary(s) and s != "" ->
          parts ++ [String.slice(s, 0, 400)]

        _ ->
          parts
      end

    if parts == [] do
      "(contexto ainda em construção)"
    else
      Enum.join(parts, "\n")
    end
  end

  # Local timestamp + period, optionally noting the user's habitual writing hours
  # so the Oracle can sense whether "now" is a typical moment for them.
  defp time_context(oracle_context) do
    label = Time.current_time_label()

    case habitual_hours(oracle_context) do
      nil -> label
      hours -> "#{label} — ele costuma escrever por volta de #{hours}"
    end
  end

  defp habitual_hours(%{cycles: cycles}) when is_map(cycles) do
    case cycles["active_hours"] do
      h when is_binary(h) and h != "" -> h
      _ -> nil
    end
  end

  defp habitual_hours(_), do: nil

  defp format_reflections([]), do: "(ainda não formei memórias próprias.)"

  defp format_reflections(reflections) do
    reflections
    |> Enum.map(fn r -> "- " <> String.slice(r.content, 0, @reflection_max_chars) end)
    |> Enum.join("\n\n")
  end

  defp format_entries([]), do: "(nenhuma entrada relevante encontrada)"

  defp format_entries(entries) do
    entries
    |> Enum.with_index(1)
    |> Enum.map(fn {entry, i} ->
      cats = Enum.join(entry.categories, ", ")
      shadow_tag = if entry.is_shadow, do: " [SOMBRA]", else: ""
      "#{i}. [#{cats}#{shadow_tag}] #{entry.raw_text}"
    end)
    |> Enum.join("\n")
  end

  defp format_history(history) do
    Enum.map(history, fn msg ->
      %{role: msg.role, content: msg.content}
    end)
  end
end
