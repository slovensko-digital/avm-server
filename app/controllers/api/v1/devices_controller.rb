class Api::V1::DevicesController < ApiController
  def create
    @device = Device.create!(device_params)
  end

  private

  def device_params
    params.permit(:display_name, :platform, :public_key, :registration_id, :pushkey)
  end
end
