defmodule DramaType.Typist do
  use GenServer, restart: :transient

  @initial_state %{
    typer_profile: nil,
    printed_text: "",
    unprocessed_msg: [],
    active_timer: nil
  }

  def start_link(typerProfile) do
    IO.inspect(typerProfile, label: "PROFILE")
    GenServer.start_link(__MODULE__, typerProfile, name: process_name(typerProfile))
  end

  defp process_name(typerProfile),
    do: {:via, Registry, {:typistRegistry, typerProfile}}


  def init(profile) do
    state = %{@initial_state | typer_profile: profile}
    {:ok, state}
  end

  def do_typing(%{profile: profile, raw_message: raw_message}) do
    parsed_msg = parse_message(raw_message)
    IO.inspect(parsed_msg, label: "Got message to type out")

    GenServer.call(process_name(profile), {:process_message, unprocessed_msg: parsed_msg})
  end

  def handle_call({:process_message, unprocessed_msg: msg}, _from, state) do
    send(self(), {:process_message})
    {:reply, {:ok}, %{state | unprocessed_msg: msg}}
  end


  # delay
  def handle_info({:process_message}, %{unprocessed_msg: [{"d", val} | tail]} = state) do
    {:ok, active_timer} = :timer.send_after(val, self(), {:process_message})

    {:noreply, %{state | unprocessed_msg: tail, active_timer: active_timer}}
    # {:noreply, assign(socket, active_timer: active_timer, unprocessed_msg: tail)}
    # process_message(tail, socket)
  end

  def handle_info({:process_message}, %{unprocessed_msg: [{"clear"} | tail]} = state) do
    send(self(), {:process_message})
    {:noreply, %{state | printed_text: "", unprocessed_msg: tail, active_timer: nil}}
  end

  # backspace
  def handle_info({:process_message}, %{unprocessed_msg: [{"bs"} | tail]} = state) do
    handle_info({:process_message}, %{state | unprocessed_msg: [{"bs", get_type_delay()} | tail]})
  end

  def handle_info({:process_message}, %{unprocessed_msg: [{"bs", val} | tail], printed_text: printed_text, typer_profile: profile} = state) do
    printed_text = printed_text |> String.slice(0..-2//1)

    {:ok, active_timer} = :timer.send_after(val, self(), {:process_message})

    Phoenix.PubSub.broadcast(DramaType.PubSub, profile, {__MODULE__, %{display_text: printed_text}})
    {:noreply, %{state | unprocessed_msg: tail, printed_text: printed_text, active_timer: active_timer}}
  end

  def handle_info({:process_message}, %{unprocessed_msg: [char | tail], printed_text: printed_text, typer_profile: profile} = state) do
    text_to_print = printed_text <> char
    IO.inspect(text_to_print, label: to_string(__MODULE__) <> " text to print")

    Phoenix.PubSub.broadcast(DramaType.PubSub, profile, {__MODULE__, %{display_text: text_to_print}})

    {:ok, active_timer} = :timer.send_after(get_type_delay(), self(), {:process_message})

    {:noreply, %{state | active_timer: active_timer, unprocessed_msg: tail, printed_text: text_to_print}}
  end


  def handle_info({:process_message}, %{unprocessed_msg: []} = state) do
    IO.inspect("DONE!")
    {:noreply, state}
    # {:stop, :normal, state}
  end

  def handle_info(msg, state) do
    IO.inspect(msg, label: "unhandled msg")
    {:noreply, state}
  end

  defp get_type_delay() do
    :rand.normal(167, 3000) |> round()
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
          m |> String.trim_leading("{") |> String.trim_trailing("}") |> String.split(":", parts: 2) |> List.to_tuple() |> post_process_cmd()
      end
    end)
  end

  defp post_process_cmd({"bs", val}) do
    {"bs", String.to_integer(val)}
  end

  defp post_process_cmd({"d", val}) do
    {"d", String.to_integer(val)}
  end

  defp post_process_cmd(cmd) do
    cmd
  end
end
