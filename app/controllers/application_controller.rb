class ApplicationController < ActionController::API
  rescue_from ActionController::ParameterMissing do |e|
    render json: {
      code: "PARAMETER_MISSING",
      message: "Required parameter is missing.",
      details: e.message
    }, status: 400
  end

  rescue_from AvmServiceBadRequestError do |e|
    render json: JSON.parse(e.message), status: 422
  end

  rescue_from AvmServiceInternalError do |e|
    render json: JSON.parse(e.message), status: 502
  end

  rescue_from AvmUnauthorizedError do |e|
    render json: {
      code: e.code,
      message: e.message,
      details: e.details
    }, status: 401
  end

  rescue_from AvmBadEncryptionKeyError do |e|
    render json: {
      code: "ENCRYPTION_KEY_MISMATCH",
      message: "Encryption key mismatch.",
      details: "Provided encryption key failed to decrypt document."
    }, status: 403
  end
end
