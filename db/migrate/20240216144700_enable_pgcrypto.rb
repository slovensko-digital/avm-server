class EnablePgcrypto < ActiveRecord::Migration[7.1]
  def change
    enable_extension 'pgcrypto' unless extensions.include?('pgcrypto')
  end
end
