defmodule Suum.Uploaders.Image do
  use Waffle.Definition
  use Waffle.Ecto.Definition
  alias Suum.Hls.{Thumbnail, Transmission}

  @versions [:original]

  # To add a thumbnail version:
  # @versions [:original, :thumb]

  # Override the bucket on a per definition basis:
  # def bucket do
  #   :custom_bucket_name
  # end

  # Whitelist file extensions:
  def validate({file, _}) do
    ~w(.jpg .jpeg .gif .png) |> Enum.member?(Path.extname(file.file_name))
  end

  # Define a thumbnail transformation:
  # def transform(:thumb, _) do
  #   {:convert, "-strip -thumbnail 250x250^ -gravity center -extent 250x250 -format png", :png}
  # end

  # Override the persisted filenames:
  # def filename(version, _) do
  #   version
  # end

  # Override the storage directory:
  # def storage_dir(version, {file, scope}) do
  #   "uploads/user/avatars/#{scope.id}"
  # end

  # Provide a default URL if there hasn't been a file uploaded
  # def default_url(version, scope) do
  #   "/images/avatars/default_#{version}.png"
  # end

  # Specify custom headers for s3 objects
  # Available options are [:cache_control, :content_disposition,
  #    :content_encoding, :content_length, :content_type,
  #    :expect, :expires, :storage_class, :website_redirect_location]
  #
  # def s3_object_headers(version, {file, scope}) do
  #   [content_type: MIME.from_path(file.file_name)]
  # end

  def storage_dir(_version, {_file, %Thumbnail{transmission_uuid: transmission_uuid}}),
    do: "/transmissions/#{transmission_uuid}/thumbnails/"

  def storage_dir(_version, {%Waffle.File{path: "./mnt/hls/live/" <> file_path}, _scope}) do
    [transmission_uuid, _file] = String.split(file_path, "/")
    "/transmissions/#{transmission_uuid}/thumbnails/"
  end

  def storage_dir(_version, {%Waffle.File{path: "./mnt/uploads/" <> file_path}, _scope}) do
    [transmission_uuid, _file] = String.split(file_path, "/")
    "/transmissions/#{transmission_uuid}/thumbnails/"
  end

  def default_url(version, {%Waffle.File{path: "./mnt/hls/live/" <> file_path}, _scope}) do
    [transmission_uuid, _file] = String.split(file_path, "/")
    "/transmissions/#{transmission_uuid}/thumbnails/#{version}-default.jpeg"
  end

  def storage_dir(_version, {_file, %Transmission{uuid: transmission_uuid}}),
    do: "/transmissions/#{transmission_uuid}/thumbnails/"

  def storage_dir(_version, {%Waffle.File{path: "./mnt/hls/live/" <> file_path}, _scope}) do
    [transmission_uuid, _file] = String.split(file_path, "/")
    "/transmissions/#{transmission_uuid}/"
  end

  def default_url(version, {%Waffle.File{path: "./mnt/hls/live/" <> file_path}, _scope}) do
    [transmission_uuid, _file] = String.split(file_path, "/")
    "/transmissions/#{transmission_uuid}/#{version}-default.png"
  end

  def storage_dir(_version, {%Waffle.File{path: "./mnt/uploads/" <> file_path}, _scope}) do
    [transmission_uuid, _file] = String.split(file_path, "/")
    "/transmissions/#{transmission_uuid}/"
  end

  def default_url(version, {%Waffle.File{path: "./mnt/uploads/" <> file_path}, _scope}) do
    [transmission_uuid, _file] = String.split(file_path, "/")
    "/transmissions/#{transmission_uuid}/#{version}-default.png"
  end

  def default_url(version, %Transmission{uuid: transmission_uuid}),
    do: "/transmissions/#{transmission_uuid}/#{version}-default.png"

  def default_url(version, {%Waffle.File{path: "./mnt/uploads/" <> file_path}, _scope}) do
    [transmission_uuid, _file] = String.split(file_path, "/")
    "/transmissions/#{transmission_uuid}/thumbnails/#{version}-default.jpeg"
  end

  def default_url(version, {_file, %Thumbnail{transmission_uuid: transmission_uuid}}),
    do: "/transmissions/#{transmission_uuid}/thumbnails/#{version}-default.jpeg"
end
