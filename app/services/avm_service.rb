class AvmService
  def initialize(host: ENV.fetch('AVM_MICROSERVICE_HOST'))
    @host = host
  end

  def new_api
    ::AvmApi.new(host: @host)
  end
end
