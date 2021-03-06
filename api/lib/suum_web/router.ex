defmodule SuumWeb.Router do
  use SuumWeb, :router
  # , scope: "/admin", pipe_through: [:some_plug, :authenticate]
  use Kaffy.Routes

  import SuumWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_authenticated do
    plug SuumWeb.AuthAccessPipeline
  end

  pipeline :graphql do
    plug SuumWeb.Context
  end

  scope "/api" do
    pipe_through :graphql

    forward "/", Absinthe.Plug, schema: SuumWeb.Schema
  end

  scope "/", SuumWeb do
    pipe_through :browser

    get "/", PageController, :index
  end

  scope "/", SuumWeb do
    post "/on_publish", RtmpController, :on_publish
    post "/on_publish_done", RtmpController, :on_publish_done

    scope "/upload" do
      options "/", UploadController, :options
      match :head, "/:uid", UploadController, :head
      post "/", UploadController, :post
      patch "/:uid", UploadController, :patch
      delete "/:uid", UploadController, :delete
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", SuumWeb do
  #   pipe_through :api
  # end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: SuumWeb.Telemetry
    end
  end

  ## Authentication routes
  scope "/", SuumWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated, :put_session_layout]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
    get "/users/log_in", UserSessionController, :new
    post "/users/log_in", UserSessionController, :create
    get "/users/reset_password", UserResetPasswordController, :new
    post "/users/reset_password", UserResetPasswordController, :create
    get "/users/reset_password/:token", UserResetPasswordController, :edit
    put "/users/reset_password/:token", UserResetPasswordController, :update
  end

  scope "/", SuumWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm_email/:token", UserSettingsController, :confirm_email
    put "/users/settings/update_avatar", UserSettingsController, :update_avatar
  end

  scope "/", SuumWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete
    get "/users/confirm", UserConfirmationController, :new
    post "/users/confirm", UserConfirmationController, :create
    get "/users/confirm/:token", UserConfirmationController, :confirm

    get "/transmissions/:uuid/index.m3u8", TransmissionController, :vod
    get "/transmissions/:uuid/thumbnails.vtt", TransmissionController, :thumbnails
  end

  if Mix.env() == :dev do
    forward "/sent_emails", Bamboo.SentEmailViewerPlug
  end

  if Mix.env() == :dev do
    forward "/graphiql", Absinthe.Plug.GraphiQL, schema: SuumWeb.Schema
  end
end
