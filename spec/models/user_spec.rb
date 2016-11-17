require 'rails_helper'

RSpec.describe User, type: :model do

  let(:default_payload) { create_dummy_jwt_payload }
  let(:default_user) { create_dummy_user }

  it 'should be able to create a simple user' do
    user = default_user
    expect(user.valid?).to be_truthy
    expect(user.errors).to match_array([])
  end

  it 'should correctly report \'name\' and \'email\'' do
    user = default_user
    expect(user.name).to eq(default_payload['name'])
    expect(user.email).to eq(default_payload['email'])
  end

  it 'should correctly report \'oauth_provider\' and \'oauth_id\'' do
    user = default_user
    expect("#{user.oauth_provider}|#{user.oauth_id}").to eq(user.identifiable_claim)
  end

  it 'should have a LinkSystem attached on creation' do
    user = default_user
    expect(user.link_system).to be_kind_of(LinkSystem)
  end

  it 'should have a root Directory attached on creation' do
    user = default_user
    expect(user.directory).to be_kind_of(Directory)
    expect(user.directory.root?).to be_truthy
    expect(user.directory.name).to eq('')
  end

  # Authencation tests

  it 'fails authentication on missing \'email\'' do
    begin
      User.from_token_payload (default_payload.except 'email')
      fail 'should have failed because \'email\' was not specified'
    rescue Errors::UserError => e
      expect(e.action).to eq('Authenticate User')
      expect(e.severity).to eq(Errors::Severity::CRITICAL)
    end
    begin
      User.from_token_payload (default_payload.merge 'email' => nil)
      fail 'should have failed because \'email\' was nil'
    rescue Errors::UserError => e
      expect(e.action).to eq('Authenticate User')
      expect(e.severity).to eq(Errors::Severity::CRITICAL)
    end
  end

  it 'fails authentication on missing \'name\'' do
    begin
      User.from_token_payload (default_payload.except 'name')
      fail 'should have failed because \'name\' was not specified'
    rescue Errors::UserError => e
      expect(e.action).to eq('Authenticate User')
      expect(e.severity).to eq(Errors::Severity::CRITICAL)
    end
    begin
      User.from_token_payload (default_payload.merge 'name' => nil)
      fail 'should have failed because \'name\' was nil'
    rescue Errors::UserError => e
      expect(e.action).to eq('Authenticate User')
      expect(e.severity).to eq(Errors::Severity::CRITICAL)
    end
  end

  it 'fails authentication on missing \'iss\'' do
    begin
      User.from_token_payload (default_payload.except 'iss')
      fail 'should have failed because \'iss\' was not specified'
    rescue Errors::UserError => e
      expect(e.action).to eq('Authenticate User')
      expect(e.severity).to eq(Errors::Severity::CRITICAL)
    end
    begin
      User.from_token_payload (default_payload.merge 'iss' => nil)
      fail 'should have failed because \'iss\' was nil'
    rescue Errors::UserError => e
      expect(e.action).to eq('Authenticate User')
      expect(e.severity).to eq(Errors::Severity::CRITICAL)
    end
  end

  it 'fails authentication on missing \'aud\'' do
    begin
      User.from_token_payload (default_payload.except 'aud')
      fail 'should have failed because \'aud\' was not specified'
    rescue Errors::UserError => e
      expect(e.action).to eq('Authenticate User')
      expect(e.severity).to eq(Errors::Severity::CRITICAL)
    end
    begin
      User.from_token_payload (default_payload.merge 'aud' => nil)
      fail 'should have failed because \'aud\' was nil'
    rescue Errors::UserError => e
      expect(e.action).to eq('Authenticate User')
      expect(e.severity).to eq(Errors::Severity::CRITICAL)
    end
  end

  it 'fails authentication on invalid \'iat\'' do
    begin
      User.from_token_payload (default_payload.except 'iat')
      fail 'should have failed because \'iat\' was not specified'
    rescue Errors::UserError => e
      expect(e.action).to eq('Authenticate User')
      expect(e.severity).to eq(Errors::Severity::CRITICAL)
    end
    begin
      User.from_token_payload (default_payload.merge 'iat' => nil)
      fail 'should have failed because \'iat\' was nil'
    rescue Errors::UserError => e
      expect(e.action).to eq('Authenticate User')
      expect(e.severity).to eq(Errors::Severity::CRITICAL)
    end
    begin
      User.from_token_payload (default_payload.merge 'iat' => 'hello')
      fail 'should have failed because \'iat\' was not an Integer'
    rescue Errors::UserError => e
      expect(e.action).to eq('Authenticate User')
      expect(e.severity).to eq(Errors::Severity::CRITICAL)
    end
  end

  it 'fails authentication on invalid \'exp\'' do
    begin
      User.from_token_payload (default_payload.except 'exp')
      fail 'should have failed because \'exp\' was not specified'
    rescue Errors::UserError => e
      expect(e.action).to eq('Authenticate User')
      expect(e.severity).to eq(Errors::Severity::CRITICAL)
    end
    begin
      User.from_token_payload (default_payload.merge 'exp' => nil)
      fail 'should have failed because \'iat\' was nil'
    rescue Errors::UserError => e
      expect(e.action).to eq('Authenticate User')
      expect(e.severity).to eq(Errors::Severity::CRITICAL)
    end
    begin
      User.from_token_payload (default_payload.merge 'exp' => 'hello')
      fail 'should have failed because \'exp\' was not an Integer'
    rescue Errors::UserError => e
      expect(e.action).to eq('Authenticate User')
      expect(e.severity).to eq(Errors::Severity::CRITICAL)
    end
  end

  it 'succeeds authentication on github provider' do
    user = User.from_token_payload (default_payload.merge 'sub' => 'github|1234')
    expect(user.errors).to match_array([])
  end

  it 'succeeds authentication on google-oauth2 provider' do
    user = User.from_token_payload (default_payload.merge 'sub' => 'google-oauth2|1234')
    expect(user.errors).to match_array([])
  end

  it 'fails authentication on unknown claim providers' do
    %w(twitter facebook).each do |provider|
      begin
        User.from_token_payload (default_payload.merge 'sub' => "#{provider}|1234")
        fail "should have thrown because of unsupported provider '#{provider}'"
      rescue Errors::UserError => e
        expect(e.action).to eq('Authenticate User')
        expect(e.severity).to eq(Errors::Severity::CRITICAL)
      end
    end
  end
end
