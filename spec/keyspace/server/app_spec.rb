require 'spec_helper'

describe Keyspace::Server::App do
  let(:app)           { subject }
  let(:vault_store)   { mock(:store) }

  let(:writecap)      { Keyspace::Capability.generate(example_vault) }
  let(:readcap)       { writecap.degrade(:read) }
  let(:verifycap)     { writecap.degrade(:verify) }

  let(:example_vault) { 'foobar' }
  let(:example_name)  { 'baz' }
  let(:example_value) { 'quux' }

  before :each do
    Keyspace::Server::Vault.store = vault_store
  end

  it "creates vaults" do
    vault = Keyspace::Client::Vault.create(example_vault)
    vault_store.should_receive(:[]=).with("verifycap:#{example_vault}", vault.verifycap.to_s)

    post "/vaults", :verifycap => vault.verifycap
    last_response.status.should == 201
  end

  it "stores data in vaults" do
    encrypted_message = Keyspace::Message.new(example_name, example_value).encrypt(writecap)
    vault_store.should_receive(:[]).with("verifycap:#{example_vault}").and_return(verifycap.to_s)

    encrypted_name = Keyspace::Message.unpack(writecap, encrypted_message)[0]
    vault_store.should_receive(:[]=).with("value:#{example_vault}:#{encrypted_name}", encrypted_message)

    put "/vaults/#{example_vault}", encrypted_message, "CONTENT_TYPE" => Keyspace::MIME_TYPE
    last_response.status.should == 200
  end

  it "retrieves data from vaults" do
    vault_store.should_receive(:[]).with("verifycap:#{example_vault}").and_return(verifycap.to_s)

    encrypted_message = Keyspace::Message.new(example_name, example_value).encrypt(writecap)
    encrypted_name    = Keyspace::Message.unpack(writecap, encrypted_message)[0]

    vault_store.should_receive(:[]).with("value:#{example_vault}:#{encrypted_name}").and_return encrypted_message
    get "/vaults/#{example_vault}/#{Base32.encode(encrypted_name)}"

    last_response.status.should == 200
    message = readcap.decrypt(last_response.body)

    message.name.should  eq example_name
    message.value.should eq example_value
  end
end
