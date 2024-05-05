class Document < ApplicationRecord
  has_one_attached :encrypted_content
  attr_accessor :decrypted_content

  def self.convert_to_b64(mimetype, content, params)
    return [mimetype, content, params] if mimetype.include?('base64')

    params[:schema] = Base64.strict_encode64(params[:schema]) if params[:schema]
    params[:transformation] = Base64.strict_encode64(params[:transformation]) if params[:transformation]

    [mimetype + ';base64', Base64.strict_encode64(content), params]
  end

  def decrypt_content(key)
    decryptor = ActiveSupport::MessageEncryptor.new(key)
    begin
      @decrypted_content = decryptor.decrypt_and_verify(encrypted_content.download)
    rescue ActiveSupport::MessageEncryptor::InvalidMessage => e
      raise AvmBadEncryptionKeyError.new
    end
  end

  def decrypted_content_mimetype_b64
    encrypted_content.content_type + ';base64'
  end

  def encrypt_file(key, filename, mimetype, content)
    encryptor = ActiveSupport::MessageEncryptor.new(key)
    encrypted_data = encryptor.encrypt_and_sign(Base64.strict_encode64(Base64.decode64(content)))

    encrypted_content.attach(filename: filename, content_type: mimetype, io: StringIO.new(encrypted_data))
  end

  def validate_parameters(content, mimetype)
    avm_service.validate_parameters(self, content, mimetype)
  end

  def signers
    [
      {
        "signedBy": "SERIALNUMBER=PNOSK-1234567890, C=SK, L=Bratislava, SURNAME=Smith, GIVENNAME=John, CN=John Smith",
        "issuedBy": "CN=SVK eID ACA2, O=Disig a.s., OID.2.5.4.97=NTRSK-12345678, L=Bratislava, C=SK"
      }
    ]
  end

  def visualization
    avm_service.visualization(self)
  end

  def set_add_timestamp
    parameters['level'] = parameters['level'].gsub(/BASELINE_B/, 'BASELINE_T')
    save!
  end

  def datatosign(signing_certificate)
    avm_service.datatosign(self, signing_certificate)
  end

  def sign(key, data_to_sign, signed_data)
    response = avm_service.sign(self, data_to_sign, signed_data)

    document = response['documentResponse']
    encrypt_file(key, document.dig('filename'), document['mimeType'], document['content'])

    response['signer']
  end

  private

  def avm_service
    Avm::Environment.avm_api
  end
end
