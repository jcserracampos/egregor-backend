defmodule EgregorWeb.PageController do
  use EgregorWeb, :controller

  def login(conn, _params) do
    render(conn, :login, error: nil)
  end

  def authenticate(conn, %{"passkey" => passkey}) do
    expected = System.get_env("WEB_PASSKEY") || ""

    if passkey != "" and passkey == expected do
      conn
      |> put_session(:authenticated, true)
      |> redirect(to: ~p"/web")
    else
      render(conn, :login, error: "Chave incorreta.")
    end
  end

  def logout(conn, _params) do
    conn
    |> delete_session(:authenticated)
    |> redirect(to: ~p"/web/login")
  end
end
