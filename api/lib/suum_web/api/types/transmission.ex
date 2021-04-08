defmodule SuumWeb.Api.Types.Transmission do
  use Absinthe.Schema.Notation
  import Absinthe.Resolution.Helpers, only: [dataloader: 1]
  alias Suum.{Accounts, Hls}

  object :transmission do
    field(:uuid, :id)
    field(:user, :user, resolve: dataloader(Accounts))

    field(:name, :string)
    field(:slug, :string)
    field(:type, :string)
    field(:ip_address, :string)
    field(:pid, :string)
    field :state, :string
    field(:segments, list_of(:segment), resolve: dataloader(Hls))
    field(:sprite, :string)
    field(:sprite_url, :string)

    field :preview, :string do
      resolve(fn
        %{preview: nil}, _, _ ->
          {:ok, Faker.Avatar.image_url()}

        %{preview: preview}, _, _ ->
          {:ok, preview}
      end)
    end

    field(:preview_url, :string)
  end
end
