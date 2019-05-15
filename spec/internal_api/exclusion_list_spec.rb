# frozen_string_literal: true

RSpec.describe InternalApi::ExclusionList do

  class ProtectorClass
    def a_public_method
    end
  end

  # Emulate the behavior of Thread::Backtrace::Location instances (the return
  # values of `caller_locations`) but with a constructor.
  class Location < BasicObject
    attr_reader :path, :lineno

    def initialize(path, lineno)
      @path = path
      @lineno = lineno
    end

    def self.from_filename_and_line_pairs(*pairs)
      pairs.map { |pair| new(*pair) }
    end
  end

  describe '.allowed_backtrace?' do
    subject(:allowed_backtrace?) { described_class.allowed_backtrace?(protector, backtrace) }

    let(:protector) { ProtectorClass }

    context 'when the protector is found in the backtrace' do
      let(:backtrace) do
        Location.from_filename_and_line_pairs(
          ['/somewhere.rb', 9],
          [__FILE__, 6],
          ['/somewhere/else.rb', 120],
        )
      end

      it { expect(allowed_backtrace?).to be_truthy }
    end

    context 'when the protector is not found in the backtrace' do
      let(:backtrace) do
        Location.from_filename_and_line_pairs(
          ['/somewhere.rb', 9],
          [__FILE__, 15],  # wrong line number
          ['/somewhere/else.rb', 120],
        )
      end

      it { expect(allowed_backtrace?).to be_falsy }
    end
  end
end
