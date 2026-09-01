require "test_helper"

class DocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @document = documents(:one)
  end

  test "should destroy an encrypted document without an encryption key" do
    @document.encrypted_content.attach(
      io: StringIO.new("encrypted document content"),
      filename: "document.txt",
      content_type: "text/plain"
    )

    assert_difference("Document.count", -1) do
      delete api_v1_document_url(@document), as: :json
    end

    assert_response :no_content
  end
end
