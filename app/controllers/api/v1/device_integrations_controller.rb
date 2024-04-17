class Api::V1::DeviceIntegrationsController < ApiController
  before_action :set_device

  def create
    integration = ApiEnvironment.integration_token_authenticator.verify_token(params.require(:integration_pairing_token), expected_aud: 'device')
    @device.integrations << integration

    head 204
  end

  def index
    @integrations = @device.integrations
  end

  def destroy
    @device.integrations.delete(Integration.find(params.require(:id)))
    head 204
  end

  private

  def set_device
    @device = ApiEnvironment.device_token_authenticator.verify_token(authenticity_token)
  end
end
