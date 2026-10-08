# frozen_string_literal: true

# 10. REPL. irb runs in a split below, with the project's Ruby (through mise).

# 1. `<Space>ii` opens irb (or shows it, if it is already open). Focus comes
#    back here.
# 2. Cursor on the `prices = ...` line, `<Space>il` sends only that line.
prices = [1990, 4500, 1250]

# 3. Cursor inside the method below, `<Space>ip` sends the whole paragraph
#    (the block up to the blank line). It arrives whole, not line by line.
def average(values)
  values.sum.fdiv(values.size)
end

# 4. Select `average(prices).round(2)` with `v` and send it with `<Space>i`.
puts average(prices).round(2)

# 5. To go to irb, `<C-w>j`; `i` to type; `<C-\><C-n>` back to the terminal's
#    Normal mode; `<C-w>k` comes back here.
