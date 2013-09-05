require 'spec_helper'

describe 'query caching' do
  before do
    Apartment.configure do |config|
      config.excluded_models = ["Company"]
      config.database_names = lambda{ Company.scoped.collect(&:database) }
    end

    db_configs.each do |db_config|
      Apartment::Database.create(db_config)
      Company.create :database => db_config[:target_database]
    end
  end

  after do
    db_configs.each do |db| 
      Apartment::Database.drop!(db)
    end
    Company.delete_all
  end

  let(:db_configs) do
    config = ActiveRecord::Base.connection.instance_variable_get(:@config)
    
    2.times.map do
      c = config.clone
      d = Apartment::Test.next_db
      c[:database] = "information_schema"
      c[:target_database] = d
      c
    end
  end

  it 'clears the ActiveRecord::QueryCache after switching databases' do
    db_configs.each do |db_config|
      Apartment::Database.switch db_config
      User.create! name: db_config[:target_database]
    end

    ActiveRecord::Base.connection.enable_query_cache!

    Apartment::Database.switch db_configs.first
    User.find_by_name(db_configs.first[:target_database]).name.should == db_configs.first[:target_database]

    Apartment::Database.switch db_configs.last
    User.find_by_name(db_configs.first[:target_database]).should be_nil
  end
end