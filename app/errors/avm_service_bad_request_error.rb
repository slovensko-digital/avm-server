class AvmServiceBadRequestError < StandardError
  def initialize(body_str)
    @message = body_str
  end

  def message
    @message
  end
end
