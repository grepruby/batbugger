require 'socket'

module Batbugger
  class Notice
    attr_reader :exception

    attr_reader :backtrace

    attr_reader :error_class

    attr_reader :source_extract

    attr_reader :source_extract_radius

    attr_reader :environment_name

    attr_reader :cgi_data

    attr_reader :error_message

    attr_reader :send_request_session

    attr_reader :backtrace_filters

    attr_reader :params_filters

    attr_reader :parameters
    alias_method :params, :parameters

    attr_reader :component
    alias_method :controller, :component

    attr_reader :action

    attr_reader :session_data

    attr_reader :context

    attr_reader :project_root

    attr_reader :url

    attr_reader :ignore

    attr_reader :ignore_by_filters

    attr_reader :notifier_name

    attr_reader :notifier_version

    attr_reader :notifier_url

    attr_reader :hostname

    def initialize(args)
      self.args         = args
      self.exception    = args[:exception]
      self.project_root = args[:project_root]
      self.url          = args[:url] || rack_env(:url)

      self.notifier_name    = args[:notifier_name]
      self.notifier_version = args[:notifier_version]
      self.notifier_url     = args[:notifier_url]

      self.ignore              = args[:ignore]              || []
      self.ignore_by_filters   = args[:ignore_by_filters]   || []
      self.backtrace_filters   = args[:backtrace_filters]   || []
      self.params_filters      = args[:params_filters]      || []
      self.parameters          = args[:parameters] ||
                                   action_dispatch_params ||
                                   rack_env(:params) ||
                                   {}
      self.component           = args[:component] || args[:controller] || parameters['controller']
      self.action              = args[:action] || parameters['action']

      self.environment_name = args[:environment_name]
      self.cgi_data         = args[:cgi_data] || args[:rack_env]
      self.backtrace        = Backtrace.parse(exception_attribute(:backtrace, caller), :filters => self.backtrace_filters)
      self.error_class      = exception_attribute(:error_class) {|exception| exception.class.name }
      self.error_message    = exception_attribute(:error_message, 'Notification') do |exception|
        "#{exception.class.name}: #{exception.message}"
      end

      self.hostname         = local_hostname

      self.source_extract_radius = args[:source_extract_radius] || 2
      self.source_extract        = extract_source_from_backtrace

      self.send_request_session     = args[:send_request_session].nil? ? true : args[:send_request_session]

      also_use_rack_params_filters
      find_session_data
      clean_params
      clean_rack_request_data
      set_context
    end

    def deliver
      Batbugger.sender.send_to_batbugger(self)
    end

    def as_json(options = {})
      {
        :notifier => {
          :name => notifier_name,
          :url => notifier_url,
          :version => notifier_version,
          :language => 'ruby'
        },
        :error => {
          :class => error_class,
          :message => error_message,
          :backtrace => backtrace,
          :source => source_extract
        },
        :request => {
          :url => url,
          :component => component,
          :action => action,
          :params => parameters,
          :session => session_data,
          :cgi_data => cgi_data,
          :context => context
        },
        :server => {
          :project_root => project_root,
          :environment_name => environment_name,
          :hostname => hostname
        }
      }
    end

    def to_json(*a)
      as_json.to_json(*a)
    end

    def ignore_by_class?(ignored_class = nil)
      @ignore_by_class ||= Proc.new do |ignored_class|
        case error_class
        when (ignored_class.respond_to?(:name) ? ignored_class.name : ignored_class)
          true
        else
          exception && ignored_class.is_a?(Class) && exception.class < ignored_class
        end
      end

      ignored_class ? @ignore_by_class.call(ignored_class) : @ignore_by_class
    end

    def ignore?
      ignore.any?(&ignore_by_class?) ||
        ignore_by_filters.any? {|filter| filter.call(self) }
    end

    def [](method)
      case method
      when :request
        self
      else
        send(method)
      end
    end

    private

    attr_writer :exception, :backtrace, :error_class, :error_message,
      :backtrace_filters, :parameters, :params_filters, :environment_filters,
      :session_data, :project_root, :url, :ignore, :ignore_by_filters,
      :notifier_name, :notifier_url, :notifier_version, :component, :action,
      :cgi_data, :environment_name, :hostname, :context, :source_extract,
      :source_extract_radius, :send_request_session

    attr_accessor :args

    def exception_attribute(attribute, default = nil, &block)
      (exception && from_exception(attribute, &block)) || args[attribute] || default
    end

    def from_exception(attribute)
      if block_given?
        yield(exception)
      else
        exception.send(attribute)
      end
    end

    def clean_unserializable_data_from(attribute)
      self.send(:"#{attribute}=", clean_unserializable_data(send(attribute)))
    end

    def clean_unserializable_data(data, stack = [])
      return "[possible infinite recursion halted]" if stack.any?{|item| item == data.object_id }

      if data.respond_to?(:to_hash)
        data.to_hash.inject({}) do |result, (key, value)|
          result.merge(key => clean_unserializable_data(value, stack + [data.object_id]))
        end
      elsif data.respond_to?(:to_ary)
        data.to_ary.collect do |value|
          clean_unserializable_data(value, stack + [data.object_id])
        end
      else
        data.to_s
      end
    end

    def clean_params
      clean_unserializable_data_from(:parameters)
      filter(parameters)
      if cgi_data
        clean_unserializable_data_from(:cgi_data)
        filter(cgi_data)
      end
      if session_data
        clean_unserializable_data_from(:session_data)
        filter(session_data)
      end
    end

    def clean_rack_request_data
      if cgi_data
        cgi_data.delete("rack.request.form_vars")
      end
    end

    def extract_source_from_backtrace
      if backtrace.lines.empty?
        nil
      else
        if exception.respond_to?(:source_extract)
          Hash[exception_attribute(:source_extract).split("\n").map do |line|
            parts = line.split(': ')
            [parts[0].strip, parts[1] || '']
          end]
        elsif backtrace.application_lines.any?
          backtrace.application_lines.first.source(source_extract_radius)
        else
          backtrace.lines.first.source(source_extract_radius)
        end
      end
    end

    def filter(hash)
      if params_filters
        hash.each do |key, value|
          if filter_key?(key)
            hash[key] = "[FILTERED]"
          elsif value.respond_to?(:to_hash)
            filter(hash[key])
          end
        end
      end
    end

    def filter_key?(key)
      params_filters.any? do |filter|
        key.to_s.eql?(filter.to_s)
      end
    end

    def find_session_data
      if send_request_session
        self.session_data = args[:session_data] || args[:session] || rack_session || {}
        self.session_data = session_data[:data] if session_data[:data]
      end
    end

    def set_context
      self.context = Thread.current[:batbugger_context] || {}
      self.context.merge!(args[:context]) if args[:context]
      self.context = nil if context.empty?
    end

    def rack_env(method)
      rack_request.send(method) if rack_request
    end

    def rack_request
      @rack_request ||= if args[:rack_env]
        ::Rack::Request.new(args[:rack_env])
      end
    end

    def action_dispatch_params
      args[:rack_env]['action_dispatch.request.parameters'] if args[:rack_env]
    end

    def rack_session
      args[:rack_env]['rack.session'] if args[:rack_env]
    end

    # Private: (Rails 3+) Adds params filters to filter list
    #
    # Returns nothing
    def also_use_rack_params_filters
      if cgi_data
        @params_filters ||= []
        @params_filters += cgi_data['action_dispatch.parameter_filter'] || []
      end
    end

    def local_hostname
      Socket.gethostname
    end
  end
end
