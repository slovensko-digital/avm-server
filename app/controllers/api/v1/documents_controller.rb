class Api::V1::DocumentsController < ApplicationController
  before_action :set_document, only: %i[ show datatosign sign visualization destroy signature_level ]
  before_action :set_key, only: %i[ show create datatosign sign visualization ]
  before_action :decrypt_document_content, only: %i[ show sign datatosign visualization destroy]

  # GET /documents/1
  def show
    modified_since = request.headers.to_h['HTTP_IF_MODIFIED_SINCE']

    if modified_since && Time.zone.parse(modified_since) >= @document.updated_at
      response.set_header('Last-Modified', @document.created_at + 1.seconds)
      render json: nil, status: 304
    end
    @signers = @document.signers
  end

  # POST /documents
  def create
    p = document_params
    filename, mimetype = create_filename_and_mimetype(p[:document][:filename], p[:payload_mime_type])

    @document = Document.new(parameters: p[:parameters])
    @document.encrypt_file(@key, filename, mimetype, p[:document][:content])
    @document.validate_parameters(p[:document][:content], mimetype)

    unless @document.save
      render json: @document.errors, status: :unprocessable_entity
    else
      response.set_header('Last-Modified', @document.created_at + 1.seconds)
    end
  end

  # POST /documents/1/visualization
  def visualization
    @visualization = @document.visualization
  end

  # POST /documents/1/datatosign
  def datatosign
    @document.set_add_timestamp if datatosign_params[:add_timestamp]
    @signing_certificate = datatosign_params.require(:signing_certificate)
    @result = @document.datatosign(@signing_certificate)
  end

  # POST /documents/1/sign
  def sign
    @signer = @document.sign(@key, sign_params[:data_to_sign_structure], sign_params[:signed_data])
    render json: @document.errors, status: :unprocessable_entity unless @signer

    @document = Document.find(params[:id])
    decrypt_document_content
  end

  # DELETE /documents/1
  def destroy
    @document.destroy!
  end

  # GET /documents/1/signature-level
  def signature_level
    puts @document.parameters
    @level = @document.parameters.fetch("level", nil)
  end

  private
    def set_document
      @document = Document.find(params[:id])
    end

    def set_key
      key_b64 = request.headers.to_h['HTTP_X_ENCRYPTION_KEY'] || params[:encryption_key]
      begin
        begin
          # AVM app somehow sends urlsafe base64 even if its source code doesn't seem so
          @key = Base64.urlsafe_decode64(key_b64)
        rescue ArgumentError
          @key = Base64.strict_decode64(key_b64)
        end
      rescue => e
        raise AvmUnauthorizedError.new("ENCRYPTION_KEY_MALFORMED", "Encryption key Base64 decryption failed.", e.message)
      end

      raise AvmUnauthorizedError.new("ENCRYPTION_KEY_MISSING", "Encryption key not provided.", "Encryption key must be provided either in X-Encryption-Key header or as encryptionKey query parameter.") unless @key
      raise AvmUnauthorizedError.new("ENCRYPTION_KEY_MALFORMED", "Encryption key invalid.", "Encryption key must be a base64 string encoding 32 bytes long key.") unless validate_key(@key)
    end

    def validate_key(key)
      key.length == 32
    end

    def decrypt_document_content
      @document.decrypt_content(@key)
    end

    def document_params
      params.require(:parameters)
      d = params.require(:document)
      d.require(:content)
      params.permit(
        :encryption_key,
        :payload_mime_type,
        :document => [:filename, :content],
        :parameters => [
          :checkPDFACompliance,
          :autoLoadEform,
          :level,
          :container,
          :containerXmlns,
          :embedUsedSchemas,
          :identifier,
          :packaging,
          :digestAlgorithm,
          :en319132,
          :infoCanonicalization,
          :propertiesCanonicalization,
          :keyInfoCanonicalization,
          :schema,
          :schemaIdentifier,
          :transformation,
          :transformationIdentifier,
          :transformationLanguage,
          :transformationMediaDestinationTypeDescription,
          :transformationTargetEnvironment
        ]
      )
    end

    def datatosign_params
      params.permit(:encryption_key, :id, :signing_certificate, :add_timestamp)
    end

    def sign_params
      params.require(:signed_data)
      dts = params.require(:data_to_sign_structure)
      dts.require(:dataToSign)
      dts.require(:signingTime)
      dts.require(:signingCertificate)

      params.permit(:encryption_key, :id, :signed_data, :return_signed_document, :data_to_sign_structure => [:dataToSign, :signingTime, :signingCertificate])
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
        filename = 'document.' + Mime::Type.lookup(mimetype).symbol.to_s
      else
        mimetype = Mime::Type.lookup_by_extension(File.extname(filename).downcase.gsub('.', '')).to_s
        raise AvmServiceBadRequestError.new({code: "FAILED_PARSING_MIMETYPE", message: "Could not parse mimetype", details: "Could not parse mimetype from: #{filename}"}.to_json) if mimetype.empty?
        mimetype += ';base64'
      end

      [filename, mimetype]
    end
end
