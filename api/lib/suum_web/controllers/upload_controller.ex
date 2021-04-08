defmodule SuumWeb.UploadController do
  # @transmissions_base_path "./mnt/uploads"

  use Tus.Controller
  use SuumWeb, :controller
  require Logger

  alias Suum.{
    Hls,
    Hls.Transmissions.Kickstarter,
    Hls.Transmission
  }

  def on_begin_upload(%Tus.File{
        metadata: [
          {"name", filename},
          {"type", filetype},
          {"transmission_uuid", transmission_uuid}
        ],
        uid: uid
      }) do
    with %Hls.Transmission{} = transmission <- Hls.get_transmission(transmission_uuid),
         {:ok, _transmission} <-
           Hls.update_transmission(transmission, %{
             upload_name: filename,
             content_type: filetype,
             uid: uid
           }),
         {:ok, _pid} <- Kickstarter.process(transmission),
         {:ok, _transmission} <- Transmission.transition_to(transmission, "uploading") do
      :ok
    else
      error ->
        Logger.error(inspect(error, pretty: true))
        error
    end
  end

  def on_complete_upload(%Tus.File{
        metadata: [
          {"name", _filename},
          {"type", _filetype},
          {"transmission_uuid", transmission_uuid}
        ]
      }) do
    with %Hls.Transmission{} = transmission <- Hls.get_transmission(transmission_uuid),
         {:ok, _transmission} <- Transmission.transition_to(transmission, "streaming") do
      :ok
    else
      error ->
        Logger.error(inspect(error, pretty: true))
        error
    end
  end
end
