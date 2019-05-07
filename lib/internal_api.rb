# frozen_string_literal: true

require 'internal_api/version'
require 'internal_api/full_method_source_location'
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

  LoaderMutex = Mutex.new

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
    calculate_public_methods!(protector)

    # Extract the eigenclass of any object
    # https://medium.com/@ethan.reid.roberts/rubys-anonymous-eigenclass-putting-the-ei-in-team-ebc1e8f8d668
    eigenclass = (class << protectee; self; end)

    # Rewrite future public singleton methods
    Rewriter.add_singleton_rewrite_hooks!(protectee, protector)
    # Rewrite eigenclass' future public instance methods
    Rewriter.add_instance_rewrite_hooks!(eigenclass, protector)
    # Rewrite eigenclass' future public singleton methods
    Rewriter.add_singleton_rewrite_hooks!(eigenclass, protector)
  end

  def check_caller!(protector)
    allowed_caller_methods = InternalApi.public_method_cache[protector]
    # NB: `caller` is much slower than `caller_locations`
    caller_locations.each do |location|
      # This calculation is quadratic but as the backtrace is finite and these
      # comparisons take only tens of nanoseconds each this is fast enough for
      # production use.
      allowed_caller_methods.each do |path, range|
        if location.path == path && range.include?(location.lineno)
          return path, range
        end
      end
    end
    raise_violation!(caller_locations[1].label, protector)
  end

  def rewrite_method!(protectee, internal_method, protector)
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

  def public_method_cache
    @public_method_cache ||= {}
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

  def calculate_public_methods!(mod)
    LoaderMutex.synchronize do
      return if InternalApi.public_method_cache.key?(mod)

      # We cache the public methods because this requires a fairly exhaustive,
      # recursive lookup of Ruby method hierarchy to perform:
      #
      # https://github.com/ruby/ruby/blob/c3cf1ef9bbacac6ae5abc99046db173e258dc7ca/class.c#L1206-L1238
      #
      # > Benchmark.measure { 10_000.times { Object.new }}.real
      # => 0.0033939999993890524
      # >> Benchmark.measure { 10_000.times { Object.public_methods }}.real
      # => 0.1327720000408589800
      #
      # It's up to the user to avoid adding new public methods to the protected
      # code after app initialization.

      source_ranges = FullMethodSourceLocation.public_method_source_ranges(mod)
      unless source_ranges
        raise InternalApi::UnreachableCodeError,
              "#{self} is protected by #{protector}," \
              ' which has no public methods'
      end

      InternalApi.public_method_cache[mod] = source_ranges
    end
  end
end

# Make this generally available
Module.include InternalApi::RubyCoreExtension
Class.include InternalApi::RubyCoreExtension

# Time to #dogfood.
# Protect the internal parts of InternalAPI
# InternalApi.internal_api(InternalApi::RubyCoreExtension)
