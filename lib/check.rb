require 'rubygems'
require 'cmd'
require 'datastore'

class Check
  class UrlCheck
    attr_accessor :cookies, :response_time, :response, :data, :status, :location, :error_count

    def initialize(url, cookies, params, &block)
      require 'net/https'
      @exit_on_error = true
      @error_count = 0
      @cookies = cookies || {}
      cookieList = []
      @cookies.each {|key, value| cookieList << "#{key}=#{value}" }
      headers = {}
      headers['Cookie'] = cookieList.join('; ') unless cookieList.length == 0

      uri = URI.parse("#{$baseurl}#{url}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 30
      http.use_ssl  = true if uri.scheme == 'https'
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      req = Net::HTTP::Post.new(uri.path == '' ? '/' : uri.path, headers)
      req.form_data = params

      start = Time.now
      begin
        http.start {
          @response = http.request(req)
          @data = @response.body
          @status = @response.code.to_i
          pattern = Regexp.compile(/(.*?)=(.*?);.*?/)
          @location = @response['Location'] if @status >= 300 and @status < 400
          unless @location.nil?
            @location = "#{uri.scheme}://#{uri.host}:#{uri.port}/#{@location}" if @location.start_with?('/')
          end
          cookie = @response['set-cookie']
          unless cookie.nil?
            cookie.split(/, */).each {|token|
              # TODO: Add support for cookie deletions. This is broken right now
              # since deleted cookies are actually being 'added' instead.
              match = token.match(pattern)
              @cookies["#{match[1]}"] = match[2] unless match.nil?
            }
          end
        }
        finish = Time.now
        @response_time = (finish - start) * 1000

        self.instance_eval(&block)
      rescue Exception => e
        case e
          when Errno::ECONNRESET
            check "Connection Terminated by Server", false
          when Errno::ECONNABORTED
            check "Connection Aborted", false
          when Errno::ETIMEDOUT,Timeout::Error
            check "Timeout establishing connection", false
          else
            check "Error establishing connection: #{e}", false
        end
      end
      Kernel.exit @error_count if @exit_on_error unless @error_count == 0
    end

    def check(message, condition)
      error_count = error_count + 1 unless condition
      status = (condition) ? "Pass" : "Fail"
      $stdout.puts "#{status}\t#{message}"
    end

    def check_cookie_exist(cookie)
      check "Expecting cookie '#{cookie}' to exist", !cookies[cookie].nil?
    end

    def check_cookie_value(cookie, expected_value)
      check "Expecting cookie '#{cookie}' to be '#{expected_value}'", cookies[cookie] == expected_value
    end

    def check_success(duration=nil)
      check "Server responded with status #{status}", status >= 200 && status < 400
      check("Response expected to be under #{duration}ms. Was #{response_time}ms", response_time < duration) unless duration.nil?
    end

    def skip_exit_on_error
      exit_on_error = false
    end
  end

  def self.url(url, cookies={}, params={}, &block)
    UrlCheck.new(url, cookies, params, &block)
  end

  def self.url_redirect(url_check, &block)
    UrlCheck.new(url_check.location, url_check.cookies, {}, &block)
  end
end
