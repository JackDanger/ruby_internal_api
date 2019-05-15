module InternalApi
  module ExclusionList
    extend self

    def allowed_backtrace?(protector, backtrace)
      allowed_caller_methods = PublicMethodCache.get(protector)
      return unless allowed_caller_methods

      backtrace.each do |location|
        # This calculation is quadratic but as the backtrace is finite and these
        # comparisons take only tens of nanoseconds each this is fast enough for
        # production use.
        allowed_caller_methods.each do |path, range|
          if location.path == path && range.include?(location.lineno)
            return path, range
          end
        end
      end
      false
    end
  end
end
