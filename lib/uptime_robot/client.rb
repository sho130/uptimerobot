class UptimeRobot::Client
  ENDPOINT = 'http://api.uptimerobot.com'

  METHODS = {
    :get_account_details => :getAccountDetails,
  }

  DEFAULT_ADAPTERS = [
    Faraday::Adapter::NetHttp,
    Faraday::Adapter::Test
  ]

  def initialize(options)
    @api_key = options.delete(:api_key)

    raise ':api_key is required' unless @api_key

    options[:url] ||= ENDPOINT

    @conn = Faraday.new(options) do |faraday|
      faraday.request  :url_encoded
      faraday.response :json, :content_type => /\bjson$/
      faraday.response :raise_error

      yield(faraday) if block_given?

      unless DEFAULT_ADAPTERS.any? {|i| faraday.builder.handlers.include?(i) }
        faraday.adapter Faraday.default_adapter
      end
    end
  end

  private

  def method_missing(method_name, *args, &block)
    ur_method = METHODS[method_name]

    raise NoMethodError, "undefined method: #{method_name}" unless ur_method

    len = args.length
    params = args.first

    unless len.zero? or (len == 1 and params.kind_of?(Hash))
      raise ArgumentError, "invalid argument: #{args}"
    end

    request(ur_method, params || {}, &block)
  end

  def request(method_name, params = {})
    params.update(
      :apiKey => @api_key,
      :format => 'json',
      :noJsonCallback => 1
    )

    response = @conn.get do |req|
      req.url "/#{method_name}"
      req.params = params
      yield(req) if block_given?
    end

    json = response.body

    if json['stat'] != 'ok'
      raise UptimeRobot::Error.new(json)
    end

    json.delete('stat')
    json.values.first
  end
end
