require 'test_helper'

class UserTest < ActiveSupport::TestCase

  def setup
    @user = create(:user)
  end

  test "email change tokens should expire" do
    @user = create(:user_with_pending_email_change, confirmation_sent_at: 15.days.ago)
    @user.confirm!
    assert_equal "needs to be confirmed within 14 days, please request a new one", @user.errors[:email][0]
  end

  # Attribute protection

  test "the role has to be specifically assigned" do
    u = User.new(name: 'Bad User', role: "admin")
    assert_not_equal "admin", u.role

    u.role = "admin"
    assert_equal "admin", u.role
  end

  # Scopes

  test "fetches users who signed_in X days ago" do
    signed_in_2_days_ago = create(:user, current_sign_in_at: 2.days.ago)
    signed_in_8_days_ago = create(:user, current_sign_in_at: 8.days.ago)

    assert_equal [signed_in_2_days_ago], User.last_signed_in_on(2.days.ago)
  end

  test "fetches users who signed_in before X days ago" do
    signed_in_6_days_ago = create(:user, current_sign_in_at: 6.days.ago)
    signed_in_7_days_ago = create(:user, current_sign_in_at: 7.days.ago)
    signed_in_8_days_ago = create(:user, current_sign_in_at: 8.days.ago)

    assert_equal [signed_in_7_days_ago, signed_in_8_days_ago], User.last_signed_in_before(6.days.ago)
  end

  # Password Validation

  test "it requires a password to be at least 10 characters long" do
    u = build(:user, :password => "dNG.c0w5!")
    assert !u.valid?
    assert_not_empty u.errors[:password]
  end

  test "it allows very long passwords with spaces" do
    u = build(:user, :password => ("4 l0nG sT!,ng " * 10)[0..127])
    u.valid?
    assert u.valid?
    assert_empty u.errors[:password]
  end

  test "it requires a reason for suspension to suspend a user" do
    u = create(:user)
    u.suspended_at = 1.minute.ago
    assert ! u.valid?
    assert_not_empty u.errors[:reason_for_suspension]
  end

  test "organisation admin must belong to an organisation" do
    user = build(:user, role: 'organisation_admin', organisation_id: nil)

    assert_false user.valid?
    assert_equal "can't be 'None' for an Organisation admin", user.errors[:organisation_id].first
  end

  # Password migration
  test "it migrates old passwords on sign-in" do
    password = ("4 l0nG sT!,ng " * 10)[0..127]
    old_encrypted_password = ::BCrypt::Password.create("#{password}", :cost => 10).to_s

    u = create(:user)
    u.update_column :encrypted_password, old_encrypted_password
    u.reload

    assert u.valid_legacy_password?(password), "Not recognised as valid old-style password"
    assert u.valid_password?(password), "Doesn't allow old-style password"
    u.reload

    assert_not_equal old_encrypted_password, u.encrypted_password, "Doesn't change password format"
    assert u.valid_password?(password), "Didn't recognise correct password"
  end

  test "it doesn't migrate password unless correct one given" do
    password = ("4 l0nG sT!,ng " * 10)[0..127]
    old_encrypted_password = ::BCrypt::Password.create("#{password}", :cost => 10).to_s

    u = create(:user)
    u.update_column :encrypted_password, old_encrypted_password
    u.reload

    assert ! u.valid_password?("something else")
    u.reload

    assert_equal old_encrypted_password, u.encrypted_password, "Changed passphrase"
  end

  test "can grant permissions to user application and permission name" do
    app = create(:application, name: "my_app", supported_permissions: [
            create(:supported_permission, name: 'signin'),
            create(:supported_permission, name: 'Create publications'),
            create(:supported_permission, name: 'Delete publications')
          ])
    user = create(:user)

    user.grant_permission(app, "Create publications")

    assert_user_has_permissions ['Create publications'], app, user
  end

  test "granting an already granted permission doesn't cause duplicates" do
    app = create(:application, name: "my_app")
    user = create(:user)

    user.grant_permission(app, "signin")
    user.grant_permission(app, "signin")

    assert_user_has_permissions ['signin'], app, user
  end

  test "inviting a user sets confirmed_at" do
    if user = User.find_by_email("j@1.com")
      user.delete
    end
    user = User.invite!(name: "John Smith", email: "j@1.com")
    assert_not_nil user
    assert user.persisted?
    assert_not_nil user.confirmed_at
  end

  test "performs validations before inviting" do
    user = User.invite!(name: nil, email: "j@1.com")

    assert_not_empty user.errors
    assert_false user.persisted?
  end

  def assert_user_has_permissions(expected_permissions, application, user)
    permissions_for_my_app = user.permissions.reload.find_by_application_id(application.id)
    assert_equal expected_permissions, permissions_for_my_app.permissions
  end

end
