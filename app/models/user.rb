class User < ApplicationRecord
  def self.from_token_payload(payload)
    # We are very careful here wrt/ exceptions because any exceptions thrown here
    # will cause Knock to fail authentication even though that might not be the underlying
    # cause. This way we'll at least get a log. The requester will still get a vague "invalid token"
    # message.
    # NOTE: This method should never return nil. If a user cannot be found, throw a UserError
    begin
      # Sanity checks:
      # We require scopes: openid email name
      unless %w(iss sub aud email name).all? { |field| payload[field].is_a? String } &&
          %w(exp iat).all? { |field| payload[field].is_a? Integer }
        raise Errors::UserError.new(
            action: 'Authenticate User',
            message: 'Missing field(s) in JWT payload',
            severity: Errors::Severity::CRITICAL,
            userdata: { :payload => payload }
        )
      end

      # This is expected to be in the format
      # "#{provider}|#{user_id}"
      sub_claim = payload['sub']

      # Only accept recognized providers, e.g. 'github|', 'google-oauth2|'
      # Take note of the pipe (|) that separates the provider from their ID
      known_providers = Settings[:jwt][:known_oauth_providers]
      if known_providers.none? { |provider| sub_claim.start_with? "#{provider}|" }
        raise Errors::UserError.new(
            action: 'Authenticate User',
            message: "Unknown provider for JWT 'sub' claim '#{sub_claim}'",
            severity: Errors::Severity::CRITICAL,
            userdata: { :payload => payload }
        )
      end

      # Since we provide no sign up mechanism ourselves, users are created on the fly
      user = self.find_or_create_by identifiable_claim: sub_claim do |user|
        # NOTE: This is only called when creating a new user
        # The code works without this but then we have an extra query
        # and created_at no longer matches updated_at
        user.name = payload['name']
        user.email = payload['email']
      end

      # If these fields have changed, then update them in the database as well
      # If we've just created a new user right, that's okay. This will be a no-op
      user.name = payload['name']
      user.email = payload['email']
      user.save! if user.changed?

      # And finally, return the user back
      return user
    rescue Exception => e
      Rails.logger.error "Error when fetching error from jwt payload: #{e.message}"
      raise
    end
  end

  # This is the root Directory attached to the user.
  belongs_to :directory, optional: true
  # When a new user is created, we need to also create a root Directory for them
  before_create :build_root_directory_if_needed
  # Take ownership of our root Directory always
  after_create :take_ownership_of_directory

  # If the user doesn't have a root Directory, they can't do anything
  validates_presence_of :directory, on: :save
  validates_associated :directory
  # Make sure our root Directory is actually a root directory
  validate :_validate_directory_is_root, on: :update

  # This is the first part of the claim. (e.g. 'github', 'google-oauth2')
  def oauth_provider
    return identifiable_claim_parts[0] || '<unknown>'
  end

  # This is the second part of the claim. It is the unique ID for the user that
  # comes from the oauth_provider
  def oauth_id
    return identifiable_claim_parts[1] || '<unknown>'
  end

  private

  def identifiable_claim_parts
    parts = identifiable_claim.split('|')
    # We expect it in the format specified in models/user.rb
    # Otherwise don't provide any information
    return parts if parts.length == 2
    return []
  end

  def build_root_directory_if_needed
    # Over here, we create the root Directory for a user.
    # This directory doesn't really have a name so we choose empty string
    unless directory == nil
      return
    end
    create_directory name: ''
    return true
  end

  def take_ownership_of_directory
    directory.user = self
    # Throw an exception if we can't take ownership.
    # This will cause us to rollback the transaction and
    # no phantom directories will be created.
    directory.save!
  end

  def _validate_directory_is_root
    if directory == nil || !directory.root? || directory.name != ''
      errors.add(:directory, 'must be a root Directory')
    end
  end
end
