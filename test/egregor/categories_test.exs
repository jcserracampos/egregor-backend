defmodule Egregor.CategoriesTest do
  use Egregor.DataCase, async: false

  alias Egregor.Categories

  describe "seed_defaults/0" do
    test "creates the 7 default categories" do
      Categories.seed_defaults()
      categories = Categories.list_all()

      assert length(categories) == 7

      names = Enum.map(categories, & &1.name)
      assert "Ideias" in names
      assert "Compras" in names
      assert "Tarefas" in names
      assert "Projetos" in names
      assert "Pessoas" in names
      assert "Reflexões" in names
      assert "Sombra" in names
    end

    test "is idempotent — calling twice still yields 7 categories" do
      Categories.seed_defaults()
      Categories.seed_defaults()

      assert length(Categories.list_all()) == 7
    end
  end

  describe "get_or_create/1" do
    test "returns existing category when it already exists" do
      {:ok, existing} = Categories.create_category("Sonhos")

      {:ok, found} = Categories.get_or_create("Sonhos")
      assert found.id == existing.id
    end

    test "creates a new category when it does not exist" do
      assert is_nil(Categories.get_by_name("Nova"))

      assert {:ok, category} = Categories.get_or_create("Nova")
      assert category.name == "Nova"
      assert category.id != nil
    end
  end

  describe "increment_count/1" do
    test "increments entry_count by 1" do
      {:ok, category} = Categories.create_category("Counter")

      assert category.entry_count == 0

      {:ok, updated} = Categories.increment_count(category)
      assert updated.entry_count == 1

      {:ok, updated2} = Categories.increment_count(updated)
      assert updated2.entry_count == 2
    end
  end
end
