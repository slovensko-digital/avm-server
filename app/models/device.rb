class Device < ApplicationRecord
  has_many :devices_integrations
  has_many :integrations, -> { distinct }, through: :devices_integrations

  validates :platform, presence: true
  validates :display_name, presence: true
  validates :registration_id, presence: true
  validates :public_key, presence: true
  validate :public_key_format_should_be_valid


  def notify(integration, document_guid, document_encryption_key)
    # TODO: encrypt notifications
    # encrpyted_message = encrypt_message({
    #     document_guid: document_guid,
    #     key: document_encryption_key
    #   }.to_json,
    #   integration.pushkey
    # )

    encrpyted_message = {
        document_guid: document_guid,
        key: document_encryption_key
      }.to_json

    if ['ios', 'android'].include? platform
      ApiEnvironment.fcm_notifier.notify(registration_id, encrpyted_message)
    elsif ['ntfy'].include? platform
      conn = Faraday.new(url: registration_id) do |f|
        f.headers["X-Actions"] = "view, Sign, https://autogram.slovensko.digital/api/v1/qr-code?guid=#{document_guid}&key=#{CGI.escape document_encryption_key}"
      end

      conn.post
    else
      Rails.logger.warn "Unrecognized device platform: #{platform}"
    end
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

  def encrypt_message(message, key)
    encryptor = ActiveSupport::MessageEncryptor.new(Base64.decode64 key)
    encryptor.encrypt_and_sign(message)
  end
end
