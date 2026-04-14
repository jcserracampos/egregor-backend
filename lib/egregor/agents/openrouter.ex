defmodule Egregor.Agents.OpenRouter do
  @moduledoc """
  Base HTTP client for OpenRouter API.
  All LLM and embedding calls go through here.
  """

  @base_url "https://openrouter.ai/api/v1"

  def chat(model, messages, opts \\ []) do
    body =
      %{
        model: model,
        messages: messages
      }
      |> maybe_put(:temperature, opts[:temperature])
      |> maybe_put(:max_tokens, opts[:max_tokens])

    post("/chat/completions", body)
    |> case do
      {:ok, %{"choices" => [%{"message" => %{"content" => content}} | _]}} ->
        {:ok, content}

      {:ok, response} ->
        {:error, {:unexpected_response, response}}

      error ->
        error
    end
  end

  def embed(text) do
    model = model(:embedding)

    body = %{
      model: model,
      input: text
    }

    post("/embeddings", body)
    |> case do
      {:ok, %{"data" => [%{"embedding" => embedding} | _]}} ->
        {:ok, embedding}

      {:ok, response} ->
        {:error, {:unexpected_response, response}}

      error ->
        error
    end
  end

  # Whisper orientation prompt (SPEC §5 Agente I).
  # The `prompt` parameter biases the model toward preserving natural speech
  # and avoiding grammar corrections — critical for noisy real-world capture.
  @whisper_prompt """
  Transcreva o áudio com precisão máxima. Preserve a linguagem natural do falante, \
  incluindo hesitações e vocabulário informal. Não corrija gramática. \
  Não adicione pontuação além do necessário para compreensão. \
  Retorne apenas o texto transcrito, sem metadados.\
  """

  def transcribe(audio_path) do
    model = model(:scribe)
    api_key = api_key()

    Req.post(
      url: "#{base_url()}/audio/transcriptions",
      headers: [
        {"Authorization", "Bearer #{api_key}"},
        {"HTTP-Referer", "https://github.com/egregor"},
        {"X-Title", "Egregor"}
      ],
      form_multipart: [
        model: model,
        file: {File.read!(audio_path), filename: Path.basename(audio_path)},
        response_format: "text",
        prompt: @whisper_prompt
      ]
    )
    |> case do
      {:ok, %Req.Response{status: 200, body: text}} when is_binary(text) ->
        {:ok, String.trim(text)}

      {:ok, %Req.Response{status: 200, body: %{"text" => text}}} ->
        {:ok, String.trim(text)}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp post(path, body) do
    api_key = api_key()

    Req.post(
      url: "#{base_url()}#{path}",
      headers: [
        {"Authorization", "Bearer #{api_key}"},
        {"Content-Type", "application/json"},
        {"HTTP-Referer", "https://github.com/egregor"},
        {"X-Title", "Egregor"}
      ],
      json: body,
      receive_timeout: 30_000
    )
    |> case do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp api_key do
    case Application.get_env(:egregor, :openrouter) do
      nil -> raise "OpenRouter not configured. Set OPENROUTER_API_KEY environment variable."
      config -> config[:api_key]
    end
  end

  defp base_url do
    case Application.get_env(:egregor, :openrouter) do
      nil -> @base_url
      config -> config[:base_url] || @base_url
    end
  end

  def model(key) do
    Application.get_env(:egregor, :models, [])[key] ||
      raise "Model #{key} not configured"
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
