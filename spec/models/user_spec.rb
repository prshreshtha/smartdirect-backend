require 'rails_helper'

RSpec.describe User, type: :model do

  let(:default_payload) { create_dummy_jwt_payload }
  let(:default_user) { create_dummy_user! }

  it 'is able to create a simple one' do
    user = default_user
    expect(user.valid?).to be_truthy
    expect(user.errors).to match_array([])
  end

  context 'when creating user' do
    it 'correctly reports \'name\'' do
      user = default_user
      expect(user.name).to eq(default_payload['name'])
    end
    it 'correctly reports \'email\'' do
      user = default_user
      expect(user.email).to eq(default_payload['email'])
    end
    it 'correctly reports \'friendly_name\'' do
      user = default_user
      expect(user.friendly_name).to eq('john-smith')
    end
    it 'has an attached root Directory' do
      user = default_user
      expect(user.directory).to be_kind_of(Directory)
      expect(user.directory.root?).to be_truthy
      expect(user.directory.name).to eq('')
    end
    it 'does not share directory with another user' do
      20.times do |n|
        create_dummy_user! identifiable_claim: "google-oauth2|#{n.to_s}"
      end
      all_users_directory_ids = User.all.map do |user|
        user.directory.id
      end
      expect(all_users_directory_ids).to match_array(all_users_directory_ids.uniq)
    end
  end

  context 'when generating friendly name' do
    context 'when empty(-ish)' do
      it 'uses a fake name if empty name' do
        friendly_name = User.generate_friendly_name ''
        # good enough
        expect(friendly_name.length).to be > 0
      end
      it 'uses a fake name if symbolic name' do
        garbage_name = " ☀☂☕ \t "
        friendly_name = User.generate_friendly_name garbage_name
        expect(friendly_name.length).to be > 0
        expect(friendly_name.chars & garbage_name.chars).to match_array([])
      end
    end

    context 'when unfriendly characters' do
      it 'converts ascii symbols to words' do
        expect(User.generate_friendly_name 'Tom & Jerry').to eq('tom-and-jerry')
      end
      it 'converts standard unicode characters' do
        expect(User.generate_friendly_name 'TèïåçêèÄÉæôm & Jërry').to eq('teiaceeaeaeom-and-jerry')
      end
      it 'omits weird unicode characters' do
        expect(User.generate_friendly_name 'Tom &♣⌂⌐♪ Jerry').to eq('tom-and-jerry')
      end
    end

    context 'when conflicts' do
      let (:default_user2) { create_dummy_user! identifiable_claim: 'google-oauth2|1234' }
      let (:default_user3) { create_dummy_user! identifiable_claim: 'google-oauth2|12345' }

      it 'suffixes numbers' do
        user = default_user
        user2 = default_user2
        user3 = default_user3
        expect(user2.friendly_name).to eq("#{user.friendly_name}1")
        expect(user3.friendly_name).to eq("#{user.friendly_name}2")
      end
    end

    context 'when name is long' do
      it 'works with exactly max length' do
        name = 'a' * 20
        expect(User.generate_friendly_name(name, max_length: 20)).to eq(name)
      end
      it 'breaks on words instead of characters' do
        name = 'hello-world'
        max_length = 'hello-wor'.length
        expect(User.generate_friendly_name(name, max_length: max_length)).to eq('hello')
      end
      it 'truncates if one word is too long' do
        name = 'hello'
        expect(User.generate_friendly_name(name, max_length: 2)).to eq('he')
      end
      it 'truncates ascii converted url' do
        name = '%' * 2
        max_length = 'percent'.length + 1
        expect(User.generate_friendly_name(name, max_length: max_length)).to eq('percent')
      end
      it 'does not have trailing dashes' do
        name = 'a-'
        expect(User.generate_friendly_name name, max_length: 2).to eq('a')
      end

      context 'when conflicts' do
        let (:what_the_user) {
          create_dummy_user!(
            identifiable_claim: 'google-oauth2|1234',
            friendly_name: 'what-the',
          )
        }
        it 'truncates last word to be make room for suffix' do
          # Force create the user
          what_the_user
          name = 'what-the-hell'
          max_length = 'what-the'.length
          expect(User.generate_friendly_name name, max_length: max_length).to eq('what-th1')
        end
      end
    end
  end

  context 'when user changes their info' do
    let(:identifiable_claim) { 'github|1234' }
    it 'updates \'name\'' do
      user = User.from_token_payload(
          jwt_payload_from(
              identifiable_claim: identifiable_claim,
              name: 'Person A',
              email: 'JSmith@example.com'
          )
      )
      expect(user.name).to eq('Person A')

      first_user_id = user.id
      user = User.from_token_payload(
          jwt_payload_from(
              identifiable_claim: identifiable_claim,
              name: 'Person B',
              email: 'Person@example.com'
          )
      )
      expect(user.id).to eq(first_user_id)

      expect(user.name).to eq('Person B')
    end
    it 'updates \'email\'' do
      user = User.from_token_payload(
          jwt_payload_from(
              identifiable_claim: identifiable_claim,
              name: 'Person',
              email: 'PersonA@example.com'
          )
      )
      expect(user.email).to eq('PersonA@example.com')

      first_user_id = user.id
      user = User.from_token_payload(
          jwt_payload_from(
              identifiable_claim: identifiable_claim,
              name: 'Person',
              email: 'PersonB@example.com'
          )
      )
      expect(user.id).to eq(first_user_id)
      expect(user.email).to eq('PersonB@example.com')
    end

    it 'does not automatically update \'friendly_name\'' do
      user = User.from_token_payload(
          jwt_payload_from(
              identifiable_claim: identifiable_claim,
              name: 'Person A',
              email: 'Person@example.com'
          )
      )
      expect(user.friendly_name).to eq('person-a')

      first_user_id = user.id
      user = User.from_token_payload(
          jwt_payload_from(
              identifiable_claim: identifiable_claim,
              name: 'Person B',
              email: 'Person@example.com'
          )
      )
      expect(user.id).to eq(first_user_id)
      expect(user.friendly_name).to eq('person-a')
    end

    it 'does not allow duplicate\'friendly_name\'' do
      user1 = create_dummy_user!(
          identifiable_claim: 'google-oauth2|1234',
          friendly_name: 'user1',
      )
      user2 = create_dummy_user!(
          identifiable_claim: 'google-oauth2|5678',
          friendly_name: 'user2',
      )
      # sanity checks
      expect(user1.valid?).to eq(true)
      expect(user2.valid?).to eq(true)

      # conflict!
      user2.friendly_name = user1.friendly_name

      expect(user1.valid?).to eq(true)
      expect(user2.valid?).to eq(false)
    end
  end

  context 'when validating jwt claims' do
    context 'when validating \'name\'' do
      it 'fails if missing' do
        begin
          User.from_token_payload (default_payload.except 'name')
          fail 'should have failed because \'name\' was not specified'
        rescue Errors::UserError => e
          expect(e.action).to eq('Authenticate User')
          expect(e.severity).to eq(Errors::Severity::CRITICAL)
        end
      end
      it 'fails if nil' do
        begin
          User.from_token_payload (default_payload.merge 'name' => nil)
          fail 'should have failed because \'name\' was nil'
        rescue Errors::UserError => e
          expect(e.action).to eq('Authenticate User')
          expect(e.severity).to eq(Errors::Severity::CRITICAL)
        end
      end
    end

    context 'when validating \'email\'' do
      it 'fails if missing' do
        begin
          User.from_token_payload (default_payload.except 'email')
          fail 'should have failed because \'email\' was not specified'
        rescue Errors::UserError => e
          expect(e.action).to eq('Authenticate User')
          expect(e.severity).to eq(Errors::Severity::CRITICAL)
        end
      end
      it 'fails if nil' do
        begin
          User.from_token_payload (default_payload.merge 'email' => nil)
          fail 'should have failed because \'email\' was nil'
        rescue Errors::UserError => e
          expect(e.action).to eq('Authenticate User')
          expect(e.severity).to eq(Errors::Severity::CRITICAL)
        end
      end
    end

    context 'when validating \'iss\'' do
      it 'fails if missing' do
        begin
          User.from_token_payload (default_payload.except 'iss')
          fail 'should have failed because \'iss\' was not specified'
        rescue Errors::UserError => e
          expect(e.action).to eq('Authenticate User')
          expect(e.severity).to eq(Errors::Severity::CRITICAL)
        end
      end
      it 'fails if nil' do
        begin
          User.from_token_payload (default_payload.merge 'iss' => nil)
          fail 'should have failed because \'iss\' was nil'
        rescue Errors::UserError => e
          expect(e.action).to eq('Authenticate User')
          expect(e.severity).to eq(Errors::Severity::CRITICAL)
        end
      end
    end

    context 'when validating \'aud\'' do
      it 'fails if missing' do
        begin
          User.from_token_payload (default_payload.except 'aud')
          fail 'should have failed because \'aud\' was not specified'
        rescue Errors::UserError => e
          expect(e.action).to eq('Authenticate User')
          expect(e.severity).to eq(Errors::Severity::CRITICAL)
        end
      end
      it 'fails if nil' do
        begin
          User.from_token_payload (default_payload.merge 'aud' => nil)
          fail 'should have failed because \'aud\' was nil'
        rescue Errors::UserError => e
          expect(e.action).to eq('Authenticate User')
          expect(e.severity).to eq(Errors::Severity::CRITICAL)
        end
      end
    end

    context 'when validating \'iat\'' do
      it 'fails if missing' do
        begin
          User.from_token_payload (default_payload.except 'iat')
          fail 'should have failed because \'iat\' was not specified'
        rescue Errors::UserError => e
          expect(e.action).to eq('Authenticate User')
          expect(e.severity).to eq(Errors::Severity::CRITICAL)
        end
      end
      it 'fails if nil' do
        begin
          User.from_token_payload (default_payload.merge 'iat' => nil)
          fail 'should have failed because \'iat\' was nil'
        rescue Errors::UserError => e
          expect(e.action).to eq('Authenticate User')
          expect(e.severity).to eq(Errors::Severity::CRITICAL)
        end
      end
      it 'fails if it\'s not an integer' do
        begin
          User.from_token_payload (default_payload.merge 'iat' => 'hello')
          fail 'should have failed because \'iat\' was not an Integer'
        rescue Errors::UserError => e
          expect(e.action).to eq('Authenticate User')
          expect(e.severity).to eq(Errors::Severity::CRITICAL)
        end
      end
    end

    context 'when vadating \'exp\'' do
      it 'fails if missing' do
        begin
          User.from_token_payload (default_payload.except 'exp')
          fail 'should have failed because \'exp\' was not specified'
        rescue Errors::UserError => e
          expect(e.action).to eq('Authenticate User')
          expect(e.severity).to eq(Errors::Severity::CRITICAL)
        end
      end
      it 'fails if nil' do
        begin
          User.from_token_payload (default_payload.merge 'exp' => nil)
          fail 'should have failed because \'iat\' was nil'
        rescue Errors::UserError => e
          expect(e.action).to eq('Authenticate User')
          expect(e.severity).to eq(Errors::Severity::CRITICAL)
        end
      end
      it 'fails if it\'s not an integer' do
        begin
          User.from_token_payload (default_payload.merge 'exp' => 'hello')
          fail 'should have failed because \'exp\' was not an Integer'
        rescue Errors::UserError => e
          expect(e.action).to eq('Authenticate User')
          expect(e.severity).to eq(Errors::Severity::CRITICAL)
        end
      end
    end
  end

  context 'when authenticating oauth provider' do
    it 'succeeds with github' do
      user = User.from_token_payload (default_payload.merge 'sub' => 'github|1234')
      expect(user.errors).to match_array([])
    end

    it 'succeeds with google-oauth2' do
      user = User.from_token_payload (default_payload.merge 'sub' => 'google-oauth2|1234')
      expect(user.errors).to match_array([])
    end

    it 'fails on unknown claim' do
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

end
