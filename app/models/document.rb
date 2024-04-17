class Document < ApplicationRecord
  has_one_attached :encrypted_content
  attr_accessor :decrypted_content

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
    filename, mimetype = create_filename_and_mimetype(filename, mimetype)

    if mimetype.include?('base64')
      content = Base64.decode64(content)
    end

    encryptor = ActiveSupport::MessageEncryptor.new(key)
    encrypted_data = encryptor.encrypt_and_sign(Base64.strict_encode64(content))

    encrypted_content.attach(filename: filename, content_type: mimetype, io: StringIO.new(encrypted_data))
  end

  def validate_parameters(content)
    avm_service.validate_parameters(self, content)
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

  def create_filename_and_mimetype(filename, mimetype)
    return [filename, mimetype] if filename && mimetype

    Mime::Type.register("application/vnd.etsi.asic-e+zip", "asice", [], [".sce"])
    Mime::Type.register("application/vnd.etsi.asic-s+zip", "asics", [], [".scs"])
    Mime::Type.register("application/vnd.gov.sk.xmldatacontainer+xml", "xdcf")
    Mime::Type.register("application/msword", "doc")
    Mime::Type.register("application/vnd.openxmlformats-officedocument.wordprocessingml.document", "docx")
    Mime::Type.register("application/vnd.ms-excel", "xls")
    Mime::Type.register("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "xlsx")
    Mime::Type.register("application/vnd.ms-powerpoint", "ppt")
    Mime::Type.register("application/vnd.openxmlformats-officedocument.presentationml.presentation", "pptx")

    unless filename
      filename = 'document' + Mime::Type.lookup(mimetype).symbol.to_s
    else
      mimetype = Mime::Type.lookup_by_extension(File.extname(filename).downcase.gsub('.', '')).to_s
      raise AvmServiceBadRequestError.new("Could not parse mimetype from \"#{filename}\"") if mimetype.empty?
      mimetype += ';base64'
    end

    [filename, mimetype]
  end
end
