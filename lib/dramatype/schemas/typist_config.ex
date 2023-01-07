defmodule DramaType.Schema.TypistConfig do
  use Ecto.Schema
  import Ecto.Changeset

  schema "typist_config" do
    field :profile,           :string
    field :font_family,       :string
    field :font_size,         :string
    field :text_area_width,   :string
    field :text_area_height,  :string

    timestamps()
  end

  @doc false
  def changeset(config, attrs \\ %{}) do
    config
    |> cast(attrs, [:profile, :font_family, :font_size, :text_area_width, :text_area_height])
    |> unique_constraint(:profile)
  end
end
