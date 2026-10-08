# frozen_string_literal: true

# 04. Surround, split/join, align and comment. `:e!` undoes everything.

# 1. Replace. Cursor inside `'hello world'`, `sr'"` swaps the quotes. The
#    Standard warning on the line goes away.
GREETING = 'hello world'

# 2. Delete. Cursor inside the parentheses, `sd(` removes the pair.
TOTAL = (price * quantity)

# 3. Add. Cursor on `customer_id`, `saiw"` surrounds the word with quotes.
#    `saiw(` surrounds it with parentheses and `saiw[` with brackets.
OWNER = customer_id

# 4. Function. Cursor on `value`, `saiwf`, type `Integer` and `<CR>`, and it
#    becomes `Integer(value)`. Then, inside it, `sdf` removes the call and
#    leaves only the argument.
AMOUNT = value

# 5. Next and last. With the cursor at the start of the line (outside the
#    quotes), `sdn'` deletes the next single quotes and `srn'"` turns the next
#    ones into double quotes. `l` in place of `n` uses the previous ones.
FAREWELL = 'see you soon'

# 6. Find and highlight. Cursor at the start of the line, `sf"` jumps to the
#    next quotes and `sF"` to the previous ones. `sh(` flashes the surrounding
#    parentheses.
REPORT = build_report("monthly", format: :csv)

# 7. treesj's split/join. Cursor on the `{ |item| ... }` block below, `gS`
#    turns it into `do ... end`. `gS` again turns it back.
def block_toggle(items)
  items.map { |item| item * 2 }
end

# 8. Cursor on any word of the `return ... if ...` below, `gS` turns it into
#    `if ... end`, and back. In the indentation, the node under the cursor is
#    the method, and `gS` joins the whole method into one line (`:e!`
#    undoes).
def modifier_toggle(value)
  return :empty if value.nil?

  value
end

# 9. `gS` on the hash and on the array puts one item per line, with no
#    trailing comma (as Standard wants). `gS` again joins them.
CONFIG = {name: "Downtown", currency: "BRL", tags: ["retail", "food", "bakery"]}.freeze

# 10. Align. Cursor on a constant, `gaip=` aligns the paragraph's `=`. `gAip`
#     does the same with an interactive preview (type `=` and watch).

LOW = 1
MEDIUM_HIGH = 2
TOP = 3

# 11. Comment. `gcc` comments the line. `gcip` comments the paragraph. With
#     the lines commented, `dgc` deletes the whole comment block.

COMMENT_ME = :first
COMMENT_ME_TOO = :second

# 12. mini.pairs. Open a line (`o`) and type `call(` and `"`, and the closing
#     ones go in by themselves. Typing the `)` steps over the one already
#     there.
