class DevicesIntegration < ApplicationRecord
  belongs_to :device
  belongs_to :integration
  validates :device, uniqueness: {scope: :integration, message: 'integration pair already exists'}
end
