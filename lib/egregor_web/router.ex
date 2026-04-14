defmodule EgregorWeb.Router do
  use EgregorWeb, :router

  pipeline :api do
    plug CORSPlug, origin: "*"
    plug :accepts, ["json"]
  end

  # Health check — no pipeline, no auth, Flutter connectivity probe
  scope "/api", EgregorWeb do
    get "/health", HealthController, :check
  end

  scope "/api", EgregorWeb do
    pipe_through :api

    # Entries — core capture and retrieval
    post "/entries/audio", EntryController, :create_audio
    patch "/entries/:id/transmute", EntryController, :transmute
    resources "/entries", EntryController, only: [:index, :create, :show, :update]

    # Categories — dashboard data
    get "/categories", CategoryController, :index

    # Chat with the Oracle
    get "/chat/messages", ChatController, :messages
    post "/chat", ChatController, :create

    # Oracle utilities
    get "/oracle/phrase", OracleController, :phrase
    get "/oracle/narrative", OracleController, :narrative
    get "/oracle/ritual_mode", OracleController, :ritual_mode
    get "/oracle/context", OracleController, :context
    get "/convergences/latest", OracleController, :convergence

    # Milestones
    get "/milestones", MilestoneController, :index
  end
end
