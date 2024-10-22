require_relative "boot"

require "rails/all"
require "active_storage/engine"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

if ['development', 'test'].include? ENV['RAILS_ENV']
  Dotenv::Rails.load
end

module AutogramServer
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w(assets tasks))

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    config.exceptions_app = self.routes

    Rails.application.config.generators { |g| g.orm :active_record, primary_key_type: :uuid }
    Rails.application.config.filter_parameters += [
      :encryption_key, :document, :parameters, :signing_certificate, :signed_data, :data_to_sign_structure, :registration_id, :pushkey
    ]

    config.active_record.encryption.primary_key = ENV['ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY']
    config.active_record.encryption.deterministic_key = ENV['ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY']
    config.active_record.encryption.key_derivation_salt = ENV['ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT']

    config.active_job.queue_adapter = :good_job
    config.good_job.max_threads = 2
    config.good_job.execution_mode = :async
    config.good_job.enable_cron = true

    config.good_job.cron = {
      delete_expired_documents: {
        cron: "*/15 * * * *",
        class: "DeleteExpiredDocumentsJob",
        set: {priority: -5}
      },
      delete_expired_tokens: {
        cron: "*/15 * * * *",
        class: "DeleteExpiredTokensJob",
        set: {priority: -10}
      }
    }

  end
end
