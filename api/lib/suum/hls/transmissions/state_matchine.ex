defmodule Suum.Hls.Transmissions.StateMachine do
  alias Suum.Hls
  require Logger

  use Machinery,
    states: ["created", "streaming", "uploading", "processing", "ready", "error"],
    transitions: %{
      "created" => ["streaming", "uploading"],
      "uploading" => "streaming",
      "streaming" => "processing",
      "processing" => "ready",
      "*" => "error"
    }

  def persist(transmission, next_state) do
    {:ok, transmission} = Hls.update_transmission(transmission, %{state: next_state})
    transmission
  end

  def log_transition(transmission, next_state) do
    Logger.info("Transmission #{transmission.uuid} - #{transmission.state} => #{next_state}")
    transmission
  end

  def guard_transition(transmission, _state), do: transmission

  def before_transition(transmission, state) do
    Logger.info("#{transmission.state} - #{state}")
    transmission
  end

  # def before_transition(transmission, _state), do: transmission

  def after_transition(transmission, "uploading") do
    Logger.info("uploading #{transmission.uuid}")

    GenServer.cast(
      pid(transmission.uuid),
      {:uploading, [transmission: transmission]}
    )
  end

  def after_transition(transmission, "processing") do
    Logger.info("processing #{transmission.uuid}")

    GenServer.cast(
      pid(transmission.uuid),
      {:processing, [transmission: transmission]}
    )
  end

  def after_transition(transmission, "streaming") do
    Logger.info("streaming #{transmission.uuid}")

    GenServer.cast(
      pid(transmission.uuid),
      {:streaming, [transmission: transmission]}
    )
  end

  def after_transition(transmission, _state), do: transmission

  defp pid(uuid), do: get_from_registry(Registry.lookup(TransmissionRegistry, uuid))

  defp get_from_registry([{pid, _}]), do: pid
  defp get_from_registry([]), do: nil
end
