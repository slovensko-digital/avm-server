class ApplicationController < ActionController::API

  class WrongEncryptionKey < ArgumentError
  end

  rescue_from WrongEncryptionKey do |e|
    render_forbidden
  end

  private

  def render_forbidden
    render status: :forbidden, json: { message: "Forbidden" }
  end
end
