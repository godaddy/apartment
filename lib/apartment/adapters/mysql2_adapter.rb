module Apartment

  module Database

    def self.mysql2_adapter(config)
        Adapters::Mysql2Adapter.new(config)
    end
  end

  module Adapters

    class Mysql2Adapter < AbstractAdapter

    protected

      #   Connect to new database
      #   Abstract adapter will catch generic ActiveRecord error
      #   Catch specific adapter errors here
      #
      #   @param {Hash} database_config, 
      #         complete info of a database, :database, :host, ...
      #   ---------------------------------------
      def connect_to_new(database_config)

        # Step1: using establish_connection to retrive/start a connection to the db server.
        default_database_config = database_config.clone.tap do |config|
          config[:database] = DEFAULT_DB          
        end
        Apartment.establish_connection default_database_config

        # Step2: use "USE" to connect to the desired databse.
        Apartment.connection.execute "USE #{database_config[:database]}"

      rescue Mysql2::Error, ActiveRecord::StatementInvalid
        Apartment::Database.reset
        raise DatabaseNotFound, "Cannot find database #{database_config[:database]}"
      end
      
      # return {string}, name of the current database
      def current_database_name
        # In the release of rails 3.2.14 rc2, 
        # ActiveRecord::Base.connection.current_database becomes a private method.
        # Apartment.connection.current_database # 3.2.13
      
        # 3.2.14 # Running MySql command directly to retrive the current used db name.
        Apartment.connection.select_value 'SELECT DATABASE() as db'
      end

      #   TODO: Not sure if we need this method anymore, may delete it later.
      def process_excluded_model(model)
        model.constantize.tap do |klass|
          # some models (such as delayed_job) seem to load and cache their column names before this,
          # so would never get the default prefix, so reset first
          klass.reset_column_information

          # Ensure that if a schema *was* set, we override
          table_name = klass.table_name.split('.', 2).last

          # Not sure why, but Delayed::Job somehow ignores table_name_prefix...  so we'll just manually set table name instead
          klass.table_name = "#{default_database}.#{table_name}"
        end
      end

    end
  end
end
