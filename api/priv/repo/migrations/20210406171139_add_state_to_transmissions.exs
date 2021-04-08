defmodule Suum.Repo.Migrations.AddStateToTransmissions do
  use Ecto.Migration

  def change do
    alter table(:transmissions) do
      add :state, :string
    end
  end
end
