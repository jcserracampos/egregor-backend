defmodule Egregor.Jobs.GenerateSigilJobTest do
  use Egregor.DataCase, async: false
  use Oban.Testing, repo: Egregor.Repo

  alias Egregor.Jobs.GenerateSigilJob
  alias Egregor.Entries.Entry

  defp insert_intention_entry(raw_text) do
    %Entry{}
    |> Entry.changeset(%{raw_text: raw_text, is_intention: true})
    |> Repo.insert!()
  end

  describe "perform/1" do
    test "same text always produces the same sigil_data" do
      entry = insert_intention_entry("abrir uma barbearia afro")

      assert :ok = GenerateSigilJob.perform(%Oban.Job{args: %{"entry_id" => entry.id}})
      first = Repo.get!(Entry, entry.id).sigil_data

      # Update sigil_data to nil to force re-generation
      Repo.update!(Entry.intention_changeset(entry, %{sigil_data: nil}))

      assert :ok = GenerateSigilJob.perform(%Oban.Job{args: %{"entry_id" => entry.id}})
      second = Repo.get!(Entry, entry.id).sigil_data

      assert first == second
    end

    test "sigil_data contains all required fields" do
      entry = insert_intention_entry("intenção de criar algo novo")

      assert :ok = GenerateSigilJob.perform(%Oban.Job{args: %{"entry_id" => entry.id}})
      sigil = Repo.get!(Entry, entry.id).sigil_data

      assert Map.has_key?(sigil, "frequency_x")
      assert Map.has_key?(sigil, "frequency_y")
      assert Map.has_key?(sigil, "phase")
      assert Map.has_key?(sigil, "amplitude")
      assert Map.has_key?(sigil, "stroke_color")
      assert Map.has_key?(sigil, "points")
    end

    test "points list has exactly 100 pairs" do
      entry = insert_intention_entry("cem pontos na curva")

      assert :ok = GenerateSigilJob.perform(%Oban.Job{args: %{"entry_id" => entry.id}})
      sigil = Repo.get!(Entry, entry.id).sigil_data

      assert length(sigil["points"]) == 100
      assert Enum.all?(sigil["points"], fn pair -> length(pair) == 2 end)
    end

    test "stroke_color is a valid hex color string" do
      entry = insert_intention_entry("cor do sigilo")

      assert :ok = GenerateSigilJob.perform(%Oban.Job{args: %{"entry_id" => entry.id}})
      sigil = Repo.get!(Entry, entry.id).sigil_data

      assert sigil["stroke_color"] =~ ~r/^#[0-9a-fA-F]{6}$/
    end

    test "does not update sigil_data when entry is not an intention" do
      entry =
        %Entry{}
        |> Entry.changeset(%{raw_text: "not an intention", is_intention: false})
        |> Repo.insert!()

      assert :ok = GenerateSigilJob.perform(%Oban.Job{args: %{"entry_id" => entry.id}})

      assert Repo.get!(Entry, entry.id).sigil_data == nil
    end
  end
end
