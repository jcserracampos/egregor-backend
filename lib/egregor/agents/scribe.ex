defmodule Egregor.Agents.Scribe do
  @moduledoc """
  Agente Escriba — transcrição de áudio para texto via Whisper large-v3.
  Preserva linguagem natural, sem correção gramatical.
  """

  alias Egregor.Agents.OpenRouter

  def transcribe(audio_path) do
    OpenRouter.transcribe(audio_path)
  end
end
