defmodule Suum.Repo.Migrations.AddUploadNameContentTypeUidToTransmissions do
  use Ecto.Migration

  def change do
    alter table(:transmissions) do
      add :upload_name, :string
      add :content_type, :string
      add :uid, :uuid
    end
  end
end
