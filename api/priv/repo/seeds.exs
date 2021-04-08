import Suum.Factory

root = insert(:user, email: "abdulachik@gmail.com")
_transmission = insert(:transmission, user: root)

# {:ok, pid} =
#   Suum.Hls.Transmissions.Observer.start_link(%{
#     transmission_uuid: transmission.uuid,
#     transmission_base_path: "./fixtures"
#   })

# GenServer.cast(pid, {:process, %{filename: "video.mp4"}})
