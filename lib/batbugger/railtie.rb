require 'batbugger'
require 'rails'

module Batbugger
  class Railtie < Rails::Railtie
    initializer "batbugger.use_rack_middleware" do |app|
      app.config.middleware.insert 0, "Batbugger::Rack"
    end

    config.after_initialize do
      Batbugger.configure(true) do |config|
        config.logger           ||= ::Rails.logger
        config.environment_name ||= ::Rails.env
        config.project_root     ||= ::Rails.root
        config.framework        = "Rails: #{::Rails::VERSION::STRING}"
      end

      ActiveSupport.on_load(:action_controller) do
        require 'batbugger/rails/controller_methods'

        include Batbugger::Rails::ControllerMethods
      end

      if defined?(::ActionDispatch::DebugExceptions)
        require 'batbugger/rails/middleware/exceptions_catcher'
        ::ActionDispatch::DebugExceptions.send(:include,Batbugger::Rails::Middleware::ExceptionsCatcher)
      elsif defined?(::ActionDispatch::ShowExceptions)
        require 'batbugger/rails/middleware/exceptions_catcher'
        ::ActionDispatch::ShowExceptions.send(:include,Batbugger::Rails::Middleware::ExceptionsCatcher)
      end
    end
  end
end
