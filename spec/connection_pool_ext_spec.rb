=begin

This rspec is commented out since we do not need to override active record anymore.
  Besides, the override of active record is also commented out.


require_relative 'spec_helper'

module ActiveRecord
  describe Base do

    before do
      @nemo_test = { 
        :host => "10.224.25.22",
        :port => 3306,
        :adapter => "mysql2",
        :encoding => "utf8",
        :username => "dev_QSC_root",
        :password => "zh9g4gCxaA3FCxNK",
        :database => "information_schema"
      }

      @nemo_dev = { 
        :host => "10.224.25.21",
        :port => 3306,
        :adapter => "mysql2",
        :encoding => "utf8",
        :username => "dev_QSC_root",
        :password => "zh9g4gCxaA3FCxNK",
        :database => "information_schema"
      }
    end

    after do
      ActiveRecord::Base.establish_connection @nemo_test
      ActiveRecord::Base.connection.execute("DROP DATABASE db1" )

      ActiveRecord::Base.establish_connection @nemo_dev
      ActiveRecord::Base.connection.execute("DROP DATABASE db2" )
    end


    it "should make two threads not override each other's connection in the situation of multiple database servers" do

      
      threads = []

      threads << Thread.new do
        db = "db1"
        ActiveRecord::Base.establish_connection @nemo_test
        ActiveRecord::Base.connection.create_database db
        ActiveRecord::Base.connection.execute("USE #{db}")
        
        5.times do
          sleep 1
          name = ActiveRecord::Base.connection.current_database
          expect(name).to eq(db)
        end

      end

      threads << Thread.new do
        db = "db2"
        ActiveRecord::Base.establish_connection @nemo_dev
        ActiveRecord::Base.connection.create_database db
        ActiveRecord::Base.connection.execute("USE #{db}")
        
        5.times do
          sleep 1
          name = ActiveRecord::Base.connection.current_database
          expect(name).to eq(db)
        end

      end

      threads.each { |thread| thread.join }

    end

  end
end



=end
