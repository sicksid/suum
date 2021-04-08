# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :suum,
  ecto_repos: [Suum.Repo],
  bucket_name: System.get_env("AWS_BUCKET_NAME", "suum"),
  base_url: System.get_env("BASE_URL", "http://localhost:4000")

config :suum, Suum.Repo, migration_primary_key: [type: :uuid]

# Configures the endpoint
config :suum, SuumWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Krj5HpQToTdm/InnItlYF+K8qO9kdwmMotLFG0/9rpzd/EUn9AqqPlyX7BQ945Um",
  render_errors: [view: SuumWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Suum.PubSub,
  live_view: [signing_salt: "OHdMvegK"]

config :ex_aws,
  access_key_id: System.get_env("AWS_ACCESS_KEY_ID", "local_access"),
  secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY", "local_access"),
  region: System.get_env("AWS_REGION", "local")

config :ex_aws, :s3,
  host: System.get_env("AWS_HOST", "127.0.0.1"),
  port: System.get_env("AWS_PORT", "9000"),
  region: System.get_env("AWS_REGION", "local"),
  scheme: System.get_env("AWS_SCHEME", "http://")

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :suum, Suum.Guardian,
  issuer: "suum",
  secret_key:
    System.get_env(
      "SECRET_KEY",
      "2m9Vl9d1P/XiaRc8mSvhwB3GzYXmRkxLWyt+bUIoafypZTG+JDTJmkM2F1zG9OHX9Rs="
    ),
  ttl: {3, :days}

config :suum, SuumWeb.AuthAccessPipeline,
  module: Suum.Guardian,
  error_handler: SuumWeb.AuthErrorHandler

config :waffle,
  storage: Waffle.Storage.S3,
  bucket: System.get_env("AWS_BUCKET_NAME", "suum"),
  asset_host: System.get_env("MINIO_HOST", "http://localhost:9000/suum")

# If using S3:
config :ex_aws,
  json_codec: Jason,
  access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
  secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY"),
  region: System.get_env("AWS_REGION")

config :ex_aws, :s3,
  host: System.get_env("AWS_HOST", "127.0.0.1"),
  port: System.get_env("AWS_PORT", "9000"),
  region: System.get_env("AWS_REGION", "local"),
  scheme: System.get_env("AWS_SCHEME", "http://")

config :suum, Suum.Mailer,
  adapter: Bamboo.MandrillAdapter,
  api_key: "my_api_key"

config :kaffy,
  otp_app: :suum,
  ecto_repo: Suum.Repo,
  router: SuumWeb.Router

config :task_bunny,
  hosts: [
    default: [
      connect_options: [
        username: System.get_env("RABBITMQ_DEFAULT_USER", "local_access"),
        password: System.get_env("RABBITMQ_DEFAULT_PASSWORD", "local_access")
      ]
    ]
  ]

config :task_bunny,
  queue: [
    namespace: "task_bunny.",
    queues: [[name: "normal", jobs: :default]]
  ]

config :tus, controllers: [SuumWeb.UploadController]

config :tus, SuumWeb.UploadController,
  s3_host: System.get_env("AWS_HOST", "127.0.0.1"),
  s3_bucket: System.get_env("AWS_BUCKET_NAME", "suum"),
  storage: Tus.Storage.Local,
  base_path: "mnt/uploads/",
  cache: Tus.Cache.Memory,
  max_size: 20_971_520

config :porcelain, goon_warn_if_missing: false

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
