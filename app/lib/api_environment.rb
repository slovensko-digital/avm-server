module ApiEnvironment
  extend self

  def integration_token_authenticator
    @integration_token_authenticator ||= ApiTokenAuthenticator.new(
      public_key_reader: -> (sub) { OpenSSL::PKey::EC.new(Integration.find(sub).public_key) },
      return_handler: -> (sub) { Integration.find(sub) }
    )
  end

  def device_token_authenticator
    @device_token_authenticator ||= ApiTokenAuthenticator.new(
      public_key_reader: -> (sub) { OpenSSL::PKey::EC.new(Device.find(sub).public_key) },
      return_handler: -> (sub) { Device.find(sub) }
    )
  end

  def fcm_notifier
    @fcm_notifier ||= FcmNotifer.new
  end
end
