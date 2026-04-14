defmodule EgregorWeb.EntryControllerTest do
  use EgregorWeb.ConnCase, async: false
  use Oban.Testing, repo: Egregor.Repo

  alias Egregor.Entries

  describe "POST /api/entries" do
    test "returns 201 with entry data when raw_text is provided", %{conn: conn} do
      conn =
        post(conn, "/api/entries", %{"raw_text" => "primeira captura"})

      assert %{"data" => data} = json_response(conn, 201)
      assert data["raw_text"] == "primeira captura"
      assert data["id"] != nil
      assert data["urgency"] == "low"
      assert data["categories"] == []
    end

    test "returns 422 when raw_text is missing", %{conn: conn} do
      conn = post(conn, "/api/entries", %{})

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Map.has_key?(errors, "raw_text")
    end
  end

  describe "GET /api/entries" do
    test "returns 200 with list of entries", %{conn: conn} do
      {:ok, _} = Entries.create_entry(%{raw_text: "entry one"})
      {:ok, _} = Entries.create_entry(%{raw_text: "entry two"})

      conn = get(conn, "/api/entries")

      assert %{"data" => data} = json_response(conn, 200)
      assert length(data) >= 2
    end

    test "returns empty list when no entries exist", %{conn: conn} do
      conn = get(conn, "/api/entries")

      assert %{"data" => []} = json_response(conn, 200)
    end
  end

  describe "PATCH /api/entries/:id" do
    test "returns 200 and updates the entry fields", %{conn: conn} do
      {:ok, entry} = Entries.create_entry(%{raw_text: "original text"})

      conn = patch(conn, "/api/entries/#{entry.id}", %{"raw_text" => "updated text"})

      assert %{"data" => data} = json_response(conn, 200)
      assert data["raw_text"] == "updated text"
      assert data["id"] == entry.id
    end

    test "updates urgency field", %{conn: conn} do
      {:ok, entry} = Entries.create_entry(%{raw_text: "some thought"})

      conn = patch(conn, "/api/entries/#{entry.id}", %{"urgency" => "high"})

      assert %{"data" => data} = json_response(conn, 200)
      assert data["urgency"] == "high"
    end
  end
end
