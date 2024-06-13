class AppleController < ApplicationController
  def apple_app_site_association
    render :json => {
      "applinks": {
        "details": [
          {
            "appIDs": [
              "44U4JSRX4Z.digital.slovensko.avm"
            ],
            "components": [
              {
                "/": "/api/*"
              }
            ]
          }
        ]
      }
    }
  end
end
