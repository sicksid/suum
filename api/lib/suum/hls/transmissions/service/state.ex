defmodule Suum.Hls.Transmissions.Service.State do
  use Suum.Schema
  alias Suum.Hls.Transmission

  @required [
    :pid
  ]

  @optional [
    :processed_lines
  ]

  embedded_schema do
    embeds_one :transmission, Transmission
    field :pid, :string
    field :processed_lines, {:array, :map}

    timestamps()
  end

  def changeset(state \\ %__MODULE__{}, attrs) do
    state
    |> cast(attrs, @required ++ @optional)
    |> cast_embed(:transmission)
    |> validate_required(@required)
  end

  def put_processed_lines(state, processed_lines) do
    Map.put(state, :processed_lines, processed_lines)
  end
end
