require 'net/http'
require 'net/https'
require 'json'
require 'logger'

require 'batbugger/configuration'
require 'batbugger/backtrace'
require 'batbugger/notice'
require 'batbugger/rack'
require 'batbugger/sender'

require 'batbugger/railtie' if defined?(Rails::Railtie)

module Batbugger
  VERSION = '1.6.0'
  LOG_PREFIX = "** [Batbugger] "

  HEADERS = {
    'Content-type'             => 'application/json',
    'Accept'                   => 'text/json, application/json'
  }

  class << self
    attr_accessor :sender
    attr_writer :configuration

    def report_ready
      write_verbose_log("Notifier #{VERSION} ready to catch errors", :info)
    end

    def report_environment_info
      write_verbose_log("Environment Info: #{environment_info}")
    end

    def report_response_body(response)
      write_verbose_log("Response from Batbugger: \n#{response}")
    end

    def environment_info
      info = "[Ruby: #{RUBY_VERSION}]"
      info << " [#{configuration.framework}]" if configuration.framework
      info << " [Env: #{configuration.environment_name}]" if configuration.environment_name
    end

    def write_verbose_log(message, level = Batbugger.configuration.debug ? :info : :debug)
      logger.send(level, LOG_PREFIX + message) if logger
    end

    def logger
      self.configuration.logger
    end

    def configure(silent = false)
      yield(configuration)
      self.sender = Sender.new(configuration)
      report_ready unless silent
      self.sender
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def notify(exception, options = {})
      send_notice(build_notice_for(exception, options))
    end

    def notify_or_ignore(exception, opts = {})
      notice = build_notice_for(exception, opts)
      send_notice(notice) unless notice.ignore?
    end

    def build_lookup_hash_for(exception, options = {})
      notice = build_notice_for(exception, options)

      result = {}
      result[:action]           = notice.action      rescue nil
      result[:component]        = notice.component   rescue nil
      result[:error_class]      = notice.error_class if notice.error_class
      result[:environment_name] = 'production'

      unless notice.backtrace.lines.empty?
        result[:file]        = notice.backtrace.lines[0].file
        result[:line_number] = notice.backtrace.lines[0].number
      end

      result
    end

    def context(hash = {})
      Thread.current[:batbugger_context] ||= {}
      Thread.current[:batbugger_context].merge!(hash)
      self
    end

    def clear!
      Thread.current[:batbugger_context] = nil
    end

    private

    def send_notice(notice)
      if configuration.public?
        if configuration.async?
          configuration.async.call(notice)
        else
          notice.deliver
        end
      end
    end

    def build_notice_for(exception, opts = {})
      exception = unwrap_exception(exception)
      opts = opts.merge(:exception => exception) if exception.is_a?(Exception)
      opts = opts.merge(exception.to_hash) if exception.respond_to?(:to_hash)
      Notice.new(configuration.merge(opts))
    end

    def unwrap_exception(exception)
      if exception.respond_to?(:original_exception)
        exception.original_exception
      elsif exception.respond_to?(:continued_exception)
        exception.continued_exception
      else
        exception
      end
    end
  end
end
