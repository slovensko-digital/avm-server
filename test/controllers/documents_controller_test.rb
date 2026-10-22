require "test_helper"

class DocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @document = documents(:one)
  end

  test "should not destroy an encrypted document without an encryption key" do
    encrypt_document

    assert_no_difference("Document.count") do
      delete api_v1_document_url(@document), as: :json
    end

    assert_response :unauthorized
  end

  test "should not destroy an encrypted document with a different encryption key" do
    encrypt_document

    assert_no_difference("Document.count") do
      delete api_v1_document_url(@document), headers: encryption_key_header(SecureRandom.random_bytes(32)), as: :json
    end

    assert_response :forbidden
  end

  test "should destroy an encrypted document with its encryption key" do
    key = encrypt_document

    assert_difference("Document.count", -1) do
      delete api_v1_document_url(@document), headers: encryption_key_header(key), as: :json
    end

    assert_response :no_content
  end

  test "should return verifiable visualization of an encrypted document" do
    key = encrypt_document
    visualization = {
      "signatureForm" => "PAdES",
      "document" => { "filename" => "document.pdf", "mimeType" => "application/pdf;base64", "content" => "JVBERi0xLjQ=" },
      "pdfByteRange" => [0, 10, 20, 5],
      "signingTime" => 1707900119123
    }

    with_avm_api(FakeAvmApi.new(verifiable_visualization: visualization)) do
      get verifiable_visualization_api_v1_document_url(@document), headers: encryption_key_header(key), as: :json
    end

    assert_response :success
    assert_equal visualization, response.parsed_body
  end

  test "should not return verifiable visualization without an encryption key" do
    encrypt_document

    get verifiable_visualization_api_v1_document_url(@document), as: :json

    assert_response :unauthorized
  end

  test "should pass signing time to datatosign" do
    key = encrypt_document
    signing_time = (Time.current.to_f * 1000).to_i
    avm_api = FakeAvmApi.new

    with_avm_api(avm_api) do
      post datatosign_api_v1_document_url(@document), params: { signingCertificate: "MIIC", signingTime: signing_time }, headers: encryption_key_header(key), as: :json
    end

    assert_response :success
    assert_equal [["MIIC", signing_time]], avm_api.datatosign_calls
    assert_equal signing_time, response.parsed_body["signingTime"]
  end

  test "should use current signing time in datatosign by default" do
    key = encrypt_document
    avm_api = FakeAvmApi.new

    with_avm_api(avm_api) do
      post datatosign_api_v1_document_url(@document), params: { signingCertificate: "MIIC" }, headers: encryption_key_header(key), as: :json
    end

    assert_response :success
    assert_equal [["MIIC", nil]], avm_api.datatosign_calls
  end

  test "should not accept signing time out of document lifetime" do
    key = encrypt_document
    avm_api = FakeAvmApi.new

    with_avm_api(avm_api) do
      [(@document.created_at - 1.hour).to_i * 1000, (Time.current + 1.hour).to_i * 1000, "now"].each do |signing_time|
        post datatosign_api_v1_document_url(@document), params: { signingCertificate: "MIIC", signingTime: signing_time }, headers: encryption_key_header(key), as: :json

        assert_response :unprocessable_entity
        assert_equal "INVALID_SIGNING_TIME", response.parsed_body["code"]
      end
    end

    assert_empty avm_api.datatosign_calls
  end

  private

    class FakeAvmApi
      attr_reader :datatosign_calls

      def initialize(verifiable_visualization: nil)
        @verifiable_visualization = verifiable_visualization
        @datatosign_calls = []
      end

      def verifiable_visualization(document)
        @verifiable_visualization
      end

      def datatosign(document, signing_certificate, signing_time = nil)
        @datatosign_calls << [signing_certificate, signing_time]
        { "dataToSign" => "ZGF0YVRvU2lnbg==", "signingTime" => signing_time || (Time.current.to_f * 1000).to_i }
      end
    end

    def with_avm_api(avm_api)
      original = Avm::Environment.instance_variable_get(:@avm_api)
      Avm::Environment.instance_variable_set(:@avm_api, avm_api)
      yield
    ensure
      Avm::Environment.instance_variable_set(:@avm_api, original)
    end

    def encrypt_document
      key = SecureRandom.random_bytes(32)
      @document.encrypt_file(key, "document.txt", "text/plain", Base64.strict_encode64("document content"))
      key
    end

    def encryption_key_header(key)
      { "X-Encryption-Key" => Base64.strict_encode64(key) }
    end
end
