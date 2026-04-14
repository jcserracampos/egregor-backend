defmodule Egregor.Categories do
  import Ecto.Query
  alias Egregor.Repo
  alias Egregor.Categories.Category

  # Default colors for initial categories
  @defaults %{
    "Ideias" => %{color: "#c9aa82", glow_color: "#d4b896"},
    "Compras" => %{color: "#8a6a9a", glow_color: "#9a7aaa"},
    "Tarefas" => %{color: "#8a1839", glow_color: "#9a2849"},
    "Projetos" => %{color: "#4a7a6a", glow_color: "#5a8a7a"},
    "Pessoas" => %{color: "#7a5a3a", glow_color: "#8a6a4a"},
    "Reflexões" => %{color: "#3a5a8a", glow_color: "#4a6a9a"},
    "Sombra" => %{color: "#2a2a4a", glow_color: "#3a3a5a"}
  }

  def list_active do
    Category
    |> where([c], c.entry_count > 0)
    |> order_by([c], desc: c.entry_count)
    |> Repo.all()
  end

  def list_all do
    Category
    |> order_by([c], desc: c.entry_count)
    |> Repo.all()
  end

  def get_category!(id), do: Repo.get!(Category, id)

  def get_by_name(name) do
    Repo.get_by(Category, name: name)
  end

  def get_or_create(name) do
    case get_by_name(name) do
      nil -> create_category(name)
      category -> {:ok, category}
    end
  end

  def create_category(name) do
    {color, glow_color} = colors_for(name)

    %Category{}
    |> Category.changeset(%{name: name, color: color, glow_color: glow_color})
    |> Repo.insert(on_conflict: :nothing, conflict_target: :name)
    |> case do
      {:ok, %Category{id: nil}} -> {:ok, get_by_name(name)}
      result -> result
    end
  end

  def increment_count(%Category{} = category) do
    category
    |> Ecto.Changeset.change(entry_count: category.entry_count + 1)
    |> Repo.update()
  end

  def decrement_count(%Category{} = category) do
    new_count = max(0, category.entry_count - 1)

    category
    |> Ecto.Changeset.change(entry_count: new_count)
    |> Repo.update()
  end

  def awaken(%Category{} = category, symbol) do
    category
    |> Category.awaken_changeset(symbol)
    |> Repo.update()
  end

  def seed_defaults do
    Enum.each(@defaults, fn {name, colors} ->
      unless get_by_name(name) do
        %Category{}
        |> Category.changeset(Map.put(colors, :name, name))
        |> Repo.insert!(on_conflict: :nothing, conflict_target: :name)
      end
    end)
  end

  defp colors_for(name) do
    case Map.get(@defaults, name) do
      %{color: c, glow_color: g} ->
        {c, g}

      nil ->
        # Generate color from hash of name
        hash = :crypto.hash(:md5, name) |> Base.encode16(case: :lower)
        r = String.slice(hash, 0, 2)
        g = String.slice(hash, 2, 2)
        b = String.slice(hash, 4, 2)
        color = "##{r}#{g}#{b}"
        # Slightly lighter for glow
        glow = "##{String.slice(hash, 6, 2)}#{String.slice(hash, 8, 2)}#{String.slice(hash, 10, 2)}"
        {color, glow}
    end
  end
end
