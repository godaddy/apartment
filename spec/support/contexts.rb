#   Some shared contexts for specs

shared_context "with default schema", :default_schema => true do
  let(:default_schema){ Apartment::Test.next_db }

  before do
    Apartment::Test.create_schema(default_schema)
    Apartment.default_schema = default_schema
  end

  after do
    # resetting default_schema so we can drop and any further resets won't try to access droppped schema
    Apartment.default_schema = nil
    Apartment::Test.drop_schema(default_schema)
  end
end

# Some default setup for elevator specs
shared_context "elevators", :elevator => true do
  let(:company1)  { mock_model(Company, :database => Apartment::Test.next_db).as_null_object }
  let(:company2)  { mock_model(Company, :database => Apartment::Test.next_db).as_null_object }
  
  let(:database1) { company1.database }
  let(:database2) { company2.database }
  
  let(:api)       { Apartment::Database }
  
  let(:database1_config) do
    database1_config = api.current
    database1_config[:database] = "information_schema"
    database1_config[:target_database] = database1
    database1_config  
  end

  let(:database2_config) do
    database2_config = api.current
    database2_config[:database] = "information_schema"
    database2_config[:target_database] = database2
    database2_config  
  end

   before do
     Apartment.reset # reset all config
     Apartment.seed_after_create = false
     Apartment.use_schemas = true
     api.reload! # reload adapter

     api.create(database1_config)
     api.create(database2_config)
   end

   after do
     api.drop!(database1_config)
     api.drop!(database2_config)
  end
end

shared_context "persistent_schemas", :persistent_schemas => true do
  let(:persistent_schemas){ ['hstore', 'postgis'] }

  before do
    persistent_schemas.map{|schema| subject.create(schema) }
    Apartment.persistent_schemas = persistent_schemas
  end

  after do
    Apartment.persistent_schemas = []
    persistent_schemas.map{|schema| subject.drop!(schema) }
  end
end