defmodule Suum.Hls.Transmissions.Kickstarter do
  use DynamicSupervisor
  alias Suum.Hls.Transmissions.Service

  require Logger

  def start_link(arg),
    do: DynamicSupervisor.start_link(__MODULE__, arg, name: __MODULE__)

  def init(_arg),
    do: DynamicSupervisor.init(strategy: :one_for_one)

  def process(transmission) do
    Logger.info("Received message to start transmission #{transmission.uuid}")
    do_process(Registry.lookup(TransmissionRegistry, transmission.uuid), transmission)
  end

  defp do_process([], transmission) do
    Logger.info("Starting process for transmission #{transmission.uuid}")

    DynamicSupervisor.start_child(
      __MODULE__,
      {Service, transmission}
    )
  end

  defp do_process(_, transmission) do
    Logger.warn("Process for transmission #{transmission.uuid} already started")
    {:ok, nil}
  end
end
