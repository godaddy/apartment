class Company < ActiveRecord::Base
  # Dummy models

  def self.build_connection
    db_config = Rails.configuration.database_configuration["company"].symbolize_keys
	establish_connection db_config
  end

end