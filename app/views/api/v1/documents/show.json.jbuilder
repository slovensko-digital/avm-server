json.filename @document.encrypted_content.filename
json.mimeType @document.decrypted_content_mimetype_b64
json.content @document.decrypted_content(key)
json.signers @signers
