class DeleteExpiredDocumentsJob < ApplicationJob
  def perform
    Document.where('created_at < ?', Time.now - 24.hours).destroy_all
  end
end
