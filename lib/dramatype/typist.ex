defmodule DramaType.Typist do
  use GenServer, restart: :transient
  alias DramaType.Schema.TypistConfig

  @initial_state %{
    typer_profile: nil,
    printed_text: "",
    unprocessed_msg: [],
    active_timer: nil,
    config: %{}
  }

  def start_link(typerProfile) do
    IO.inspect(typerProfile, label: "PROFILE")
    GenServer.start_link(__MODULE__, typerProfile, name: process_name(typerProfile))
  end

  defp process_name(typerProfile),
    do: {:via, Registry, {:typistRegistry, typerProfile}}


  def init(profile) do
    config = get_config(%{profile: profile})
    state = %{@initial_state | typer_profile: profile, config: config}
    {:ok, state}
  end

  defp get_config(%{profile: profile}) do
    case DramaType.Repo.get_by(TypistConfig, profile: profile) do
      nil -> %TypistConfig{profile: profile}
      config -> config
    end
  end

  def set_config(%{profile: profile, config: config}) do
    {:ok, struct} = get_config(%{profile: profile})
      |> TypistConfig.changeset(config)
      |> DramaType.Repo.insert_or_update()

    IO.inspect(struct, label: "INSERTED")
    Phoenix.PubSub.broadcast(DramaType.PubSub, profile, {__MODULE__, %{config: struct}})
  end

  def get_current_state(%{profile: profile} = args) do
    %{config: get_config(args), printed_text: GenServer.call(process_name(profile), {:get_printed_text})}
  end


  def do_typing(%{profile: profile, message: parsed_msg}) do
    IO.inspect(parsed_msg, label: "Got message to type out")

    GenServer.call(process_name(profile), {:process_message, unprocessed_msg: parsed_msg})
  end


  def handle_call({:get_printed_text}, _from, %{printed_text: printed_text} = state) do
    {:reply, printed_text, state}
  end

  def handle_call({:process_message, unprocessed_msg: msg}, _from, state) do
    IO.inspect("handling first message")
    send(self(), {:process_message})
    {:reply, {:ok}, %{state | unprocessed_msg: msg}}
  end

  def handle_info({:process_message}, %{unprocessed_msg: [msg | tail], typer_profile: profile} = state) when length(tail) == 0 do
    IO.inspect("Last one")
    state = case process_message(msg, state) do
      %{delay: _, new_text: new_text} ->
        send_new_text(profile, new_text)
        %{state | printed_text: new_text}
      _ ->
        state
    end

    {:noreply, %{state | active_timer: nil, unprocessed_msg: []}}
  end

  def handle_info({:process_message}, %{unprocessed_msg: [msg | tail], typer_profile: profile} = state) do
    result = process_message(msg, state)

    state = case result do
      %{new_text: new_text} ->
        send_new_text(profile, new_text)
        %{state | printed_text: new_text}
      _ ->
        state
    end

    IO.inspect(result.delay, label: "Delay")

    active_timer = Process.send_after(self(), {:process_message}, result.delay)
    {:noreply, %{state | active_timer: active_timer, unprocessed_msg: tail}}
  end

  def handle_info(msg, state) do
    IO.inspect(msg, label: "unhandled msg")
    {:noreply, state}
  end

  defp send_new_text(profile, new_text) do
    Phoenix.PubSub.broadcast(DramaType.PubSub, profile, {__MODULE__, %{display_text: new_text}})
  end


  # delay
  defp process_message({"d", delay_ms}, _state) do
    %{delay: delay_ms}
  end

  defp process_message({"clear"}, _state) do
    %{delay: 0, new_text: ""}
  end

  defp process_message({"nl"}, %{printed_text: printed_text} = _state) do
    %{delay: get_type_delay(), new_text: printed_text <> "<br/>"}
  end

  # backspace
  defp process_message({"bs"}, state) do
    process_message({"bs", get_type_delay()}, state)
  end

  # backspace, with delay
  defp process_message({"bs", delay_ms}, %{printed_text: printed_text} = _state) do
    printed_text = printed_text |> String.slice(0..-2//1)
    %{delay: delay_ms, new_text: printed_text}
  end

  defp process_message(char, %{printed_text: printed_text} = _state) do
    %{delay: get_type_delay(), new_text: printed_text <> char}
  end

  defp get_type_delay() do
    :rand.normal(167, 3000) |> round() |> max(20)
  end
end
