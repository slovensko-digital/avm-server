class Api::V1::DocumentsController < ApplicationController
  before_action :set_document, only: %i[ show datatosign sign visualization destroy ]
  before_action :set_key, only: %i[ show create datatosign sign visualization ]
  before_action :decrypt_document_content, only: %i[ show sign datatosign visualization destroy]

  # GET /documents/1
  def show
    @signers = @document.signers
  end

  # POST /documents
  def create
    p = document_params
    @document = Document.new(parameters: p[:parameters])
    @document.encrypt_file(@key, p[:document][:filename], p[:payloadMimeType], p[:document][:content])
    @document.validate_parameters(p[:document][:content])

    render json: @document.errors, status: :unprocessable_entity unless @document.save
  end

  # POST /documents/1/visualization
  def visualization
    @visualization = @document.visualization
  end

  # POST /documents/1/datatosign
  def datatosign
    @document.set_add_timestamp if datatosign_params[:addTimestamp]
    @signing_certificate = datatosign_params.require(:signingCertificate)
    @result = @document.datatosign(@signing_certificate)
  end

  # POST /documents/1/sign
  def sign
    @signer = @document.sign(@key, sign_params[:dataToSignStructure], sign_params[:signedData])
    render json: @document.errors, status: :unprocessable_entity unless @signer

    @document = Document.find(params[:id])
    decrypt_document_content
  end

  # DELETE /documents/1
  def destroy
    @document.destroy!
  end

  private
    def set_document
      @document = Document.find(params[:id])
    end

    def set_key
      begin
        begin
          # AVM app somehow sends urlsafe base64 even if its source code doesn't seem so
          @key = Base64.urlsafe_decode64(request.headers.to_h['HTTP_X_ENCRYPTION_KEY'] || params[:encryptionKey])
        rescue ArgumentError
          @key = Base64.strict_decode64(request.headers.to_h['HTTP_X_ENCRYPTION_KEY'] || params[:encryptionKey])
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
      params.permit(:encryptionKey, :payloadMimeType, :key, :document => [:filename, :content], :parameters => [:level, :container])
    end

    def datatosign_params
      params.permit(:encryptionKey, :id, :signingCertificate, :addTimestamp)
    end

    def sign_params
      params.require(:signedData)
      dts = params.require(:dataToSignStructure)
      dts.require(:dataToSign)
      dts.require(:signingTime)
      dts.require(:signingCertificate)

      params.permit(:encryptionKey, :id, :signedData, :returnSignedDocument, :dataToSignStructure => [:dataToSign, :signingTime, :signingCertificate])
    end
end
