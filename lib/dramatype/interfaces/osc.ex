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

  defp handle_osc_message({{path, message}}, state) do
    IO.inspect({path, message}, label: "GOT MESSAGE")

    path_parts = String.split(path, "/", trim: true)

    process_message(path_parts, message)

    # profile = String.trim_leading(path, "/")
    # DramaType.Typist.do_typing(%{profile: profile, raw_message: message})

    # Phoenix.PubSub.broadcast(
    #   DramaType.PubSub,
    #   "newtext",
    #   {message}
    # )
    state
  end

  defp process_message([profile], [osc_string: message]) do
    DramaType.Typist.do_typing(%{profile: profile, message: parse_message(message)})
  end

  defp process_message([profile, "config"], [osc_string: config]) do
    config = Jason.decode!(config)
    DramaType.Typist.set_config(%{profile: profile, config: config})
  end

  defp parse_message(raw_message) do
    # split messages into array of individual letters and {commands}
    # e.g. "my {d:12}msg" becomes ["m", "y", " ", {"d", 12}, "m", "s", "g"]
    String.split(raw_message, ~r/{(?<={).*?(?=})}|./, include_captures: true, trim: true)
    |> parse_tokens()
  end

  defp parse_tokens(split_msg) do
    split_msg |> Enum.map(fn m ->
      cond do
        String.length(m) == 1 -> m
        true ->
          m |> String.trim_leading("{") |> String.trim_trailing("}") |> String.split(":", parts: 2) |> List.to_tuple() |> post_process_msg_cmd()
      end
    end)
  end

  # commands with integer values
  defp post_process_msg_cmd({cmd, val}) when cmd in ["bs", "d"] do
    {cmd, String.to_integer(val)}
  end

  defp post_process_msg_cmd(cmd), do: cmd
end
