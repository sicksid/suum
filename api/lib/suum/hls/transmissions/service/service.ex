defmodule Suum.Hls.Transmissions.Service do
  use GenServer

  alias Suum.{
    Hls,
    Hls.Transmission,
    Hls.Transmissions.Service.State,
    Hls.Jobs.UpsertMediaElement
  }

  require Logger

  @initial_state %State{}
  @default_interval 5_000

  # Process.flag(:trap_exit, true)
  def start_link(transmission),
    do:
      GenServer.start_link(
        __MODULE__,
        [
          transmission: transmission,
          processed_lines: []
        ],
        name: process_name(transmission)
      )

  @impl true
  def init(args) do
    Logger.info("Initializing Transmission with args: #{inspect(args, pretty: true)}")
    Process.send_after(__MODULE__, :watch, @default_interval)
    {:ok, args}
  end

  @impl true
  def handle_cast(
        {:uploading, [transmission: %Transmission{type: :vod, uuid: uuid}]},
        state
      ) do
    transmission = Hls.get_transmission(uuid)
    transmission_path = "#{base_path(transmission.type)}/#{uuid}"
    {:ok, _, _} = :exec.run("mkdir -p #{transmission_path}", [])
    {:noreply, state}
  end

  def handle_cast(
        {:streaming,
         [
           transmission: %Transmission{type: :live, uuid: uuid} = transmission
         ]},
        state
      ) do
    Logger.info("Sync Playlist Request #{uuid}")
    playlist = get_playlist("./mnt/hls/live", uuid)
    {:ok, pid} = FileSystem.start_link(dirs: [playlist], name: :playlist)
    FileSystem.subscribe(pid)
    {:noreply, Keyword.merge(state, transmission: transmission)}
  end

  def handle_cast(
        {:streaming,
         [
           transmission:
             %Transmission{
               type: :vod,
               uuid: uuid,
               upload_name: upload_name,
               uid: uid
             } = _transmission
         ]},
        state
      ) do
    file_dir =
      uid
      |> String.slice(0..2)
      |> String.split("")
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("/")

    base_path = base_path(:vod)
    transmission_path = "#{base_path}/#{uuid}"

    video_file_path = "#{transmission_path}/#{upload_name}"
    Logger.info("Created #{transmission_path}")

    {:ok, _, _} =
      :exec.run(
        ~w(
          mv
          #{base_path}/#{file_dir}/#{uid}
          #{video_file_path}
        ),
        []
      )

    Logger.info("Copied #{base_path}/#{file_dir}/#{uid} to #{transmission_path}")

    command = ~w(
      /usr/local/bin/ffmpeg
      -re -nostdin
      -i #{video_file_path}
      -vcodec libx264
      -preset:v ultrafast
      -acodec aac
      -f flv
      #{rtmp_host()}/live/#{uuid}
      )

    {:ok, _, _} = :exec.run(command, [])
    # {:ok, _} = Transmission.transition_to(transmission, "processing")
    Logger.info("Processing #{video_file_path}")
    {:noreply, state}
  end

  def handle_cast(
        {:processing, [transmission: %Transmission{type: :live, uuid: uuid} = transmission]},
        state
      ) do
    Logger.info("Processing #{uuid}")
    base_path = base_path(:live)
    thumbnails = get_thumbnails(base_path, uuid)
    save_thumbnails(thumbnails, uuid, base_path)
    :timer.sleep(2000)
    {:ok, _} = Transmission.transition_to(transmission, "ready")
    {:noreply, state}
  end

  def handle_cast(
        {:processing, [transmission: %Transmission{type: :vod, uuid: uuid} = transmission]},
        state
      ) do
    Logger.info("Processing #{uuid}")
    base_path = base_path(:live)
    thumbnails = get_thumbnails(base_path, uuid)
    playlist = get_playlist(base_path, uuid)
    save_thumbnails(thumbnails, uuid, base_path)
    save_playlist(transmission, playlist, [])
    {:ok, _} = Transmission.transition_to(transmission, "ready")
    {:noreply, state}
  end

  def handle_cast(
        {:ready,
         [transmission: %Transmission{name: name, type: type, uuid: uuid} = _transmission]},
        state
      ) do
    Logger.info("Ready to watch #{type} - #{uuid} | #{name}")
    {:noreply, state}
  end

  def handle_cast(request, state) do
    Logger.warn("Unrecognized request #{inspect(request, pretty: true)}")
    {:noreply, state}
  end

  @impl true
  def handle_info(
        {:file_event, _watcher_pid, {playlist, events}},
        [
          processed_lines: processed_lines,
          transmission: %Transmission{} = transmission
        ] = state
      ) do
    Logger.info("file event - #{playlist} -  #{inspect(events, pretty: true)}")
    next_processed_lines = save_playlist(transmission, playlist, processed_lines)
    # state = State.put_processed_lines(state, processed_lines)
    state = Keyword.put(state, :processed_lines, next_processed_lines)
    {:noreply, state}
  end

  def handle_info(:watch, state) do
    Logger.info("watching....")
    transmissions = Hls.list_transmissions(%{state: "created"})

    Logger.info("found #{length(transmissions)} transmissions")

    Process.send_after(__MODULE__, :watch, @default_interval)
    {:noreply, state}
  end

  defp save_playlist(
         %Transmission{uuid: uuid} = _transmission,
         playlist_path,
         processed_lines
       ) do
    acc = []
    {:ok, raw} = File.read(playlist_path)
    base_path = base_path(:live)
    lines = raw |> String.split("\n") |> Enum.with_index()

    next_processed_lines =
      lines
      |> Enum.reject(&Enum.member?(processed_lines, &1))
      |> Enum.reduce(acc, &parse_segment(&1, &2, lines, uuid, base_path))

    enqueue_upsert(next_processed_lines, :segment)
    next_processed_lines
  end

  defp save_thumbnails(thumbnails, uuid, base_path) do
    Logger.info("Received order to save #{thumbnails}")
    acc = []
    {:ok, raw} = File.read(thumbnails)
    lines = String.split(raw, "\n")

    case lines
         |> Enum.reduce(acc, &parse_thumbnail(&1, &2, uuid, base_path))
         |> enqueue_upsert(:thumbnail) do
      :ok ->
        Logger.info("Enqueuing jobs to save thumbails")
    end
  end

  defp parse_thumbnail("", thumbnails, _uuid, _transmissions_base_path), do: thumbnails

  defp parse_thumbnail(thumbnail, thumbnails, uuid, transmissions_base_path) do
    file = "#{transmissions_base_path}/#{uuid}/#{thumbnail}"
    [timestamp_raw | _] = String.split(thumbnail, ".jpeg")
    timestamp = String.to_integer(timestamp_raw)

    thumbnail = %{
      timestamp: DateTime.from_unix!(timestamp, :millisecond),
      file: file,
      transmission_uuid: uuid
    }

    [thumbnail | thumbnails]
  end

  defp parse_segment(
         {"#EXTINF:" <> duration_raw, i},
         segments,
         lines,
         uuid,
         base_path
       ) do
    {file, _i} = Enum.at(lines, i + 1)
    [timestamp_raw | _] = String.split(file, ".ts")
    timestamp = String.to_integer(timestamp_raw)
    file = "#{base_path}/#{uuid}/#{file}"

    segment = %{
      duration: trunc((duration_raw |> String.trim(",") |> String.to_float()) * 1000),
      timestamp: DateTime.from_unix!(timestamp, :millisecond),
      file: file,
      transmission_uuid: uuid
    }

    Logger.info("Processing #{file}")
    [segment | segments]
  end

  defp parse_segment(_line, segments, _lines, _, _) do
    segments
  end

  defp enqueue_upsert(segments, :segment),
    do: Enum.each(segments, &UpsertMediaElement.enqueue!(%{type: :segment, attrs: &1}))

  defp enqueue_upsert(thumbnails, :thumbnail),
    do: Enum.each(thumbnails, &UpsertMediaElement.enqueue!(%{type: :thumbnail, attrs: &1}))

  defp base_path(:live), do: "./mnt/hls/live"
  defp base_path(:vod), do: "./mnt/uploads"

  defp get_playlist(base_path, transmission_uuid),
    do: "#{base_path}/#{transmission_uuid}/index.m3u8"

  defp get_thumbnails(base_path, transmission_uuid),
    do: "#{base_path}/#{transmission_uuid}/thumbnails.txt"

  defp rtmp_host, do: System.get_env("RTMP_HOST", "rtmp://localhost:1935")

  defp process_name(transmission),
    do: {:via, Registry, {TransmissionRegistry, transmission.uuid}}
end
