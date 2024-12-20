class Document < ApplicationRecord
  has_one_attached :encrypted_content
  attr_accessor :decrypted_content

  before_create :set_last_signed_at

  def self.convert_to_b64(mimetype, content, params)
    return [mimetype, content, params] if mimetype.include?('base64')

    params[:schema] = Base64.strict_encode64(params[:schema]) if params[:schema]
    params[:transformation] = Base64.strict_encode64(params[:transformation]) if params[:transformation]

    [mimetype + ';base64', Base64.strict_encode64(content), params]
  end

  def reset_signature_level
    return unless parameters['level']
    parameters['level'] = parameters['level'].gsub(/XAdES_BASELINE_/, '').gsub(/CAdES_BASELINE_/, '')
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

  def signature_validation
    avm_service.validate self
  end

  def signers
    begin
      signature_validation['signatures'].map do |signature|
        {
          signedBy: signature['signingCertificate']['subjectDN'],
          issuedBy: signature['signingCertificate']['issuerDN']
        }
      end
    rescue AvmServiceDocumentNotSignedError
      []
    end
  end

  def visualization
    avm_service.visualization(self)
  end

  def set_add_timestamp
    parameters['level'] = parameters['level'].gsub(/BASELINE_B/, 'BASELINE_T') if parameters['level']
    parameters['level'] = 'T' unless parameters['level'] && parameters['level'] != 'B'
    save!
  end

  def datatosign(signing_certificate)
    avm_service.datatosign(self, signing_certificate)
  end

  def sign(key, data_to_sign, signed_data)
    response = avm_service.sign(self, data_to_sign, signed_data)

    document = response['documentResponse']
    encrypt_file(key, document.dig('filename'), document['mimeType'], document['content'])
    self.last_signed_at = Time.current
    save!

    response['signer']
  end

  private

  def set_last_signed_at
    self.last_signed_at = self.created_at
  end

  def avm_service
    Avm::Environment.avm_api
  end
end
