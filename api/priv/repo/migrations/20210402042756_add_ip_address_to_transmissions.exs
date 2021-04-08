defmodule Suum.Repo.Migrations.AddIpAddressToTransmissions do
  use Ecto.Migration

  def change do
    alter table(:transmissions) do
      add :ip_address, :string
    end
  end
end
