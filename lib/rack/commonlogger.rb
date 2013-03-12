require 'rack/body_proxy'
require 'logger'

module Rack
  # Rack::CommonLogger forwards every request to the given +app+, and
  # logs a line in the
  # {Apache common log format}[http://httpd.apache.org/docs/1.3/logs.html#common]
  # to the +logger+.
  #
  # If +logger+ is nil, CommonLogger will fall back +rack.errors+, which is
  # an instance of Rack::NullLogger.
  #
  # +logger+ can be any class, including the standard library Logger, and is
  # expected to have a +write+ method, which accepts the CommonLogger::FORMAT.
  # If +logger" is an instance of the standard library Logger, CommonLogger will
  # use the underlying IO device, bypassing any "level" settings.
  # According to the SPEC, the error stream must also respond to +puts+
  # (which takes a single argument that responds to +to_s+), and +flush+
  # (which is called without arguments in order to make the error appear for
  # sure)
  class CommonLogger
    # Common Log Format: http://httpd.apache.org/docs/1.3/logs.html#common
    #
    #   lilith.local - - [07/Aug/2006 23:58:02] "GET / HTTP/1.1" 500 -
    #
    #   %{%s - %s [%s] "%s %s%s %s" %d %s\n} %
    FORMAT = %{%s - %s [%s] "%s %s%s %s" %d %s %0.4f\n}

    def initialize(app, logger=nil)
      @app = app
      @logger = logger
      @logger = @logger.instance_variable_get(:@logdev) if ::Logger === @logger
    end

    def call(env)
      began_at = Time.now
      status, header, body = @app.call(env)
      header = Utils::HeaderHash.new(header)
      body = BodyProxy.new(body) { log(env, status, header, began_at) }
      [status, header, body]
    end

    private

    def log(env, status, header, began_at)
      now = Time.now
      length = extract_content_length(header)

      logger = @logger || env['rack.errors']
      logger.write FORMAT % [
        env['HTTP_X_FORWARDED_FOR'] || env["REMOTE_ADDR"] || "-",
        env["REMOTE_USER"] || "-",
        now.strftime("%d/%b/%Y %H:%M:%S"),
        env["REQUEST_METHOD"],
        env["PATH_INFO"],
        env["QUERY_STRING"].empty? ? "" : "?"+env["QUERY_STRING"],
        env["HTTP_VERSION"],
        status.to_s[0..3],
        length,
        now - began_at ]
    end

    def extract_content_length(headers)
      value = headers['Content-Length'] or return '-'
      value.to_s == '0' ? '-' : value
    end
  end
end
