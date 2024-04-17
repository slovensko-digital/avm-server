class Integration < ApplicationRecord
  has_many :devices_integrations
  has_many :devices, -> { distinct }, through: :devices_integrations

  encrypts :pushkey

  validates :platform, presence: true
  validates :display_name, presence: true
  validates :public_key, presence: true
  validates :pushkey, presence: true
  validate :public_key_format_should_be_valid


  def notify_devices(document_guid, document_encryption_key)
    devices.each { |d| d.notify(self, document_guid, document_encryption_key) }
  end

  private

  def public_key_format_should_be_valid
    begin
      OpenSSL::PKey::EC.new(public_key)
    rescue OpenSSL::PKey::ECError => e
      errors.add(:public_key, e.message)
    end
  end

  def pushkey_format_should_be_vakud
    begin
      key = nil
      begin
        key = Base64.urlsafe_decode64(pushkey)
      rescue ArgumentError
        key = Base64.strict_decode64(pushkey)
      end

      errors.add(:pushkey, "aes256 key must be 32 bytes long") unless key.length == 32
    rescue => e
      errors.add(:pushkey, e.message)
    end

  end
end
