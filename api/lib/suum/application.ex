defmodule Suum.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  alias Suum.Hls.Transmissions.{Service, Kickstarter}

  def start(_type, _args) do
    children = [
      Suum.Repo,
      SuumWeb.Telemetry,
      {Phoenix.PubSub, name: Suum.PubSub},
      SuumWeb.Endpoint,
      {Registry, keys: :unique, name: TransmissionRegistry},
      Kickstarter
    ]

    opts = [strategy: :one_for_one, name: Suum.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    SuumWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
