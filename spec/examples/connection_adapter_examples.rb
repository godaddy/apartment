require 'spec_helper'

shared_examples_for "a connection based apartment adapter" do
  include Apartment::Spec::AdapterRequirements


  let(:default_database){ subject.process{ ActiveRecord::Base.connection.current_database } }

  let(:unknown_database_config) do
    unknown_database_config = ActiveRecord::Base.connection.instance_variable_get(:@config).clone
    unknown_database_config[:database] = 'information_schema'
    unknown_database_config[:target_database] = 'unknown_database'
    unknown_database_config
  end

  describe "#init" do
    it "should process model exclusions" do
      Apartment.configure do |config|
        config.excluded_models = ["Company"]
      end

      ActiveRecord::Base.establish_connection
      ActiveRecord::Base.connection.create_database "company"
      Apartment::Database.init
      Company.connection.object_id.should_not == ActiveRecord::Base.connection.object_id
      ActiveRecord::Base.connection.execute "DROP DATABASE company"
    end
  end

  describe "#drop!" do
    it "should raise an error for unknown database" do
      expect {
        subject.drop! unknown_database_config
      }.to raise_error(Apartment::DatabaseNotFound)
    end


  end

  describe "#switch" do
    it "should raise an error if database is invalid" do
      expect {
        subject.switch unknown_database_config
      }.to raise_error(Apartment::DatabaseNotFound)
    end
  end
end