defmodule EgregorWeb.OracleController do
  use EgregorWeb, :controller

  alias Egregor.Agents.PhraseAgent
  alias Egregor.Categories
  alias Egregor.Convergences
  alias Egregor.Entries
  alias Egregor.Narratives
  alias Egregor.Oracle
  alias Egregor.Time

  # Phrase cached per hour (key: "YYYY-MM-DD-HH")
  def phrase(conn, _params) do
    cache_key = phrase_cache_key()

    phrase =
      case :ets.lookup(:oracle_phrase_cache, cache_key) do
        [{^cache_key, cached}] ->
          cached

        [] ->
          summary = build_archive_summary()

          case PhraseAgent.generate(summary) do
            {:ok, text} ->
              :ets.insert(:oracle_phrase_cache, {cache_key, text})
              text

            {:error, _} ->
              "Solve et Coagula."
          end
      end

    json(conn, %{data: %{phrase: phrase, cache_key: cache_key}})
  end

  def convergence(conn, _params) do
    convergence = Convergences.latest_unseen()

    if convergence do
      Convergences.mark_seen(convergence)
      json(conn, %{data: serialize_convergence(convergence)})
    else
      json(conn, %{data: nil})
    end
  end

  def narrative(conn, _params) do
    case Narratives.generate_for_week() do
      {:ok, narrative} ->
        json(conn, %{data: serialize_narrative(narrative)})

      {:error, reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{error: "Narrator unavailable", reason: inspect(reason)})
    end
  end

  def context(conn, _params) do
    ctx = Oracle.get_context()

    json(conn, %{
      data: %{
        obsessions: ctx.obsessions || [],
        raw_summary: ctx.raw_summary,
        vocabulary: ctx.vocabulary || %{},
        updated_at: ctx.updated_at
      }
    })
  end

  def ritual_mode(conn, _params) do
    is_ritual = Time.ritual_mode?()
    json(conn, %{data: %{is_ritual: is_ritual, hour: Time.local_hour()}})
  end

  defp phrase_cache_key, do: Time.hourly_cache_key()

  defp build_archive_summary do
    count = Entries.count_entries()
    recent = Entries.list_recent(5)
    oracle_ctx = Oracle.get_context()
    dominant = Categories.list_active() |> List.first()
    latest_convergence = Convergences.latest_unseen()
    last_intention = Entries.last_intention()

    parts = ["#{count} entradas no acervo."]

    parts =
      case dominant do
        nil -> parts
        cat -> parts ++ ["Categoria mais ativa: #{cat.name} (#{cat.entry_count} entradas)."]
      end

    parts =
      case oracle_ctx do
        nil ->
          parts

        ctx ->
          obsessions = ctx.obsessions || []

          if obsessions != [] do
            parts ++ ["Obsessões recorrentes: #{Enum.join(obsessions, ", ")}."]
          else
            parts
          end
      end

    parts =
      case last_intention do
        nil -> parts
        e -> parts ++ ["Última intenção marcada: \"#{String.slice(e.raw_text, 0, 80)}\"."]
      end

    parts =
      case latest_convergence do
        nil -> parts
        c -> parts ++ ["Convergência detectada recentemente: #{c.message}"]
      end

    parts =
      if recent != [] do
        recent_text =
          recent
          |> Enum.map(fn e -> String.slice(e.raw_text, 0, 60) end)
          |> Enum.join("; ")

        parts ++ ["Entradas recentes: #{recent_text}."]
      else
        parts
      end

    Enum.join(parts, " ")
  end

  defp serialize_convergence(c) do
    %{
      id: c.id,
      message: c.message,
      pattern_type: c.pattern_type,
      entry_ids: c.entry_ids,
      inserted_at: c.inserted_at
    }
  end

  defp serialize_narrative(n) do
    %{
      id: n.id,
      content: n.content,
      period_start: n.period_start,
      period_end: n.period_end,
      inserted_at: n.inserted_at
    }
  end
end
