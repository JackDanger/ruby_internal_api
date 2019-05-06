# frozen_string_literal: true

require 'internal_api/version'

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
  module ClassMacro
    def internal_api(_mod_class_or_module)
      InternalApi.protect(self, protector_class_or_module)
    end
  end

  # Rewrites all public methods on the protectee (the Ruby class or module that
  # received the 'internal_api' message), replacing them with a method that
  # checks the backtrace and ensures at least one line matches one of the
  # public methods of the protector.
  def protect(protectee, protector)
    calculate_public_methods!(protector)

    rewrite!(protectee, protector)
  end

  def check!(protector)
    allowed_caller_methods = InternalApi.public_method_cache[protector]
    # NB: `caller` is much slower than `caller_locations`
    caller_locations.each do |location|
      # This calculation is quadratic but as the backtrace is finite and these
      # comparisons take only tens of nanoseconds each this is fast enough for
      # production use.
      allowed_caller_methods.each do |path, lineno|
        return nil if location.path == path && location.lineno == lineno
      end
    end
    raise InternalApi::ViolationError,
          "Only `#{protector.name}` methods can execute #{protector.name} code"
  end

  private

  def rewrite!(protectee, protector)
    # We protect both the public class methods and public instance methods on
    # the internal code
    protectee.public_instance_methods.each do |internal_method|
      rewrite_method!(protectee, internal_method, protector)
    end
    protectee.public_methods.each do |internal_method|
      rewrite_method!(eigenclass(protectee), internal_method, protector)
    end
  end

  def rewrite_method!(protectee, internal_method, protector)
    protectee.instance_eval do
      # We create a new pointer to the original method
      alias_method "_internal_api_#{internal_method}"

      # And overwrite it
      define_method internal_method do |*args, &block|
        InternalApi.check!(protector)
        send("_internal_api_#{internal_method}", *args, &block)
      end
    end
  end

  def calculate_public_methods!(mod)
    LoaderMutex.lock do
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
      InternalApi.public_method_cache[mod] = all_public_method_locations(mod)
    end
  end

  # Find the path and line numbers of all public class methods and public
  # instance methods
  def all_public_method_locations(mod)
    class_locs = mod.public_methods.map do |m|
      mod.method(m).source_location
    end.compact
    instance_locs = mod.public_instance_methods.map do |m|
      mod.instance_method(m).source_location
    end.compact
    (class_locs + instance_locs).map do |location|
      [location.path, location.lineno]
    end
  end

  # Extract the eigenclass of any object
  # https://medium.com/@ethan.reid.roberts/rubys-anonymous-eigenclass-putting-the-ei-in-team-ebc1e8f8d668
  def eigenclass(obj)
    class << obj
      self
    end
  end
end
