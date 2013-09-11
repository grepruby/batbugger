module Batbugger
  # Middleware for Rack applications. Any errors raised by the upstream
  # application will be delivered to Batbugger and re-raised.
  #
  # Synopsis:
  #
  #   require 'rack'
  #   require 'batbugger'
  #
  #   Batbugger.configure do |config|
  #     config.api_key = 'my_api_key'
  #   end
  #
  #   app = Rack::Builder.app do
  #     run lambda { |env| raise "Rack down" }
  #   end
  #
  #   use Batbugger::Rack
  #   run app
  #
  # Use a standard Batbugger.configure call to configure your api key.
  class Rack
    def initialize(app)
      @app = app
    end

    def ignored_user_agent?(env)
      true if Batbugger.
        configuration.
        ignore_user_agent.
        flatten.
        any? { |ua| ua === env['HTTP_USER_AGENT'] }
    end

    def notify_batbugger(exception,env)
      Batbugger.notify_or_ignore(exception, :rack_env => env) unless ignored_user_agent?(env)
    end

    def call(env)
      begin
        response = @app.call(env)
      rescue Exception => raised
        env['batbugger.error_id'] = notify_batbugger(raised, env)
        raise
      ensure
        Batbugger.context.clear!
      end

      framework_exception = env['rack.exception'] || env['sinatra.error']
      if framework_exception
        env['batbugger.error_id'] = notify_batbugger(framework_exception, env)
      end

      response
    end
  end
end
