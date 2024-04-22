class DeleteExpiredTokensJob < ApplicationJob
  def perform
    Token.where('expires_at < ?', Time.now).destroy_all
  end
end
