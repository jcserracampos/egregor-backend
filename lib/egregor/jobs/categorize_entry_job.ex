defmodule Egregor.Jobs.CategorizeEntryJob do
  use Oban.Worker, queue: :categorization, max_attempts: 3

  alias Egregor.Repo
  alias Egregor.Entries.Entry
  alias Egregor.Agents.Taxonomist
  alias Egregor.Categories
  alias Egregor.Jobs.AwakenCategoryJob

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"entry_id" => entry_id}}) do
    entry = Repo.get!(Entry, entry_id)
    text = entry.transcription || entry.raw_text

    existing_categories =
      Categories.list_all()
      |> Enum.map(& &1.name)

    case Taxonomist.categorize(text, existing_categories) do
      {:ok, %{categories: cat_names, urgency: urgency, is_shadow: is_shadow, summary: summary}} ->
        # Ensure all categories exist in the DB
        categories =
          Enum.map(cat_names, fn name ->
            {:ok, cat} = Categories.get_or_create(name)
            cat
          end)

        # Increment count for each category
        Enum.each(categories, &Categories.increment_count/1)

        # Update entry
        entry
        |> Entry.categorize_changeset(%{
          categories: cat_names,
          urgency: urgency,
          is_shadow: is_shadow,
          summary: summary
        })
        |> Repo.update!()

        # Check for awakening (10 entries threshold)
        Enum.each(categories, fn cat ->
          refreshed = Categories.get_category!(cat.id)

          if refreshed.entry_count >= 10 and not refreshed.awakened do
            %{"category_id" => cat.id}
            |> AwakenCategoryJob.new()
            |> Oban.insert()
          end
        end)

        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end
end
