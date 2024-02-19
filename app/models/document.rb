class Document < ApplicationRecord
  has_one_attached :encrypted_content

  def decrypted_content(key)
    encrypted_content.download
  end

  def signers(key)
    [
      {
        "signedBy": "SERIALNUMBER=PNOSK-1234567890, C=SK, L=Bratislava, SURNAME=Smith, GIVENNAME=John, CN=John Smith",
        "issuedBy": "CN=SVK eID ACA2, O=Disig a.s., OID.2.5.4.97=NTRSK-12345678, L=Bratislava, C=SK"
      }
    ]
  end

  def visualization(key)
    {
      filename: encrypted_content.filename,
      mimetype: encrypted_content.content_type,
      content: decrypted_content(key),
    }
  end

  def datatosign(key, signing_certificate)
    {
      signing_time: 1707900119123,
      datatosign: 'MYIBBDAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMC8GCSqGSIb3DQEJBDEiBCBi60eUI/NmObmcTwDsze2zBooVmgpZh8puJa4OhNpEejCBtgYLKoZIhvcNAQkQAi8xgaYwgaMwgaAwgZ0EIJz+4gnulo5kn6oovtKTUeONdQyNjCUKINcKqCmvL7JwMHkwa6RpMGcxCzAJBgNVBAYTAlNLMRMwEQYDVQQHEwpCcmF0aXNsYXZhMRcwFQYDVQRhEw5OVFJTSy0zNTk3NTk0NjETMBEGA1UEChMKRGlzaWcgYS5zLjEVMBMGA1UEAxMMU1ZLIGVJRCBBQ0EyAgoG/pWsnJ0ABRcV'
    }
  end

  def sign(key, params)
    true
  end
end
