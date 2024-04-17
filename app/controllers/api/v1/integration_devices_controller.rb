class Api::V1::IntegrationDevicesController < ApiController
  before_action :set_integration

  def index
    @devices = @integration.devices
  end

  def destroy
    @integration.devices.delete(Device.find(params.require(:id)))
    render :head
  end

  private

  def set_integration
    @integration = ApiEnvironment.integration_token_authenticator.verify_token(authenticity_token)
  end
end
