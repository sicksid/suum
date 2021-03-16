defmodule Suum.Hls.Transmissions.Observer do
  use GenServer
  require Logger
  alias Suum.Hls.Jobs.UpsertMediaElement

  @transmissions_base_path "./mnt/hls/live"

  def start_link(state) do
    GenServer.start_link(__MODULE__, state)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:save, uuid}, state) do
    playlist = get_playlist(uuid)
    thumbnails = get_thumbnails(uuid)

    if File.exists?(playlist) do
      Logger.info("Received order to save #{playlist}")
      acc = []
      {:ok, raw} = File.read(playlist)
      lines = raw |> String.split("\n") |> Enum.with_index()

      case lines
           |> Enum.reduce(acc, &parse_segment(&1, &2, lines, uuid))
           |> enqueue_upsert(:segment) do
        :ok ->
          Logger.info("Enqueuing jobs to save segments")
      end
    end

    if File.exists?(thumbnails) do
      Logger.info("Received order to save #{thumbnails}")
      acc = []
      {:ok, raw} = File.read(thumbnails)
      lines = String.split(raw, "\n")

      case lines
           |> Enum.reduce(acc, &parse_thumbnail(&1, &2, uuid))
           |> enqueue_upsert(:thumbnail) do
        :ok ->
          Logger.info("Enqueuing jobs to save thumbails")
      end
    end

    {:noreply, state}
  end

  defp parse_thumbnail("", thumbnails, _uuid), do: thumbnails

  defp parse_thumbnail(thumbnail, thumbnails, uuid) do
    file = "#{@transmissions_base_path}/#{uuid}/#{thumbnail}"
    [timestamp_raw | _] = String.split(thumbnail, ".jpeg")
    timestamp = String.to_integer(timestamp_raw)

    thumbnail = %{
      timestamp: DateTime.from_unix!(timestamp, :millisecond),
      file: file,
      transmission_uuid: uuid
    }

    [thumbnail | thumbnails]
  end

  defp parse_segment({"#EXTINF:" <> duration_raw, i}, segments, lines, uuid) do
    {file, _i} = Enum.at(lines, i + 1)
    [timestamp_raw | _] = String.split(file, ".ts")
    timestamp = String.to_integer(timestamp_raw)
    file = "#{@transmissions_base_path}/#{uuid}/#{file}"

    segment = %{
      duration: trunc((duration_raw |> String.trim(",") |> String.to_float()) * 1000),
      timestamp: DateTime.from_unix!(timestamp, :millisecond),
      file: file,
      transmission_uuid: uuid
    }

    Logger.info(inspect(segment, pretty: true))
    Logger.info("Processing #{file}")
    [segment | segments]
  end

  defp parse_segment(_line, segments, _lines, _) do
    segments
  end

  defp enqueue_upsert(segments, :segment),
    do: Enum.each(segments, &UpsertMediaElement.enqueue!(%{type: :segment, attrs: &1}))

  defp enqueue_upsert(thumbnails, :thumbnail),
    do: Enum.each(thumbnails, &UpsertMediaElement.enqueue!(%{type: :thumbnail, attrs: &1}))

  defp get_playlist(transmission_uuid),
    do: "#{@transmissions_base_path}/#{transmission_uuid}/index.m3u8"

  defp get_thumbnails(transmission_uuid),
    do: "#{@transmissions_base_path}/#{transmission_uuid}/thumbnails.txt"
end