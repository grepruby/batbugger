module Batbugger
  class Backtrace

    class Line
      INPUT_FORMAT = %r{^((?:[a-zA-Z]:)?[^:]+):(\d+)(?::in `([^']+)')?$}.freeze

      attr_reader :file

      attr_reader :number

      attr_reader :method

      attr_reader :filtered_file, :filtered_number, :filtered_method

      def self.parse(unparsed_line, opts = {})
        filters = opts[:filters] || []
        filtered_line = filters.inject(unparsed_line) do |line, proc|
          proc.call(line)
        end

        if filtered_line
          _, file, number, method = unparsed_line.match(INPUT_FORMAT).to_a
          _, *filtered_args = filtered_line.match(INPUT_FORMAT).to_a
          new(file, number, method, *filtered_args)
        else
          nil
        end
      end

      def initialize(file, number, method, filtered_file = file,
                     filtered_number = number, filtered_method = method)
        self.filtered_file   = filtered_file
        self.filtered_number = filtered_number
        self.filtered_method = filtered_method
        self.file            = file
        self.number          = number
        self.method          = method
      end

      def to_s
        "#{filtered_file}:#{filtered_number}:in `#{filtered_method}'"
      end

      def ==(other)
        to_s == other.to_s
      end

      def inspect
        "<Line:#{to_s}>"
      end

      def application?
        (filtered_file =~ /^\[PROJECT_ROOT\]/i) && !(filtered_file =~ /^\[PROJECT_ROOT\]\/vendor/i)
      end

      def source(radius = 2)
        @source ||= get_source(file, number, radius)
      end

      private

      attr_writer :file, :number, :method, :filtered_file, :filtered_number, :filtered_method

      def get_source(file, number, radius = 2)
        if file && File.exists?(file)
          before = after = radius
          start = (number.to_i - 1) - before
          start = 0 and before = 1 if start <= 0
          duration = before + 1 + after

          l = 0
          File.open(file) do |f|
            start.times { f.gets ; l += 1 }
            return Hash[duration.times.map { (line = f.gets) ? [(l += 1), line] : nil }.compact]
          end
        else
          {}
        end
      end
    end

    attr_reader :lines, :application_lines

    def self.parse(ruby_backtrace, opts = {})
      ruby_lines = split_multiline_backtrace(ruby_backtrace)

      lines = ruby_lines.collect do |unparsed_line|
        Line.parse(unparsed_line, opts)
      end.compact

      instance = new(lines)
    end

    def initialize(lines)
      self.lines = lines
      self.application_lines = lines.select(&:application?)
    end

    def to_ary
      lines.map { |l| { :number => l.filtered_number, :file => l.filtered_file, :method => l.filtered_method } }
    end
    alias :to_a :to_ary

    def as_json(options = {})
      to_ary
    end

    def to_json(*a)
      as_json.to_json(*a)
    end

    def inspect
      "<Backtrace: " + lines.collect { |line| line.inspect }.join(", ") + ">"
    end

    def ==(other)
      if other.respond_to?(:to_json)
        to_json == other.to_json
      else
        false
      end
    end

    private

    attr_writer :lines, :application_lines

    def self.split_multiline_backtrace(backtrace)
      if backtrace.to_a.size == 1
        backtrace.to_a.first.split(/\n\s*/)
      else
        backtrace
      end
    end
  end
end
