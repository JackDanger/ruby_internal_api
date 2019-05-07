# frozen_string_literal: true

require 'method_source'
module InternalApi
  # Ruby gives us the start location of a method but not the end. We need to
  # know the full range so we can verify any calls made anywhere in a method
  # have originated from that method.
  #
  # We lean on the MethodSource gem (the library underneath Pry's method
  # inspection) for this as it does some wild trickery with attempting to
  # parse raw Ruby code without actually using a parser.
  module FullMethodSourceLocation
    extend self

    def range(method)
      source_location = method.source_location
      return unless source_location

      path, start = source_location

      source = MethodSource.source_helper(source_location)
      [path, (start..(start + source.lines.size - 1))]
    end

    # Find the file path and the start and end line numbers of all public class
    # methods and public instance methods
    def public_method_source_ranges(mod)
      class_ranges = mod.public_methods(false).map do |m|
        FullMethodSourceLocation.range(mod.method(m))
      end.compact
      instance_ranges = mod.public_instance_methods(false).map do |m|
        FullMethodSourceLocation.range(mod.instance_method(m))
      end.compact
      class_ranges + instance_ranges
    end
  end
end
