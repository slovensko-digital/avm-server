class AvmApi
  def initialize(host:)
    @host = host
  end

  def validate_parameters(document, content)
    response = Faraday.post(url('/parameters/validate'), {
      document: {
        filename: document.encrypted_content.filename,
        content: content
      },
      parameters: document.parameters,
      payloadMimeType: document.decrypted_content_mimetype_b64
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

    JSON.parse(response.body)
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
    raise AvmServiceBadRequestError.new(response.body) if response.status >= 400
  end
end
