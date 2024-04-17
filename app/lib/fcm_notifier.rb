class FcmNotifer
  def initialize
    @fcm = FCM.new(
      ENV.fetch('FIREBASE_API_TOKEN', ''),
      StringIO.new(ENV.fetch('FIREBASE_CREDENTIALS')),
      ENV.fetch('FIREBASE_PROJECT_ID')
    )
  end

  def notify(registration_id, message)
    Rails.logger.debug "FcmNorifier.notify for registration_id: #{registration_id} with message: #{message}"

    message = {
      'token': registration_id,
      'data': {
        encrypted_message: message
      },
      'notification': {
        title: "Podpisovanie dokumentu",
        body: "Podpíšte elektronický dokument",
      },
      'android': {
        priority: "high",
        ttl: "300s"
      },
      'apns': {
        payload: {
          headers:{
            'apns-priority': "10",
            'apns-expiration': "#{Time.zone.now.to_i + 300}"
          },
          aps: {
            category: "SIGN_EXTERNAL_DOCUMENT"
          }
        }
      }
      # TODO: consider analytic labels
      # 'fcm_options': {
      #   analytics_label: 'Label'
      # }
    }

    # TODO: handle errors and implement exponential back-off
    fcm.send_v1(message)
  end
end
