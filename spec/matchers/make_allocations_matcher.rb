require 'rspec/expectations'

RSpec::Matchers.define :make_allocations do |expected|
  supports_block_expectations

  match do |block|
    stats = AllocationStats.trace do
      block.call
    end

    @allocations = stats.allocations.to_a.size
    @allocations == expected
  end

  failure_message do |_|
    "expected that block would make #{expected} allocations but made #{@allocations}"
  end
end
