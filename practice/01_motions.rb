# frozen_string_literal: true

# 01. Motions. Each exercise sits right above its target. `:e!` undoes.

# 1. The gutter shows relative line numbers. From here, read the number of the
#    `target` line below and use `{n}j` to land on it in one go. `{n}k` goes
#    back.
def relative_numbers
  [:noise, :noise, :noise, :noise, :target]
end

# 2. mini.jump. At the start of the `call` line below, `f(` goes to the first
#    `(`. Press `f` again (without the `(`): it moves on to the next one, on
#    the lines below too. `;` repeats as well. `t` and `T` stop one short.
def mini_jump
  call(one(two(three)))
  again(four(five))
end

# 3. mini.jump2d. Press `<CR>`: the start of every visible word gets a label.
#    Type the label of `landing` to jump straight there.
def jump2d
  [:alpha, :beta, :gamma, :landing, :delta]
end

# 4. `%` jumps between the opening and the closing parenthesis of the line
#    below.
def pairs
  total_for(orders.map { |order| order[:price] * (order[:qty] + 1) })
end

# 5. `}` and `{` move by paragraph (a block separated by a blank line).
#    `<C-d>` and `<C-u>` move half a screen down and up, and recenter.

# 6. Cursor on `amount` below, `*` searches the word, and `n` / `N` move
#    through the matches, always centering. `<C-c>` clears the search
#    highlight.
def search_word(order)
  order.amount + order.tax_amount + order.amount.abs
end

# 7. Marks. On the `mark_here` line, `ma`: the `a` shows in the gutter. Go
#    somewhere else and come back with `'a` (the line) or `` `a `` (the exact
#    position). Press `'` and wait: mini.clue lists the marks. `:delm a`
#    deletes it. On a line with a diagnostic, its dot covers the letter.
def marks
  :mark_here
end

# 8. Jumplist and changelist. After a few jumps (`gg`, `G`, `*`), `<C-o>` goes
#    back and `<C-i>` forward. `[j` and `]j` move through this buffer's jumps
#    only. After editing in two places, `g;` and `g,` move through the
#    changes.

# 9. mini.bracketed in the method below. `]i` and `[i` leave the block: they
#    go to the first line indented less than the cursor's. With the cursor on
#    `item.call`, `[i` goes up to the `if` and, repeated, to `items.each` and
#    the `def`. `]i` goes down through the `end`s the same way. On a line at
#    column 0 there is nowhere to go. `]c` and `[c` jump between comment
#    blocks. `]t` goes to the end of the tree-sitter node under the cursor
#    and, repeated, to the end of its parent (`[t` goes to the start).
def bracketed(items)
  # first comment block
  items.each do |item|
    next unless item

    # second comment block
    if item.respond_to?(:call)
      item.call
    end
  end
end

# 10. Methods and classes, from Ruby's ftplugin. From here, `]m` goes to the
#     next `def` and `[m` to the previous one; `]M` and `[M` do the same with
#     each method's `end`. `]]` and `[[` move between `module` and `class`,
#     `][` and `[]` between their `end`s. In any language with tree-sitter,
#     `g]F` goes to the end of the method under the cursor (or the next one)
#     and `g[F` to its start.
module Billing
  class Invoice
    def total
      10
    end

    def tax
      1
    end
  end

  class Receipt
    def print
      puts "receipt"
    end
  end
end

# 11. treesitter-context. Put the cursor on the `step_12` line and press `zt`
#     (line at the top of the screen). `def long_method` leaves the screen but
#     stays pinned at the top as a header.
def long_method
  step_1 = 1
  step_2 = step_1 + 1
  step_3 = step_2 + 1
  step_4 = step_3 + 1
  step_5 = step_4 + 1
  step_6 = step_5 + 1
  step_7 = step_6 + 1
  step_8 = step_7 + 1
  step_9 = step_8 + 1
  step_10 = step_9 + 1
  step_11 = step_10 + 1
  step_12 = step_11 + 1
  step_13 = step_12 + 1
  step_14 = step_13 + 1
  step_14 + 1
end

# 12. Folds. Folding follows indentation: `zc` closes the block under the
#     cursor, `zo` opens it, `za` toggles it. `zM` closes everything and `zR`
#     opens everything. `zj` and `zk` move between folds.
