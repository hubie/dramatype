defmodule DramaTypeWeb.TypeLive do
  use DramaTypeWeb, :live_view

  @initial_state %{
    printed_text: "",
    profile: nil
  }

  def subscribe(profile: profile) do
    Phoenix.PubSub.subscribe(DramaType.PubSub, profile)
  end


  def mount(%{"configset" => typerProfile} = params, _session, socket) do
    if connected?(socket), do: subscribe(profile: typerProfile)

    inspect(params)
    DramaType.TypistSupervisor.createTypist(typerProfile)

    {:ok, assign(socket, %{@initial_state | profile: typerProfile})}
    # {:ok, assign(socket, %{@initial_state | })}
  end


  def handle_info({DramaType.Typist, %{display_text: text_to_print}}, socket) do
    socket = socket
      |> update(:printed_text, fn _ -> text_to_print end)
    {:noreply, socket}
  end





  def render(assigns) do
    ~H"""
      <div class="typist_output">
        <%= @printed_text %>
      </div>
    """
  end
end
