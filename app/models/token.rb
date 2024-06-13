class Token < ApplicationRecord
  validates :key, uniqueness: {scope: :namespace}

  def self.write(key, value, expires_in: 1.hour, namespace: 'default')
    begin
      create!(namespace: namespace, key: key, value: value, expires_at: Time.now + expires_in)
    rescue ActiveRecord::RecordInvalid
      nil
    end
  end
end
