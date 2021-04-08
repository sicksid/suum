defmodule Suum.Schema do
  defmacro __using__(_) do
    quote do
      use Ecto.Schema
      import Ecto.Changeset
      import Crudry.Query
      import Ecto.Query
      import EctoEnum
      import Slugy

      @primary_key {:uuid, :binary_id, autogenerate: true}
      @type t :: %__MODULE__{}
      @foreign_key_type :binary_id
      @derive {Phoenix.Param, key: :uuid}
    end
  end
end
