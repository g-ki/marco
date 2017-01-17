class MongoPersistor
  attr_reader :database

  CONECTIONS = {}
  STORES = {}

  def initialize(database)
    @database = database
  end

  def client
    return CONECTIONS[@database] if CONECTIONS[@database]
    CONECTIONS[@database] = Mongo::Client.new( [ 'mongo:27017' ], :database => @database)
  end

  def store(collection)
    return STORES[@database + collection] if STORES[@database + collection]
    STORES[@database + collection] = Marco::Storage::MongoStore.new(mongo: client, collection: collection)
  end

end