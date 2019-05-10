# frozen_string_literal: true

RSpec.describe InternalApi::FullMethodSourceLocation do
  class Helper
    def with_a_method
      [
        'this',
        'method',
        'has',
        'seven',
        'lines',
      ]
    end
  end

  it 'finds the correct, full range of a method definition' do
    expect(described_class.range(Helper.instance_method(:with_a_method))).to eq([__FILE__, (5..13)])
  end
end
