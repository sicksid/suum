defmodule SuumWeb.Api.Resolvers.Hls do
  require Crudry.Resolver
  require Logger
  alias Suum.Hls.{Transmissions, Segments, Thumbnails}
  alias Suum.Hls.{Transmission, Segment, Thumbnail}

  Crudry.Resolver.generate_functions(Transmissions, Transmission)
  Crudry.Resolver.generate_functions(Segments, Segment)
  Crudry.Resolver.generate_functions(Thumbnails, Thumbnail)

  def create_transmission(_args, params, %{context: %{current_user: user}}) do
    params
    |> Map.put(:user_uuid, user.uuid)
    |> Transmissions.create_transmission()
  end

  def update_transmission(_args, %{params: params, uuid: uuid}, %{context: %{current_user: _user}}) do
    transmission = Transmissions.get_transmission!(uuid)
    Transmissions.update_transmission(transmission, params)
  end

  def get_transmission(_args, %{uuid: uuid}, _) do
    {:ok, Transmissions.get_transmission(uuid)}
  end

  def get_transmission(_args, %{slug: slug}, _) do
    case Transmissions.get_transmission_by!(slug: slug) do
      {:error, reason} ->
        Logger.error(inspect(reason))

      transmission ->
        {:ok, transmission}
    end
  end
end
