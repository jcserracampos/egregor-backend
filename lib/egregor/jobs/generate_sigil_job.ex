defmodule Egregor.Jobs.GenerateSigilJob do
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Egregor.Repo
  alias Egregor.Entries.Entry

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"entry_id" => entry_id}}) do
    entry = Repo.get!(Entry, entry_id)

    if entry.is_intention do
      sigil_data = generate_sigil(entry.raw_text)

      entry
      |> Entry.intention_changeset(%{sigil_data: sigil_data})
      |> Repo.update()

      :ok
    else
      :ok
    end
  end

  # Generates deterministic Lissajous curve parameters from SHA-256 hash of text.
  # The Flutter client uses these parameters to render the sigil via CustomPainter.
  defp generate_sigil(text) do
    hash = :crypto.hash(:sha256, text)
    bytes = :binary.bin_to_list(hash)

    freq_x = (Enum.at(bytes, 0) / 255.0 * 4 + 1) |> Float.round(2)
    freq_y = (Enum.at(bytes, 1) / 255.0 * 4 + 1) |> Float.round(2)
    phase = (Enum.at(bytes, 2) / 255.0 * :math.pi()) |> Float.round(4)
    amplitude = (Enum.at(bytes, 3) / 255.0 * 0.5 + 0.5) |> Float.round(2)

    # Generate stroke color from bytes 4-6
    r = Enum.at(bytes, 4) |> Integer.to_string(16) |> String.pad_leading(2, "0")
    g = Enum.at(bytes, 5) |> Integer.to_string(16) |> String.pad_leading(2, "0")
    b = Enum.at(bytes, 6) |> Integer.to_string(16) |> String.pad_leading(2, "0")
    stroke_color = "##{r}#{g}#{b}"

    # Pre-compute Lissajous points for the Flutter client
    points =
      0..99
      |> Enum.map(fn i ->
        t = i / 100.0 * 2 * :math.pi()
        x = :math.sin(freq_x * t + phase) * amplitude
        y = :math.sin(freq_y * t) * amplitude
        [Float.round(x, 4), Float.round(y, 4)]
      end)

    %{
      frequency_x: freq_x,
      frequency_y: freq_y,
      phase: phase,
      amplitude: amplitude,
      stroke_color: stroke_color,
      points: points
    }
  end
end
