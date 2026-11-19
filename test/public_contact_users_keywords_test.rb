# frozen_string_literal: true

require "test_helper"

class PublicContactUsersKeywordsTest < Minitest::Test
  def test_older_users_methods_are_called_without_source_or_session
    starts = []
    proofs = []
    with_users_methods(start: listed_start(starts), proof: listed_proof(proofs)) do
      send_code_and_prove
    end

    assert_equal "ada@example.com", starts.first[:email]
    refute starts.first.key?(:source)
    assert_equal "challenge-1", proofs.first[:challenge_id]
    refute proofs.first.key?(:session)
  end

  def test_forwarding_users_before_0_39_omits_source_and_session
    starts = []
    proofs = []
    with_users_version("0.32.0") do
      with_users_methods(start: forwarding_start(starts), proof: forwarding_proof(proofs)) do
        send_code_and_prove
      end
    end

    refute starts.first.key?(:source)
    refute proofs.first.key?(:session)
  end

  def test_forwarding_users_0_39_passes_source_and_session
    starts = []
    proofs = []
    with_users_version("0.39.0") do
      with_users_methods(start: forwarding_start(starts), proof: forwarding_proof(proofs)) do
        send_code_and_prove
      end
    end

    assert_equal({ campaign: "spring" }, starts.first[:source])
    assert_equal({ campaign: "spring" }, proofs.first[:session])
  end

  private

  def send_code_and_prove
    contact = RecordingStudioMessages::PublicContact
    contact.send(:send_challenge!, "ada@example.com", Object.new, source: { campaign: "spring" })
    contact.send(:prove_email!, proof_actor, proof_intent, { campaign: "spring" })
  end

  def proof_actor
    actor = Object.new
    actor.define_singleton_method(:reload) { actor }
    actor.define_singleton_method(:confirmed?) { true }
    actor
  end

  def proof_intent
    Struct.new(:otp_challenge_id, :submitted_name).new("challenge-1", "Ada Lovelace")
  end

  def listed_start(calls)
    code = issued_code
    lambda { |request:, email:, return_to: nil, popup: nil|
      calls << { request: request, email: email, return_to: return_to, popup: popup }
      code
    }
  end

  def listed_proof(calls)
    lambda { |user:, challenge_id:, profile_attributes: {}|
      calls << { user: user, challenge_id: challenge_id, profile_attributes: profile_attributes }
      user
    }
  end

  def forwarding_start(calls)
    code = issued_code
    lambda { |**kwargs|
      calls << kwargs
      code
    }
  end

  def forwarding_proof(calls)
    lambda { |**kwargs|
      calls << kwargs
      kwargs.fetch(:user)
    }
  end

  def issued_code
    result = Object.new
    result.define_singleton_method(:issued?) { true }
    result.define_singleton_method(:throttled?) { false }
    result
  end

  def with_users_version(version)
    original = Gem.loaded_specs["recording_studio_user"]
    Gem.loaded_specs["recording_studio_user"] = Gem::Specification.new("recording_studio_user", version)
    yield
  ensure
    if original
      Gem.loaded_specs["recording_studio_user"] = original
    else
      Gem.loaded_specs.delete("recording_studio_user")
    end
  end

  def with_users_methods(start:, proof:)
    created = false
    unless defined?(RecordingStudioUser)
      Object.const_set(:RecordingStudioUser, Module.new)
      created = true
    end
    owner = RecordingStudioUser.singleton_class
    originals = remembered_methods(owner)
    owner.define_method(:start_otp_challenge!, start)
    owner.define_method(:complete_email_proof!, proof)
    yield
  ensure
    restore_users_module(created, owner, originals)
  end

  def remembered_methods(owner)
    %i[start_otp_challenge! complete_email_proof!].each_with_object({}) do |name, remembered|
      next unless owner.method_defined?(name) || owner.private_method_defined?(name)

      remembered[name] = owner.instance_method(name)
    end
  end

  def restore_users_module(created, owner, originals)
    return Object.send(:remove_const, :RecordingStudioUser) if created

    restore_method(owner, :start_otp_challenge!, originals)
    restore_method(owner, :complete_email_proof!, originals)
  end

  def restore_method(owner, name, originals)
    return if owner.nil?

    if originals[name]
      owner.define_method(name, originals[name])
    else
      owner.send(:remove_method, name)
    end
  end
end
