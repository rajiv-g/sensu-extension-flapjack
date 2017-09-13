# require File.join(File.dirname(__FILE__), "helpers")
require "sensu/extensions/flapjack"
require "sensu/logger"
require "rspec"
require "fakeredis"
require "fakeredis/rspec"
require "sensu/redis"
require 'json'

describe "Sensu::Extensions::Flapjack specs" do

  before do
    @extension = Sensu::Extension::Flapjack.new
    @extension_name = "flapjack"
    @extension_description = 'Sends sensu events to the Flapjack Redis Queue'
    @default_config = {
      host: '127.0.0.1',
      port: 6379,
      channel: 'events',
      db: 0,
      initial_failure_delay: 30,
      repeat_failure_delay: 60,
      flapjack_version: 1,
      enabled: true
    }
    @redis_instance = Redis.new
    @extension.instance_variable_set("@logger", Sensu::Logger.get(:log_level => :fatal))

  end

  it "should return name" do
    expect(@extension.name).to eq(@extension_name)
  end

  it "should return description" do
    expect(@extension.description).to eq(@extension_description)
  end

  it "#create_config raise error if no configuration is specified" do
    @extension.stub(:settings) { Hash.new }
    expect { @extension.post_init }.to raise_error(ArgumentError)
  end

  it "should return config hash with settings merged" do
    settings = { @extension_name => { host: 'flapjack.host', port: 8888 } }
    result = @default_config.merge(settings[@extension_name])
    @extension.stub(:settings) { settings }
    expect(@extension.create_config(@extension_name, @default_config)).to eq(result)
  end

  it 'should return definition' do
    expect(@extension.definition).to eq({
      type: 'extension',
      name: @extension_name,
      mutator: 'ruby_hash'
    })
  end

  it 'should #post_init establish redis connection' do
    settings = { @extension_name => {} }
    @extension.stub(:settings) { settings }
    allow(Sensu::Redis).to receive(:connect).and_return(@redis_instance)
    expect { @extension.post_init }.not_to raise_error
  end

  # it 'should #post_init log errors if any' do
  #   settings = { @extension_name => {} }
  #   @extension.stub(:settings) { settings }
  #   allow(Sensu::Redis).to receive(:connect).and_return(@redis_instance)
  #   # expect { @extension.post_init }.to 
  # end
  
  it "should push to redis server" do
    settings = { @extension_name => {} }
    @extension.stub(:settings) { settings }
    allow(Sensu::Redis).to receive(:connect).and_return(@redis_instance)
    stub_const("Sensu::SEVERITIES", %w[ok warning critical unknown].freeze)
    
    event = {
      client: {
        name: "rspec",
        address: "client-address",
        subscriptions: ["all"],
      },
      check: {
        output: "rspec 69 1480697845",
        flapjack_enabled: true,
        status: 0
      }
    }
    @extension.post_init do end
    @extension.instance_variable_set("@redis", @redis_instance)
    expect{ @extension.run(event.to_json) do end }.to_not raise_error
  end
end