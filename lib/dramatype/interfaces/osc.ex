defmodule DramaType.Interfaces.OSC do
  use GenStage
  require Logger

  @initial_state %{}

  def start_link(_) do
    GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(args) do
    inspect(args, label: "ARGS")
    {:consumer, @initial_state, subscribe_to: [ExOsc.MessageBuffer]}
  end

  def handle_events(events, _from, state) do
    inspect("LOL")
    state = Enum.reduce(events, state, fn event, acc -> handle_osc_message(event, acc) end )

    {:noreply, [], state}
  end

  defp handle_osc_message({{path, [osc_string: message]}}, state) do
    IO.inspect({path, message}, label: "GOT MESSAGE")

    profile = String.trim_leading(path, "/")
    DramaType.Typist.do_typing(%{profile: profile, raw_message: message})

    # Phoenix.PubSub.broadcast(
    #   DramaType.PubSub,
    #   "newtext",
    #   {message}
    # )
    state
  end

end
