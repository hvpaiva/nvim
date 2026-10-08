# frozen_string_literal: true

# 03. Editing. `:e!` undoes everything.

# 1. `.` repeats the whole last change. Cursor on `old_name`, `ciw`,
#    `new_name`, `<Esc>`. Go to the next `old_name` with `w` and press `.`.
def dot_repeat
  [old_name, old_name, old_name]
end

# 2. `cgn`. Cursor on `amount`, `*` (searches the word), `N` (back to the
#    first one), `cgn`, `value`, `<Esc>`. Now `.` changes the next one; `n`
#    skips one without changing it.
def change_next(order)
  order.amount + order.tax_amount * order.amount.to_f + order.amount.abs
end

# 3. `<Space>S`. Cursor on `customer` below, `<Space>S` opens a
#    `:%s/\<customer\>/customer/gI` already filled in, with the cursor on the
#    replacement. Delete it, type `client` and watch the live preview in the
#    split before `<CR>`. The `%` covers the whole file, so this comment
#    changes too; `customer_id` does not, because of `\<` and `\>`.
def substitute_word(customer)
  customer.name + customer.email + customer_id(customer)
end

# 4. Smart case in `:s`. Inside the module, `vaM` (or `vac`), then
#    `:s/pending/queued/g`. The uppercase constant changes too, because
#    `ignorecase` + `smartcase` ignore case in an all-lowercase pattern. `u`
#    and repeat with `\C`, which makes case count.
module OrderStatus
  PENDING = "pending"
  TRANSITIONS = {pending: [:paid, :cancelled]}.freeze

  def self.pending?(status)
    status.to_s == PENDING
  end
end

# 5. `:g`. To add `.freeze` only to the lines with a string, select the
#    constants below with `vip` and run `:'<,'>g/"/normal A.freeze`.

SHIPPED = "shipped"
LIMIT = 10
DELIVERED = "delivered"
RETRIES = 3

# 6. Macro. On the first line below, `qa`, `I`, `STATUS_`, `<Esc>`, `j`, `q`.
#    Then `@a` applies it to the next line and `@@` repeats the last one.
#    `2@a` does two at once. The macro lives in register `a`, and `:reg a`
#    shows it. The `"` popup describes only the special registers, not the
#    letters.

CANCELLED_AT = :cancelled_at
REFUNDED_AT = :refunded_at
ARCHIVED_AT = :archived_at
DELETED_AT = :deleted_at

# 7. Visual block. On the `S` of `SHIPPED_AT`, `<C-v>`, `3j` (three lines
#    down), `I`, `ORDER_`, `<Esc>`. To write at the end of lines of different
#    lengths, `<C-v>`, `3j`, `$`, `A`, ` # ts`, `<Esc>`.
SHIPPED_AT = :shipped_at
DELIVERED_AT = :delivered_at
RETURNED_AT = :returned_at
PAID_AT = :paid_at

# 8. mini.move. Cursor on the `third` line, `<M-k>` moves the line up and
#    `<M-j>` down. With `Vj` (two lines selected), `<M-j>` moves both. `<M-h>`
#    and `<M-l>` change the indentation.
def move_lines
  first = 1
  third = 3
  second = 2
  first + second + third
end

# 9. Indent and keep the selection. `Vj` on the two `indent_me` lines and
#    `>`. The selection stays active, so `>` again indents one more level.
def keep_selection
  indent_me = 1
  indent_me + 1
end

# 10. `J` joins lines without moving the cursor. On the `[` line, `J` three
#     times.
def join_lines
  [
    1,
    2
  ]
end

# 11. Paste over without losing the register. `yiw` on `keep`, then `viw` on
#     `drop1` and `p`; `viw` on `drop2` and `p` again. Both become `keep`.
def paste_over
  [keep, drop1, drop2]
end

# 12. `]p` and `[p`. `yiw` on `inserted`, then `]p`, and the word goes on a
#     new line below, already indented. `[p` puts it above.
def linewise_paste
  inserted = :x
  [inserted]
end

# 13. Delete without copying. `yiw` on `precious`. On the `trash = 0` line,
#     `<Space>dd` deletes the line without touching the register. `p` still
#     pastes `precious`.
def black_hole
  precious = 1
  trash = 0
  precious + trash
end

# 14. Numbers. Cursor on `41`, `<C-a>` adds 1 and `<C-x>` subtracts.
#     `10<C-a>` adds 10. On the line of the first zero, `V3j` and `g<C-a>`
#     turn the zeros into 1, 2, 3, 4. (With `<C-v>` at column 0, the block
#     takes only the indentation and nothing changes.)
def numbers
  answer = 41
  sequence = [
    0,
    0,
    0,
    0
  ]
  [answer, sequence]
end

# 15. Case. On `shout`, `gUiw` makes it uppercase, `guiw` lowercase and `~`
#     toggles one character.
def case_change = :shout

# 16. Undo. Make three different edits, then `<Space>ou` opens undotree with
#     the diff of each state. `[u` and `]u` move through the undo states
#     without opening anything.

# 17. Registers in Insert mode. After copying something, enter Insert mode
#     and press `<C-r>`. mini.clue lists the registers; type the letter to
#     paste.
