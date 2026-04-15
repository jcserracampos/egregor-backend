defmodule Egregor.Jobs.NameFilamentJob do
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Egregor.Filaments
  alias Egregor.Agents.FilamentNamer
  alias Egregor.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"filament_id" => filament_id}}) do
    filament = Filaments.get_filament_with_entries(filament_id)

    if length(filament.entries) < 2 do
      :ok
    else
      case FilamentNamer.name(filament.entries) do
        {:ok, nil} ->
          :ok

        {:ok, name} ->
          filament
          |> Egregor.Filaments.Filament.name_changeset(name)
          |> Repo.update()

          :ok

        {:error, _reason} ->
          :ok
      end
    end
  rescue
    Ecto.NoResultsError -> :ok
  end
end
