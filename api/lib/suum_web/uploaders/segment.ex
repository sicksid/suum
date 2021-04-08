defmodule Suum.Uploaders.Segment do
  use Waffle.Definition
  use Waffle.Ecto.Definition

  alias Suum.Hls.Segment

  @acl :public_read
  @versions [:original]

  def validate({file, _}) do
    Path.extname(file.file_name) == ".ts"
  end

  def storage_dir(_version, {_file, %Segment{transmission_uuid: transmission_uuid}}),
    do: "/transmissions/#{transmission_uuid}/segments/"

  def storage_dir(_version, {%Waffle.File{path: "./mnt/hls/live/" <> file_path}, _scope}) do
    [transmission_uuid, _file] = String.split(file_path, "/")
    "/transmissions/#{transmission_uuid}/segments"
  end

  def default_url(version, {%Waffle.File{path: "./mnt/hls/live/" <> file_path}, _scope}) do
    [transmission_uuid, _file] = String.split(file_path, "/")
    "/transmissions/#{transmission_uuid}/segments/default-#{version}.ts"
  end

  def default_url(version, {_file, %Segment{transmission_uuid: transmission_uuid}}),
    do: "/transmissions/#{transmission_uuid}/segments/default-#{version}.ts"
end
