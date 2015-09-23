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
          excluded_model.constantize.build_connection
        end
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
        # use establish_connection to retrieve/start a connection to the db server
        Apartment.establish_connection database_config

        #Use preloaded schema_cache to avoid problems during migrations
        Apartment.connection.schema_cache = Apartment::Database.schema_cache if Apartment::Database.schema_cache

        # use "USE" statement to connect to the desired database.
        # the only situation that :target_database should be nil
        # is when database_config is the dummy default config and :database is not nil
        if database_config[:target_database] && use_use
          Apartment.connection.execute "USE #{database_config[:target_database]}"

          # modify the target_database in the cached config to represent the most recent
          # this becomes necessary for calls like #process, which rely on the cached value
          # for connection restore
          Apartment.connection_config[:target_database] = database_config[:target_database]
        else
          # set target_database in cached db config so #current_database_name is accurate
          Apartment.connection_config[:target_database] = Apartment.connection_config[:database]
        end

      rescue Mysql2::Error, ActiveRecord::StatementInvalid
        Apartment::Database.reset
        raise DatabaseNotFound, "Cannot find database #{database_config[:target_database]}"
      end

    end
  end
end
