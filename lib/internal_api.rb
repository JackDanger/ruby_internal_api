# frozen_string_literal: true

require 'internal_api/exclusion_list'
require 'internal_api/full_method_source_location'
require 'internal_api/public_method_cache'
require 'internal_api/rewriter'

# The InternalApi module provides one public method (`.internal_api`) available
# on any Ruby module.
# This method takes as its single argument any object has public methods. When
# called, the (public) methods of the caller will no longer be directly
# accessible.
#
# This is deliberately designed to not depend on any gems, C-extensions, or any
# Ruby features specific to a minor version.
module InternalApi
  extend self

  # ViolationError is raised when protected code is called from code not behind
  # the internal api
  class ViolationError < StandardError; end

  # This is the only public API method
  module RubyCoreExtension
    def internal_api(protector)
      InternalApi.protect(self, protector)
    end
  end

  # Rewrites all public methods on the protectee (the Ruby class or module that
  # received the 'internal_api' message), replacing them with a method that
  # checks the backtrace and ensures at least one line matches one of the
  # public methods of the protector.
  def protect(protectee, protector)
    PublicMethodCache.set!(protector)

    # Extract the eigenclass (the class on which `def self.x; end` would be
    # defined) of any object
    # https://medium.com/@ethan.reid.roberts/rubys-anonymous-eigenclass-putting-the-ei-in-team-ebc1e8f8d668
    eigenclass = (class << protectee; self; end)

    # Rewrite eigenclass' future public instance methods
    Rewriter.add_instance_rewrite_hooks!(eigenclass, protector)
    # Rewrite eigenclass' future public singleton methods
    Rewriter.add_singleton_rewrite_hooks!(eigenclass, protector)
  end

  def check_caller!(protector)
    # NB: `caller_locations` is much faster than `caller`
    unless ExclusionList.allowed_backtrace?(protector, caller_locations)
      raise_violation!(caller_locations[1].label, protector)
    end
  end

  def rewrite_method!(protectee, internal_method, protector)
    PublicMethodCache.set!(protector)
    protectee.instance_eval do
      # We create a new pointer to the original method
      alias_method "_internal_api_#{internal_method}", internal_method

      # And overwrite it
      define_method internal_method do |*args, &block|
        InternalApi.check_caller!(protector)
        send("_internal_api_#{internal_method}", *args, &block)
      end
    end
  end

  def debug(line)
    puts "InternalApi: #{line}" if $DEBUG
  end

  private

  def raise_violation!(label, protector)
    message = "#{label.inspect} is protected by `#{protector.name}`" \
              " and can only execute when a `#{protector.name}`" \
              ' method is in the backtrace'
    raise InternalApi::ViolationError, message
  end
end

# Make this generally available
Module.include InternalApi::RubyCoreExtension
Class.include InternalApi::RubyCoreExtension

# Time to #dogfood.
# Protect the internal parts of InternalAPI
# InternalApi.internal_api(InternalApi::RubyCoreExtension)
