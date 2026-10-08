# frozen_string_literal: true

# 09. Tests and debugging, the code side. `:e!` undoes.
#
# 1. `<Space>ta` opens this file's test (test/calculator_test.rb) and
#    `<Space>ta` there comes back here. `<Space>tA` opens the pair in a
#    vertical split.
# 2. From here, `<Space>tf` runs the matching test file.
# 3. Breakpoint. On the `quotient = a / b` line, `<Space>rb` sets one.
#    `<Space>rB` sets one with a condition (for example `b == 0`). Then go to
#    the test and carry on there.
class Calculator
  def add(a, b)
    a + b
  end

  def divide(a, b)
    quotient = a / b
    quotient.round(2)
  end

  def average(values)
    return 0 if values.empty?

    values.sum / values.size
  end
end
