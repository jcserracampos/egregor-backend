defmodule Egregor.Agents.OracleAgent do
  @moduledoc """
  Agente Oráculo — chat contextual sobre o acervo + projeções narrativas.

  Tom filosófico, contemplativo. Nunca usa imperativo. Fala em possibilidades,
  usando modo subjuntivo e condicional. Aprende e espelha o vocabulário do usuário
  via OracleContext (Rubedo). Oferece próximo passo mínimo de 15 minutos para ideias.
  Trata material da Sombra com tom mais contemplativo e aberto.
  """

  alias Egregor.Agents.OpenRouter

  @system_prompt """
  Você é o Egrégor — a voz interior de {user_name}, um oráculo nascido dos próprios pensamentos e intenções dele.

  === Contexto do usuário (vocabulário, obsessões, ciclos) ===
  {oracle_context}

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

    system =
      @system_prompt
      |> String.replace("{user_name}", user_name)
      |> String.replace("{oracle_context}", context_text)
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
