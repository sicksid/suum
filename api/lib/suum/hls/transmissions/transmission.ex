defmodule Suum.Hls.Transmission do
  use Suum.Schema
  use Waffle.Ecto.Schema

  require Logger
  alias Suum.{Accounts.User, Hls.Segment, Hls.Transmissions.StateMachine, Uploaders}

  @required [
    :name,
    :user_uuid,
    :slug
  ]

  @optional [
    :type,
    :ip_address,
    :state,
    :upload_name,
    :content_type,
    :uid
  ]

  defenum(Type, ["live", "vod"])

  schema "transmissions" do
    field(:name, :string)
    field(:slug, :string)
    field :ip_address, :string
    field(:sprite, Suum.Uploaders.Sprite.Type)
    field(:preview, Suum.Uploaders.Preview.Type)

    field(:sprite_url, :string, virtual: true)
    field(:preview_url, :string, virtual: true)
    field :type, Type, default: :live
    field :state, :string, default: "created"

    field :upload_name, :string
    field :content_type, :string
    field :uid, Ecto.UUID

    belongs_to :user, User,
      foreign_key: :user_uuid,
      references: :uuid

    has_many(:segments, Segment)
    timestamps()
  end

  @spec set_sprite(%{:sprite => any, optional(any) => any}) :: %{
          :sprite => any,
          :sprite_url => any,
          optional(any) => any
        }
  def set_sprite(transmission),
    do:
      Map.put(
        transmission,
        :sprite_url,
        Uploaders.Sprite.url({transmission.sprite, transmission}, :original, signed: true)
      )

  def set_preview(transmission),
    do:
      Map.put(
        transmission,
        :preview_url,
        Uploaders.Preview.url({transmission.preview, transmission}, :original, signed: true)
      )

  def set_upload(
        transmission,
        %{
          upload_name: upload_name,
          content_type: content_type,
          uid: uid
        } = params
      )
      when not is_nil(upload_name) and not is_nil(content_type) and not is_nil(uid) do
    Map.merge(transmission, params)
  end

  def changeset(transmission, attrs) do
    transmission
    |> cast(attrs, @required ++ @optional)
    |> slugify(:name)
    |> validate_required(@required)
    |> cast_attachments(attrs, [:sprite, :preview])
    |> foreign_key_constraint(:user_uuid)
  end

  @spec transition_to(t(), State.t()) :: {:ok, t()} | {:error, String.t()}
  def transition_to(transmission, state),
    do: Machinery.transition_to(transmission, StateMachine, state)
end
