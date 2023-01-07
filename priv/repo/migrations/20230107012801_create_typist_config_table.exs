defmodule DramaType.Repo.Migrations.CreateTypistConfigTable do
  use Ecto.Migration

  def change do
    create table(:typist_config) do
      add :profile, :string, null: false
      add :font_family, :string
      add :font_size, :string
      add :text_area_width, :string
      add :text_area_height, :string

      timestamps()
    end

    create unique_index(:typist_config, [:profile])
  end

end
