defmodule EgregorWeb.CategoryController do
  use EgregorWeb, :controller

  alias Egregor.Categories

  def index(conn, _params) do
    categories = Categories.list_active()
    json(conn, %{data: Enum.map(categories, &serialize/1)})
  end

  defp serialize(cat) do
    %{
      id: cat.id,
      name: cat.name,
      color: cat.color,
      glow_color: cat.glow_color,
      symbol: cat.symbol,
      entry_count: cat.entry_count,
      awakened: cat.awakened,
      awakened_at: cat.awakened_at,
      is_shadow_category: cat.name == "Sombra",
      inserted_at: cat.inserted_at
    }
  end
end
