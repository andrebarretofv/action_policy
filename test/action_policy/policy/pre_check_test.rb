# frozen_string_literal: true

require "test_helper"

class TestPreCheck < Minitest::Test
  class BasePolicy
    include ActionPolicy::Policy::Core
    include ActionPolicy::Policy::Verification
    include ActionPolicy::Policy::PreCheck

    verify :user

    pre_check :allow_admins

    private

    def allow_admins
      allow! if user.admin?
    end
  end

  class TestPolicy < BasePolicy
    pre_check :deny_when_record_is_nil, except: [:index?]
    pre_check :user_is_nil, only: [:new?, :index?]

    def index?
      true
    end

    def new?
      true
    end

    def manage?
      record != false
    end

    private

    def deny_when_record_is_nil
      deny! if record.nil?
    end

    def user_is_nil
      deny! if user.name == "Neil"
    end
  end

  class AdminTestPolicy < TestPolicy
    skip_pre_check :allow_admins, only: :manage?
    skip_pre_check :deny_when_record_is_nil, only: :manage?
    skip_pre_check :user_is_nil, except: [:new?]

    def show?
      manage?
    end
  end

  class NoAdminTestPolicy < TestPolicy
    skip_pre_check :allow_admins

    def show?
      manage?
    end
  end

  def setup
    @guest = User.new("guest")
    @admin = User.new("admin")
  end

  attr_reader :guest, :admin

  def test_allow_pre_check
    policy = TestPolicy.new false, user: admin

    assert policy.apply(:manage?)

    policy2 = TestPolicy.new false, user: guest

    refute policy2.apply(:manage?)
  end

  def test_deny_pre_check
    policy = TestPolicy.new false, user: guest

    assert policy.apply(:index?)
    refute policy.apply(:manage?)

    policy2 = TestPolicy.new nil, user: guest

    assert policy2.apply(:index?)
    refute policy2.apply(:manage?)

    policy3 = TestPolicy.new nil, user: admin

    assert policy3.apply(:index?)
    assert policy3.apply(:manage?)
  end

  def test_skip_pre_check_completely
    policy = NoAdminTestPolicy.new false, user: admin

    assert policy.apply(:index?)
    refute policy.apply(:manage?)
    refute policy.apply(:show?)
  end

  def test_skip_except_pre_check_with_only
    policy = AdminTestPolicy.new false, user: admin

    assert policy.apply(:index?)
    refute policy.apply(:manage?)
    assert policy.apply(:show?)

    policy2 = AdminTestPolicy.new nil, user: guest

    assert policy2.apply(:index?)
    assert policy2.apply(:manage?)
    refute policy2.apply(:show?)
  end

  def test_skip_only_pre_check_with_except
    policy = TestPolicy.new true, user: User.new("Neil")

    refute policy.apply(:index?)
    refute policy.apply(:new?)
    assert policy.apply(:manage?)

    policy2 = AdminTestPolicy.new true, user: User.new("Neil")

    assert policy2.apply(:index?)
    refute policy2.apply(:new?)
    assert policy2.apply(:manage?)
    assert policy2.apply(:show?)
  end
end
