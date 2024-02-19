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
    d = p.require(:document)
    @document = Document.new(parameters: p[:parameters])
    @document.encrypted_content.attach(filename: d[:filename] || "document", content_type: p.require(:payloadMimeType), io: StringIO.new(d.require(:content)))

    render json: @document.errors, status: :unprocessable_entity unless @document.save
  end

  # POST /documents/1/visualization
  def visualization
    @visualization = @document.visualization
  end

  # POST /documents/1/datatosign
  def datatosign
    @signing_certificate = datatosign_params.require(:signingCertificate)
    @result = @document.datatosign(@signing_certificate)
  end

  # POST /documents/1/sign
  def sign
    @signed_by = "SERIALNUMBER=PNOSK-1234567890, C=SK, L=Bratislava, SURNAME=Smith, GIVENNAME=John, CN=John Smith"
    @issued_by = "CN=SVK eID ACA2, O=Disig a.s., OID.2.5.4.97=NTRSK-12345678, L=Bratislava, C=SK"

    unless @document.sign(sign_params)
      render json: @document.errors, status: :unprocessable_entity
    end
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
      @key = request.headers.to_h['HTTP_X_ENCRYPTION_KEY'] || params[:encryptionKey]
      raise ActionController::ParameterMissing.new('X-Encryption-Key') unless @key
    end

    def decrypt_document_content
      @decrypted_content = @document.decrypted_content(@key)
    end

    def document_params
      params.permit(:encryptionKey, :payloadMimeType, :key, :document => [:filename, :content], :parameters => [:level, :container])
    end

    def datatosign_params
      params.permit(:encryptionKey, :id, :signingCertificate)
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
