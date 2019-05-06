# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength

class Protector
  def write(line)
    ProtectedClass.new.write(line)
  end

  def self.log(*args, &block)
    ProtectedClass.log(args, &block)
  end

  def write_to_module(line)
    ProtectedModule.write(line)
  end
end

class ProtectedClass
  internal_api Protector
  attr_reader :written

  def write(line)
    @written ||= []
    @written << line
  end

  def self.log(line)
    yield "log: #{line}"
  end
end

module ProtectedModule
  internal_api Protector

  def write(line)
    line
  end
end

RSpec.describe InternalApi do
  it 'prevents direct calling of methods on Protected' do
    expect do
      Protected.new.write("shouldn't go through")
    end.to raise(
      InternalApi::ViolationError,
      'Only `Protector` methods can execute Protector code.'
    )
  end

  it 'preserves arguments and block passing' do
    expect do
      Protected.log("this should have a 'log: ' prefix and") do |line|
        line + ' this suffix'
      end
    end.to be("log: this should have a 'log: ' prefix and this suffix")
  end

  context 'when protecting modules' do
    # Ruby's `Class.is_a?(Module)` so we get this for free. Adding a test to
    # catch future regressions.
    it 'works just like when protecting classes' do
      expect do
        ProtectedModule.write("shouldn't go through")
      end.to raise(
        InternalApi::ViolationError,
        'Only `Protector` methods can execute Protector code.'
      )

      expect do
        Protected.new.write_to_module('works')
      end.to eq('works')
    end
  end

  describe '.internal_api' do
    it 'requires an argument' do
      expect do
        Protected.internal_api
      end.to raise_error(
        ArgumentError,
        'internal_api requires a module or class argument'
      )
    end
  end
end
# rubocop:enable Metrics/BlockLength
