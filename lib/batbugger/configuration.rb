module Batbugger
  class Configuration
    OPTIONS = [:api_key, :backtrace_filters, :development_environments, :environment_name,
               :host, :http_open_timeout, :http_read_timeout, :ignore, :ignore_by_filters,
               :ignore_user_agent, :notifier_name, :notifier_url, :notifier_version,
               :params_filters, :project_root, :port, :protocol, :proxy_host, :proxy_pass,
               :proxy_port, :proxy_user, :secure, :use_system_ssl_cert_chain, :framework,
               :user_information, :rescue_rake_exceptions, :source_extract_radius,
               :send_request_session, :debug].freeze

    attr_accessor :api_key

    attr_accessor :host

    attr_accessor :port

    attr_accessor :secure

    attr_accessor :use_system_ssl_cert_chain

    attr_accessor :http_open_timeout

    attr_accessor :http_read_timeout

    attr_accessor :proxy_host

    attr_accessor :proxy_port

    attr_accessor :proxy_user

    attr_accessor :proxy_pass

    attr_reader :params_filters

    attr_reader :backtrace_filters

    attr_reader :ignore_by_filters

    attr_reader :ignore

    attr_reader :ignore_user_agent

    attr_accessor :development_environments

    attr_accessor :environment_name

    attr_accessor :project_root

    attr_accessor :notifier_name

    attr_accessor :notifier_version

    attr_accessor :notifier_url

    attr_accessor :logger

    attr_accessor :user_information

    attr_accessor :framework

    attr_accessor :rescue_rake_exceptions

    attr_accessor :source_extract_radius

    attr_accessor :send_request_session

    attr_accessor :debug

    attr_writer :async

    DEFAULT_PARAMS_FILTERS = %w(password password_confirmation).freeze

    DEFAULT_BACKTRACE_FILTERS = [
      lambda { |line|
        if defined?(Batbugger.configuration.project_root) && Batbugger.configuration.project_root.to_s != ''
          line.sub(/#{Batbugger.configuration.project_root}/, "[PROJECT_ROOT]")
        else
          line
        end
      },
      lambda { |line| line.gsub(/^\.\//, "") },
      lambda { |line|
        if defined?(Gem)
          Gem.path.inject(line) do |line, path|
            line.gsub(/#{path}/, "[GEM_ROOT]")
          end
        end
      },
      lambda { |line| line if line !~ %r{lib/batbugger} }
    ].freeze

    IGNORE_DEFAULT = ['ActiveRecord::RecordNotFound',
                      'ActionController::RoutingError',
                      'ActionController::InvalidAuthenticityToken',
                      'CGI::Session::CookieStore::TamperedWithCookie',
                      'ActionController::UnknownAction',
                      'AbstractController::ActionNotFound',
                      'Mongoid::Errors::DocumentNotFound']

    alias_method :secure?, :secure
    alias_method :use_system_ssl_cert_chain?, :use_system_ssl_cert_chain

    def initialize
      @secure                    = true
      @use_system_ssl_cert_chain = false
      @host                      = 'batbugger.io'
      @http_open_timeout         = 2
      @http_read_timeout         = 5
      @params_filters            = DEFAULT_PARAMS_FILTERS.dup
      @backtrace_filters         = DEFAULT_BACKTRACE_FILTERS.dup
      @ignore_by_filters         = []
      @ignore                    = IGNORE_DEFAULT.dup
      @ignore_user_agent         = []
      @development_environments  = %w(development test cucumber)
      @notifier_name             = 'Batbugger Notifier'
      @notifier_version          = VERSION
      @notifier_url              = 'https://github.com/grepruby/batbugger'
      @framework                 = 'Standalone'
      @user_information          = 'Batbugger Error {{error_id}}'
      @rescue_rake_exceptions    = nil
      @source_extract_radius     = 2
      @send_request_session      = true
      @debug                     = false
    end

    def filter_backtrace(&block)
      self.backtrace_filters << block
    end

    def ignore_by_filter(&block)
      self.ignore_by_filters << block
    end

    def ignore_only=(names)
      @ignore = [names].flatten
    end

    def ignore_user_agent_only=(names)
      @ignore_user_agent = [names].flatten
    end

    def [](option)
      send(option)
    end

    def to_hash
      OPTIONS.inject({}) do |hash, option|
        hash[option.to_sym] = self.send(option)
        hash
      end
    end

    def merge(hash)
      to_hash.merge(hash)
    end

    def public?
      !development_environments.include?(environment_name)
    end

    def async
      @async = Proc.new if block_given?
      @async
    end
    alias :async? :async

    def port
      @port || default_port
    end

    def protocol
      if secure?
        'https'
      else
        'http'
      end
    end

    def ca_bundle_path
      if use_system_ssl_cert_chain? && File.exist?(OpenSSL::X509::DEFAULT_CERT_FILE)
        OpenSSL::X509::DEFAULT_CERT_FILE
      else
        local_cert_path 
      end
    end

    def local_cert_path
      File.expand_path(File.join("..", "..", "..", "resources", "ca-bundle.crt"), __FILE__)
    end

    def current_user_method=(null) ; end

    private

    def default_port
      if secure?
        443
      else
        80
      end
    end
  end
end

