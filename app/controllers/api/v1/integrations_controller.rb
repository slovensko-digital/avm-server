class Api::V1::IntegrationsController < ApiController
  def create
    @integration = Integration.create!(integration_params)
  end

  private

  def integration_params
    params.permit(:display_name, :platform, :public_key, :pushkey)
  end
end
