require 'spec_helper'
require 'apartment/adapters/mysql2_adapter'

describe Apartment::Adapters::Mysql2Adapter do
  unless defined?(JRUBY_VERSION)

    let(:config){ Apartment::Test.config['connections']['mysql'].symbolize_keys }

    subject(:adapter) { Apartment::Database.mysql2_adapter config }

    def database_names
      ActiveRecord::Base.connection.execute("SELECT schema_name FROM information_schema.schemata").collect { |row| row[0] }
    end

    let(:default_database) { subject.process { ActiveRecord::Base.connection.current_database } }

    context "using - the equivalent of - schemas" do
      before { Apartment.use_schemas = true }

      it_should_behave_like "a generic apartment adapter"

      describe "#default_database" do
        it "should has default_database" do
          expect(default_database).to eq(config[:database])
        end
      end

      describe "#init" do
        include Apartment::Spec::AdapterRequirements

        before do
          Apartment.configure do |config|
            config.excluded_models = ["Company"]
          end
        end

        it "should process model exclusions" do
          Apartment::Database.init
          database = Company.connection.instance_variable_get(:@config)[:database]
          expect(database).to eq(default_database)
        end
      end
    end

=begin

    # Our mysql adapter establish connection_pool to database server.

    context "using connections" do
      before { Apartment.use_schemas = false }

      it_should_behave_like "a generic apartment adapter"
      it_should_behave_like "a connection based apartment adapter"
    end
=end

  end
end
