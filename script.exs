host = if app = System.get_env("FLY_APP_NAME"), do: "#{app}.fly.dev", else: "localhost"

Application.put_env(:sample, SamplePhoenix.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  server: true,
  live_view: [signing_salt: "nfjkh289fhwehflh430feljgh4h5ghrgvxc988nk"],
  secret_key_base: String.duplicate("a", 64),
  pubsub_server: SamplePhoenix.PubSub
)

Mix.install([
  {:plug_cowboy, "~> 2.5"},
  {:jason, "~> 1.0"},
  {:phoenix, "~> 1.7.1", override: true},
  {:phoenix_live_view, "~> 0.18.17"}
])

defmodule BroadCasting do
  def broadcast(event) do
    Phoenix.PubSub.broadcast(SamplePhoenix.PubSub, "counter", event)
    {:ok}
  end

  def subscribe do
    Phoenix.PubSub.subscribe(SamplePhoenix.PubSub, "counter")
  end
end

defmodule SamplePhoenix.ErrorView do
  def render(template, _), do: Phoenix.Controller.status_message_from_template(template)
end

defmodule SamplePhoenix.SampleLive do
  use Phoenix.LiveView, layout: {__MODULE__, :live}

  def mount(_params, _session, socket) do
    if connected?(socket), do: Broadcasting.subscribe()
    {:ok, assign(socket, :count, 0)}
  end

  def handle_info(:increment, socket) do
    {:noreply, assign(socket, :count, socket.assigns.count + 1)}
  end

  def handle_info(:decrement, socket) do
    {:noreply, assign(socket, :count, socket.assigns.count - 1)}
  end

  def render("live.html", assigns) do
    ~H"""
    <script src="https://cdn.jsdelivr.net/npm/phoenix@1.7.0-rc.2/priv/static/phoenix.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/phoenix_live_view@0.18.2/priv/static/phoenix_live_view.min.js"></script>
    <script>
      let liveSocket = new window.LiveView.LiveSocket("/live", window.Phoenix.Socket)
      liveSocket.connect()
    </script>
    <style>
      * { font-size: 1.1em; }
    </style>

    """
  end

  def render(assigns) do
    ~H"""

    <button phx-click="inc">+</button>
    <button phx-click="dec">-</button>
    """
  end

  def handle_event("inc", _params, socket) do
    BroadCasting.broadcast(:increment)
    {:noreply, socket}
  end

  def handle_event("dec", _params, socket) do
    BroadCasting.broadcast(:decrement)
    {:noreply, socket}
  end
end

defmodule Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:accepts, ["html"])
  end

  scope "/", SamplePhoenix do
    pipe_through(:browser)

    live("/", SampleLive, :index)
  end
end

defmodule SamplePhoenix.Endpoint do
  use Phoenix.Endpoint, otp_app: :sample
  socket("/live", Phoenix.LiveView.Socket)
  plug(Router)
end

if System.get_env("EXS_DRY_RUN") == "true" do
  System.halt(0)
else
  {:ok, _} =
    Supervisor.start_link(
      [
        {Phoenix.PubSub, name: SamplePhoenix.PubSub},
        SamplePhoenix.Endpoint
      ],
      strategy: :one_for_one
    )

  Process.sleep(:infinity)
end
