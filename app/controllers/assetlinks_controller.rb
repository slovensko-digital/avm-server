class AssetlinksController < ApplicationController
  def apple_app_site_association
    render :json => JSON.load(Base64.decode64 ENV.fetch('APPLE_APP_SITE_ASSOCIATION', 'e30='))
  end

  def android_assetlinks
    render :json => JSON.load(Base64.decode64 ENV.fetch('ANDROID_ASSEtLINKS', 'e30='))
  end
end
