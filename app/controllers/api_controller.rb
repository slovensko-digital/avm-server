class ApiController < ApplicationController
  rescue_from JWT::DecodeError do |error|
    if error.message == 'Nil JSON web token'
      render_bad_request(RuntimeError.new(:no_credentials))
    else
      render_unauthorized(error.message)
    end
  end

  private

  def authenticity_token
    (ActionController::HttpAuthentication::Token.token_and_options(request)&.first || params[:token])&.squish.presence
  end
end
