# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
# rubocop:disable Metrics/LineLength

module Protector
  extend self

  def class_instance_write(line)
    ProtectedClass.new.instance_write(line)
  end

  def class_singleton_write(line, &block)
    ProtectedClass.singleton_write(line, &block)
  end

  def module_singleton_write(line)
    ProtectedModule.singleton_write(line)
  end

  def module_instance_write(line)
    ProtectedModule.instance_write(line)
  end
end

class ProtectedClass
  internal_api Protector

  def instance_write(line)
    line
  end

  def self.singleton_write(line)
    if block_given?
      "log: #{yield line}"
    else
      line
    end
  end
end

module ProtectedModule
  extend self

  internal_api Protector

  def instance_write(line)
    line
  end

  def self.singleton_write(line)
    line
  end
end

RSpec.describe InternalApi do
  it 'preserves arguments and block passing' do
    expect(
      Protector.class_singleton_write("this should have a 'log: ' prefix and") do |line|
        line + ' this suffix'
      end
    ).to eq("log: this should have a 'log: ' prefix and this suffix")
  end

  context 'when protecting classes' do
    context 'instance methods' do
      it 'throws errors when accessed directly' do
        expect do
          ProtectedClass.new.instance_write("shouldn't go through")
        end.to raise_error(
          InternalApi::ViolationError,
          '"block (5 levels) in <top (required)>" is protected by `Protector` and can only execute when a `Protector` method is in the backtrace'
        )
      end

      it 'permits access through the specified API' do
        expect(Protector.class_instance_write('works')).to eq('works')
      end
    end

    context 'class methods' do
      it 'throws errors when accessed directly' do
        expect do
          ProtectedClass.singleton_write("shouldn't go through")
        end.to raise_error(
          InternalApi::ViolationError,
          '"block (5 levels) in <top (required)>" is protected by `Protector` and can only execute when a `Protector` method is in the backtrace'
        )
      end

      it 'permits access through the specified API' do
        expect(Protector.class_singleton_write('works')).to eq('works')
      end
    end
  end

  context 'when protecting modules' do
    context 'instance methods' do
      it 'throws errors when accessed directly' do
        expect do
          ProtectedModule.instance_write("shouldn't go through")
        end.to raise_error(
          InternalApi::ViolationError,
          '"block (5 levels) in <top (required)>" is protected by `Protector` and can only execute when a `Protector` method is in the backtrace'
        )
      end

      it 'permits access through the specified API' do
        expect(Protector.module_instance_write('works')).to eq('works')
      end
    end

    context 'class methods' do
      it 'throws errors when accessed directly' do
        expect do
          ProtectedModule.singleton_write("shouldn't go through")
        end.to raise_error(
          InternalApi::ViolationError,
          '"block (5 levels) in <top (required)>" is protected by `Protector` and can only execute when a `Protector` method is in the backtrace'
        )
      end

      it 'permits access through the specified API' do
        expect(Protector.module_singleton_write('works')).to eq('works')
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
# rubocop:enable Metrics/LineLength
