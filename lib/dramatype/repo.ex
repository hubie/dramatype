defmodule DramaType.Repo do
  use Ecto.Repo,
    otp_app: :dramatype,
    adapter: Ecto.Adapters.SQLite3
end
