defmodule SuumWeb.TransmitChannel do
  use Phoenix.Channel
  require Logger

  @impl true
  def join("transmit:" <> transmission_uuid, _message, socket) do
    {:ok,
     assign(socket,
       transmission_uuid: transmission_uuid,
       porcelain_process: spawn_ffmpeg(transmission_uuid)
     )}
  end

  @impl true
  def terminate(reason, %{assigns: %{porcelain_process: porcelain_process}} = _socket)
      when not is_nil(porcelain_process) do
    Logger.error("Exited #{inspect(reason)}")
    :exec.kill(porcelain_process, 0)
  end

  def terminate(reason, _) do
    Logger.error("Exited #{inspect(reason)}")
    :ok
  end

  @impl true
  def handle_in(
        "segment",
        %{"data" => "data:video/x-matroska;codecs=avc1,opus;base64," <> data},
        %{assigns: %{porcelain_process: porcelain_process}} = socket
      )
      when not is_nil(porcelain_process) and not is_nil(data) do
    :ok = :exec.send(porcelain_process, Base.decode64!(data))
    {:noreply, socket}
  end

  def handle_in(
        "segment",
        %{"data" => "data:video/webm;codecs=vp8;base64," <> data},
        %{assigns: %{porcelain_process: porcelain_process}} = socket
      ) do
    :ok = :exec.send(porcelain_process, Base.decode64!(data))
    {:noreply, socket}
  end

  def handle_in(
        "segment",
        _params,
        socket
      ) do
    Logger.warn("couldnt process segment")
    {:noreply, socket}
  end

  defp spawn_ffmpeg(transmission_uuid) do
    command = ~w(
      /usr/local/bin/ffmpeg
      -i pipe:0
      -hide_banner
      -loglevel fatal
      -stats
      -fflags nobuffer
      -rtsp_transport tcp
      -preset ultrafast
      -c:a copy
      -c:v copy
      -f flv
      #{rtmp_host()}/live/#{transmission_uuid}
    )

    {:ok, pid, _os_pid} = :exec.run_link(command, [:stdin, {:stderr, self()}, :monitor])

    pid
  end

  @impl true
  def handle_info({:stderr, os_pid, message}, state) do
    Logger.error("#{os_pid} - #{message}")
    {:noreply, state}
  end

  def handle_info({:stdout, os_pid, message}, state) do
    Logger.error("#{inspect(os_pid)} - #{inspect(message)}")
    {:noreply, state}
  end

  def handle_info(request, state) do
    Logger.error("#{inspect(request, pretty: true)}")
    {:noreply, state}
  end

  defp rtmp_host, do: System.get_env("RTMP_HOST", "rtmp://localhost:1935")
end
