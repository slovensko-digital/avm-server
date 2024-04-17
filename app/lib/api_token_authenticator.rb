# See https://tools.ietf.org/html/rfc7519

class ApiTokenAuthenticator
  MAX_EXP_IN = 150.minutes
  JTI_PATTERN = /\A[0-9a-z\-_]{32,256}\z/i

  def initialize(public_key_reader:, return_handler:)
    @public_key_reader = public_key_reader
    @return_handler = return_handler
  end

  def verify_token(token, expected_aud: nil)
    options = {
      algorithm: 'ES256',
      verify_jti: -> (jti) { jti =~ JTI_PATTERN },
    }

    key_finder = -> (_, payload) do
      puts payload
      @public_key_reader.call(payload['sub'])
    rescue => e
      raise e
      raise JWT::InvalidSubError
    end

    payload, _ = JWT.decode(token, nil, true, options, &key_finder)
    sub, exp, jti, aud = payload['sub'], payload['exp'], payload['jti'], payload['aud']

    raise JWT::ExpiredSignature unless exp.is_a?(Integer)
    raise JWT::InvalidPayload, :jwt_expired if exp > (Time.now + MAX_EXP_IN).to_i
    raise JWT::InvalidPayload, :invalid_aud unless aud == expected_aud
    # raise JWT::InvalidJtiError unless Token.write("#{sub}-#{jti}", '1', expires_in: MAX_EXP_IN, namespace: 'api-token-identifiers')

    @return_handler.call(sub)
  end
end
