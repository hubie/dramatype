defmodule DramaTypeWeb.TypeLive do
  use DramaTypeWeb, :live_view
  alias DramaType.Schema.TypistConfig

  @initial_state %{
    printed_text: "",
    profile: nil,
    config: %TypistConfig{}
  }

  def subscribe(profile: profile) do
    Phoenix.PubSub.subscribe(DramaType.PubSub, profile)
  end


  def mount(%{"configset" => typerProfile} = params, _session, socket) do
    if connected?(socket), do: subscribe(profile: typerProfile)

    inspect(params)
    DramaType.TypistSupervisor.createTypist(typerProfile)

    %{config: config, printed_text: printed_text} = DramaType.Typist.get_current_state(%{profile: typerProfile})

    {:ok, assign(socket, %{@initial_state | profile: typerProfile, config: config, printed_text: printed_text})}
    # {:ok, assign(socket, %{@initial_state | })}
  end


  def handle_info({DramaType.Typist, %{display_text: text_to_print}}, socket) do
    socket = socket
      |> update(:printed_text, fn _ -> text_to_print end)
    {:noreply, socket}
  end

  def handle_info({DramaType.Typist, %{config: %TypistConfig{} = config}}, socket) do
    socket = update(socket, :config, fn _ -> config end)
    {:noreply, socket}
  end

  defp config_to_style(config) do
    Enum.reduce([:font_family, :font_size, :text_area_width, :text_area_height], "", fn config_property, acc ->
      acc <> if( nil != (val = Map.get(config, config_property))) do
        config_prop_to_style(config_property) <> ":" <> val <> ";"
      else
        ""
      end
    end)
  end

  defp config_prop_to_style(config_property) do
    case config_property do
      :text_area_height -> "height"
      :text_area_width -> "width"
      _ ->
        config_property
        |> Atom.to_string()
        |> String.replace("_", "-")
    end
  end

  def render(assigns) do
    ~H"""
      <div class="typist_output" style={config_to_style(@config)}>
        <%= @printed_text %>
      </div>
    """
  end
end
