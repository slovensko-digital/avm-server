class Api::V1::SignRequestsController < ApiController
  before_action :set_integration

  def create
    @integration.notify_devices(params.require(:document_guid), params.require(:document_encryption_key))
  end

  private

  def set_integration
    @integration = ApiEnvironment.integration_token_authenticator.verify_token(authenticity_token)
  end
end
