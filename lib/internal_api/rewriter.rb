# frozen_string_literal: true

module InternalApi
  # This uses the built-in Ruby callbacks for when new methods are defined:
  # https://github.com/ruby/ruby/blob/c3cf1ef9bbacac6ae5abc99046db173e258dc7ca/object.c#L940-L954
  module Rewriter
    extend self

    # rubocop:disable Metrics/MethodLength
    SKIP_PATTERN = /(^_internal_api)|(^(singleton_)?method_added$)/.freeze
    def add_instance_rewrite_hooks!(protectee, protector)
      protectee.class_eval do
        define_method(:method_added) do |method_name|
          return unless InternalApi::Rewriter.should_overwrite?(
            method_name,
            instance_methods,
            public_instance_methods
          )

          InternalApi.debug "#{self}##{method_name} protected by #{protector}"
          InternalApi.rewrite_method!(self, method_name, protector)
        end
      end
    end

    def add_singleton_rewrite_hooks!(protectee, protector)
      protectee.class_eval do
        define_method(:singleton_method_added) do |method_name|
          return unless InternalApi::Rewriter.should_overwrite?(
            method_name,
            methods,
            public_methods
          )

          eigen = (class << self; self; end)
          InternalApi.debug "#{eigen}.#{method_name} protected by #{protector}"
          InternalApi.rewrite_method!(eigen, method_name, protector)
        end
      end
    end
    # rubocop:enable Metrics/MethodLength

    def should_overwrite?(method_name, methods, public_methods)
      # Don't interfere with the metaprogramming
      return false if method_name.to_s =~ SKIP_PATTERN
      # And definitely don't try to do this twice
      return false if methods.include?("_internal_api_#{method_name}".to_sym)

      public_methods.include?(method_name)
    end
  end
end
