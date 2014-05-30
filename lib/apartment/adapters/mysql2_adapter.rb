module Apartment

  module Database

    def self.mysql2_adapter(config)
        Adapters::Mysql2Adapter.new(config)
    end

  end

  module Adapters

    class Mysql2Adapter < AbstractAdapter

      def process_excluded_models
        Apartment.excluded_models.each do |excluded_model|
          puts "[EXCLUDED] Build connection for #{excluded_model}" if @@debug
          excluded_model.constantize.build_connection
        end
      end

      # Maintain current database name being used
      # This is necessary because our connection pooling ignores database name and we have
      # no direct reference to db name (we simply call "USE [database]" for db switching)
      # Keeping the database name in thread current to be thread safe and relying on this
      # value being set every time db connection changes (see connect_to_new method in this class)
      def current_database_name
        Thread.current[:apartment_current_database_name]
      end

      def current_database_name=(name)
        Thread.current[:apartment_current_database_name] = name
      end

    protected

      #   Connect to new database
      #   Abstract adapter will catch generic ActiveRecord error
      #   Catch specific adapter errors here
      #
      #   @param 
      #     {Hash} database_config, complete info of a database, :database, :host, ...
      #     {Boolean} use_use, if use USE statement. In creation process, we do not want to use use since there is not db to use.
      #   ---------------------------------------
      def connect_to_new(database_config, use_use)

        # Step1: using establish_connection to retrieve/start a connection to the db server.
        Apartment.establish_connection database_config

        # Step2: use "USE" to connect to the desired database.
        # the only situation that :target_database is nil that database_config is the dummy default config.
        self.current_database_name = database_config[:database]
        unless database_config[:target_database].nil?
          if use_use
            Apartment.connection.execute "USE #{database_config[:target_database]}"
            self.current_database_name = database_config[:target_database]
          end
        end

      rescue Mysql2::Error, ActiveRecord::StatementInvalid
        Apartment::Database.reset
        raise DatabaseNotFound, "Cannot find database #{database_config[:target_database]}"
      end

    end
  end
end
