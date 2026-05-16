defmodule EgregorWeb.Router do
  use EgregorWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Health check — no pipeline, no auth, Flutter connectivity probe
  scope "/api", EgregorWeb do
    get "/health", HealthController, :check
    get "/debug", HealthController, :debug
    post "/debug/recategorize", HealthController, :recategorize
  end

  scope "/api", EgregorWeb do
    pipe_through :api

    # Entries — core capture and retrieval
    post "/entries/audio", EntryController, :create_audio
    patch "/entries/:id/transmute", EntryController, :transmute
    patch "/entries/:id/mark_resurgence", EntryController, :mark_resurgence
    get "/entries/:id/resurgence_candidates", EntryController, :resurgence_candidates
    resources "/entries", EntryController, only: [:index, :create, :show, :update, :delete]

    # Filaments — manual idea chains
    post "/filaments/:id/entries", FilamentController, :add_entry
    resources "/filaments", FilamentController, only: [:index, :show, :create]

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
