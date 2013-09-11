module Batbugger
  module Rails
    module Middleware
      module ExceptionsCatcher
        def self.included(base)
          base.send(:alias_method_chain,:render_exception,:batbugger)
        end

        def skip_user_agent?(env)
          user_agent = env["HTTP_USER_AGENT"]
          ::Batbugger.configuration.ignore_user_agent.flatten.any? { |ua| ua === user_agent }
        rescue
          false
        end

        def render_exception_with_batbugger(env,exception)
          controller = env['action_controller.instance']
          env['batbugger.error_id'] = Batbugger.
            notify_or_ignore(exception,
                   (controller.respond_to?(:batbugger_request_data) ? controller.batbugger_request_data : {:rack_env => env})) unless skip_user_agent?(env)
          if defined?(controller.rescue_action_in_public_without_batbugger)
            controller.rescue_action_in_public_without_batbugger(exception)
          end
          render_exception_without_batbugger(env,exception)
        end
      end
    end
  end
end
