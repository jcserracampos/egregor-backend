defmodule Egregor.Oracle do
  alias Egregor.Repo
  alias Egregor.Oracle.OracleContext

  def get_context do
    case Repo.all(OracleContext) do
      [] ->
        {:ok, context} =
          %OracleContext{}
          |> OracleContext.changeset(%{vocabulary: %{}, obsessions: [], cycles: %{}})
          |> Repo.insert()

        context

      [context | _] ->
        context
    end
  end

  def update_context(attrs) do
    context = get_context()

    context
    |> OracleContext.changeset(merge_context(context, attrs))
    |> Repo.update()
  end

  # Merges new context data with existing, accumulating rather than replacing
  defp merge_context(existing, new_attrs) do
    vocab_merged =
      Map.merge(
        existing.vocabulary || %{},
        new_attrs[:vocabulary] || new_attrs["vocabulary"] || %{}
      )

    obsessions_merged =
      ((existing.obsessions || []) ++
         (new_attrs[:obsessions] || new_attrs["obsessions"] || []))
      |> Enum.uniq()
      |> Enum.take(20)

    cycles_merged =
      Map.merge(
        existing.cycles || %{},
        new_attrs[:cycles] || new_attrs["cycles"] || %{}
      )

    %{
      vocabulary: vocab_merged,
      obsessions: obsessions_merged,
      cycles: cycles_merged,
      raw_summary: new_attrs[:raw_summary] || new_attrs["raw_summary"] || existing.raw_summary
    }
  end
end
