class AvmApi
  def initialize(host:)
    @host = host
  end

  def validate_parameters(document, content, mimetype)
    response = Faraday.post(url('/parameters/validate'), {
      document: {
        filename: document.encrypted_content.filename,
        content: content
      },
      parameters: document.parameters,
      payloadMimeType: mimetype
    }.to_json)

    handle_response(response)
  end

  def visualization(document)
    response = Faraday.post(url('/visualization'), {
      document: {
        filename: document.encrypted_content.filename,
        content: document.decrypted_content
      },
      parameters: document.parameters,
      payloadMimeType: document.decrypted_content_mimetype_b64
    }.to_json)

    handle_response(response)

    r = JSON.parse(response.body)
    r['mimeType'] = r['mimeType'].gsub(/ +charset=UTF-8;/, '')
    r
  end

  def datatosign(document, signing_certificate)
    response = Faraday.post(url('/datatosign'), {
      "originalSignRequestBody": {
        document: {
          filename: document.encrypted_content.filename,
          content: document.decrypted_content
        },
        parameters: document.parameters,
        payloadMimeType: document.decrypted_content_mimetype_b64
      },
      "signingCertificate": signing_certificate
    }.to_json)

    handle_response(response)

    JSON.parse(response.body)
  end

  def sign(document, datatosign_structure, signed_data)
    response = Faraday.post(url('/sign'), {
      "originalSignRequestBody": {
        document: {
          filename: document.encrypted_content.filename,
          content: document.decrypted_content
        },
        parameters: document.parameters,
        payloadMimeType: document.decrypted_content_mimetype_b64
      },
      "dataToSignStructure": datatosign_structure,
      "signedData": signed_data
    }.to_json)

    handle_response(response)

    JSON.parse(response.body)
  end

  private

  def url(endpoint)
    "http://#{@host}#{endpoint}"
  end

  def handle_response(response)
    raise AvmServiceInternalError.new(response.body) if response.status >= 500
    raise AvmServiceSignatureNotInTactError.new(response.body) if (response.status == 400 && JSON.parse(response.body)['code'] == 'SIGNATURE_NOT_IN_TACT')
    raise AvmServiceBadRequestError.new(response.body) if response.status >= 400
  end
end
