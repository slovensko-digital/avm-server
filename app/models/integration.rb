class Integration < ApplicationRecord
  has_many :devices_integrations
  has_many :devices, -> { distinct }, through: :devices_integrations

  validates :platform, presence: true
  validates :display_name, presence: true
  validates :public_key, presence: true
  validate :public_key_format_should_be_valid


  def notify_devices(document_guid, document_encryption_key)
    devices.each { |d| d.notify(document_guid, document_encryption_key) }
  end

  private

  def public_key_format_should_be_valid
    begin
      begin
        OpenSSL::PKey::EC.new(public_key)
      rescue
        OpenSSL::PKey::EC.new("-----BEGIN PUBLIC KEY-----\n#{public_key}\n-----END PUBLIC KEY-----")
      end
    rescue OpenSSL::PKey::ECError => e
      errors.add(:public_key, e.message)
    end
  end
end
