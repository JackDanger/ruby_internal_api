# When we need to enumerate the public methods of an object we cache the
# result.
#
# Finding all the methods requires a fairly exhaustive, recursive lookup
# of Ruby method hierarchy to perform:
#
# https://github.com/ruby/ruby/blob/c3cf1ef9bbacac6ae5abc99046db173e258dc7ca/class.c#L1206-L1238
#
# > Benchmark.measure { 10_000.times { Object.new }}.real
# => 0.0033939999993890524
# >> Benchmark.measure { 10_000.times { Object.public_methods }}.real
# => 0.1327720000408589800
#
# It's up to the user to ensure the objects used as API boundaries have
# their public methods defined statically so they get picked up by this.
module InternalApi
  module PublicMethodCache

    extend self

    LoaderMutex = Mutex.new

    def get(object)
      LoaderMutex.synchronize { cache[object] || set!(object) }
    end

    def set!(object)
      cache[object] = public_methods_of(object)
    end

    private

    def public_methods_of(obj)
      source_ranges = FullMethodSourceLocation.public_method_source_ranges(obj)
      unless source_ranges
        raise InternalApi::UnreachableCodeError,
              "#{protector} has no public methods"
      end

      source_ranges
    end

    def cache
      @cache ||= {}
    end
  end
end
