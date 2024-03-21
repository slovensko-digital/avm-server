class AvmUnauthorizedError < StandardError
  def initialize(code, message, details)
    @code = code
    @message = message
    @details = details
  end

  def code
    @code
  end

  def message
    @message
  end

  def details
    @details
  end
end
