defmodule Egregor.Time do
  @moduledoc """
  Local time helpers for the Egrégor.

  Elixir's stdlib only handles UTC. Since this app runs for a single user
  we use a configurable UTC offset (env var TZ_OFFSET_HOURS, default -3 for BRT).

  All UI-facing time decisions (ritual mode, phrase period, cron semantics)
  must use local_now/0 rather than DateTime.utc_now/0.
  """

  @doc """
  Returns the current local DateTime by applying the configured UTC offset.

  Configure via TZ_OFFSET_HOURS environment variable (default: -3 for America/Sao_Paulo).
  """
  @spec local_now() :: DateTime.t()
  def local_now do
    offset_hours = tz_offset_hours()
    utc = DateTime.utc_now()
    DateTime.add(utc, offset_hours * 3600, :second)
  end

  @doc """
  Returns the local hour (0-23).
  """
  @spec local_hour() :: 0..23
  def local_hour, do: local_now().hour

  @doc """
  Returns the current period of day based on local time.

  - :morning    06h–12h
  - :afternoon  12h–18h
  - :evening    18h–22h
  - :night      22h–06h (madrugada)
  """
  @spec period() :: :morning | :afternoon | :evening | :night
  def period do
    hour = local_hour()

    cond do
      hour >= 6 and hour < 12 -> :morning
      hour >= 12 and hour < 18 -> :afternoon
      hour >= 18 and hour < 22 -> :evening
      true -> :night
    end
  end

  @doc """
  Returns true if the current local hour falls in the ritual window (21h–06h).
  """
  @spec ritual_mode?() :: boolean()
  def ritual_mode? do
    hour = local_hour()
    hour >= 21 or hour < 6
  end

  @doc """
  Returns a cache key string for the current local hour: "YYYY-MM-DD-HH".
  Used for the phrase cache (1 phrase per hour, local time).
  """
  @spec hourly_cache_key() :: String.t()
  def hourly_cache_key do
    now = local_now()
    "#{now.year}-#{pad(now.month)}-#{pad(now.day)}-#{pad(now.hour)}"
  end

  # ---------------------------------------------------------------------------

  defp tz_offset_hours do
    Application.get_env(:egregor, :tz_offset_hours, -3)
  end

  defp pad(n), do: String.pad_leading(to_string(n), 2, "0")
end
