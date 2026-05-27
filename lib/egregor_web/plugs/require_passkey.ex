defmodule EgregorWeb.Plugs.RequirePasskey do
  @moduledoc """
  Plug that requires the session to be authenticated with the web passkey.
  Redirects unauthenticated requests to /web/login.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  def init(opts), do: opts

  def call(conn, _opts) do
    if get_session(conn, :authenticated) do
      conn
    else
      conn
      |> redirect(to: "/web/login")
      |> halt()
    end
  end
end
