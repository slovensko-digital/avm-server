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

  private

    def encrypt_document
      key = SecureRandom.random_bytes(32)
      @document.encrypt_file(key, "document.txt", "text/plain", Base64.strict_encode64("document content"))
      key
    end

    def encryption_key_header(key)
      { "X-Encryption-Key" => Base64.strict_encode64(key) }
    end
end
