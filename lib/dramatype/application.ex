defmodule DramaType.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      DramaType.Repo,
      # Start the Telemetry supervisor
      DramaTypeWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: DramaType.PubSub},
      # Start the Endpoint (http/https)
      DramaTypeWeb.Endpoint,
      # Start a worker by calling: DramaType.Worker.start_link(arg)
      DramaType.Interfaces.OSC,

      DramaType.TypistSupervisor,
      {Registry, keys: :unique, name: :typistRegistry}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DramaType.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DramaTypeWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
