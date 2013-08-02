module Apartment
  module Spec

    #
    #   Define the interface methods required to
    #   use an adapter shared example
    #
    #
    module AdapterRequirements

      extend ActiveSupport::Concern

      included do

        let(:db1) { Apartment::Test.next_db }
        let(:db2) { Apartment::Test.next_db }

        let(:db_config1) do
          db_config1 = config.clone
          db_config1[:database] = "information_schema"
          db_config1[:target_database] = db1
          db_config1
        end

        let(:db_config2) do 
          db_config2 = config.clone
          db_config2[:database] = "information_schema"
          db_config2[:target_database] = db2
          db_config2
        end

        let(:connection){ ActiveRecord::Base.connection }

        before do
          Apartment::Database.reload!(config.symbolize_keys)

          subject.create(db_config1)
          subject.create(db_config2)
        end

        after do
          # Reset before dropping (can't drop a db you're connected to)
          subject.reset

          # sometimes we manually drop these schemas in testing, don't care if we can't drop, hence rescue
          subject.drop!(db_config1) rescue true
          subject.drop!(db_config2) rescue true

          # This is annoying, but for each sublcass that establishes its own connection (ie Company for excluded models for connection based adapters)
          # a separate connection is maintained (clear_all_connections! doesn't appear to deal with these)
          # This causes problems because previous tests that established this connection could F up the next test, so we'll just remove them all for each test :(
          Apartment.excluded_models.each do |m|
            klass = m.constantize
            Apartment.connection_class.remove_connection(klass)
            klass.reset_table_name
          end
          ActiveRecord::Base.clear_all_connections!
        end
      end

      %w{subject config database_names default_database}.each do |method|
        define_method method do
          raise "You must define a `#{method}` method in your host group"
        end unless defined?(method)
      end

    end
  end
end