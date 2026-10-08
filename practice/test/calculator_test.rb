# frozen_string_literal: true

# 09. Tests and debugging, the test side. `:e!` undoes.
#
# 1. Cursor inside `test_add`, `<Space>tt` runs only that test in a terminal
#    below (the same terminal is reused). `<Space>tf` runs the file,
#    `<Space>ts` the suite, `<Space>tl` repeats the last run and `<Space>tv`
#    goes back to the last test run.
# 2. `test_average` fails on purpose, since the average of 1 and 2 comes out
#    as 1 by integer division. Run it, read the failure, fix it in
#    lib/calculator.rb (`fdiv`) and `<Space>tl`.
# 3. Code lenses. Above each `def test_`, ruby-lsp shows actions (Run, Run In
#    Terminal, Debug). Cursor on the `def` line, `gl` picks one.
# 4. Debugging. With a breakpoint in lib/calculator.rb (`<Space>rb`), cursor
#    in `test_divide`, `<Space>rt` debugs that test. It stops first at the
#    file's entry (`stopOnEntry`); `<Space>rr` continues to the breakpoint.
#    Stopped there, `<Space>rn` runs the next line, `<Space>ri` steps in,
#    `<Space>ro` steps out, `<Space>re` on `quotient` shows its value,
#    `<Space>rs` shows the scopes, `<Space>rc` opens the console,
#    `<Space>rr` continues and `<Space>rq` stops. `<Space>rl` repeats the
#    last session.

require "minitest/autorun"
require_relative "../lib/calculator"

class CalculatorTest < Minitest::Test
  def setup
    @calc = Calculator.new
  end

  def test_add
    assert_equal 5, @calc.add(2, 3)
  end

  def test_divide
    assert_in_delta 3.33, @calc.divide(10.0, 3), 0.01
  end

  def test_average
    assert_in_delta 1.5, @calc.average([1, 2]), 0.001
  end
end
