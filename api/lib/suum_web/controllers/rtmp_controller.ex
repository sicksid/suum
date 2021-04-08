defmodule SuumWeb.RtmpController do
  use SuumWeb, :controller
  require Logger

  alias Suum.{
    Hls,
    Hls.Jobs,
    Hls.Transmissions.Kickstarter,
    Hls.Transmission
  }

  @spec on_publish(Plug.Conn.t(), map) :: Plug.Conn.t()
  def on_publish(
        conn,
        %{
          "addr" => ip_address,
          "app" => _app,
          "call" => _call,
          "clientid" => _clientid,
          "flashver" => _flashver,
          "name" => transmission_uuid,
          "pageurl" => _pageurl,
          "swfurl" => _swurl,
          "tcurl" => _tcurl,
          "type" => _type
        } = _params
      ) do
    with %Hls.Transmission{} = transmission <- Hls.get_transmission(transmission_uuid),
         {:ok, _} <-
           Hls.update_transmission(transmission, %{
             ip_address: ip_address
           }),
         {:ok, _pid} <- Kickstarter.process(transmission),
         {:ok, _} <- maybe_transition_to_streaming(transmission) do
      send_resp(conn, 200, "")
    end
  end

  @spec on_publish_done(Plug.Conn.t(), map) :: Plug.Conn.t()
  def on_publish_done(
        conn,
        %{"name" => transmission_uuid, "call" => "publish_done"} = _params
      ) do
    Logger.info("Transmission - #{transmission_uuid} finished | creating sprites")

    with %Hls.Transmission{} = transmission <- Hls.get_transmission(transmission_uuid),
         :ok <- Jobs.CreateSprite.enqueue!(transmission_uuid),
         {:ok, _} <- Transmission.transition_to(transmission, "processing") do
      send_resp(conn, 200, "")
    end
  end

  defp maybe_transition_to_streaming(%Transmission{type: :live} = transmission) do
    Transmission.transition_to(transmission, "streaming")
  end

  defp maybe_transition_to_streaming(%Transmission{type: :vod} = transmission),
    do: {:ok, transmission}
end
