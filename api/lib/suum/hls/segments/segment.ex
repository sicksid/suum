defmodule Suum.Hls.Segment do
  alias Suum.{Hls.Transmission, Uploaders}

  use Suum.Schema
  use Waffle.Ecto.Schema

  @required [
    :file,
    :timestamp,
    :duration,
    :transmission_uuid
  ]

  @optional []

  schema "segments" do
    field(:file, Suum.Uploaders.Segment.Type)
    field(:timestamp, :utc_datetime)
    field(:duration, :integer)

    belongs_to(:transmission, Transmission,
      foreign_key: :transmission_uuid,
      references: :uuid,
      primary_key: true
    )

    field(:duration_sec, :float, virtual: true)
    field(:url, :string, virtual: true)

    timestamps()
  end

  def changeset(segment, attrs) do
    segment
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> cast_attachments(attrs, [:file])
    |> foreign_key_constraint(:transmission_uuid)
    |> unique_constraint(:slug)
  end

  def set_url(segment),
    do:
      Map.put(
        segment,
        :url,
        Uploaders.Segment.url({segment.file, segment}, :original, signed: true)
      )

  def set_duration_sec(segment),
    do: Map.put(segment, :duration_sec, segment.duration / 1000)
end
