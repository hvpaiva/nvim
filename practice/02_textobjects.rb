# frozen_string_literal: true

# 02. mini.ai text objects. `v` + an object shows the selection first; swap
# `v` for `d`, `c` or `y` to act. `:e!` undoes.

# 1. Cursor inside the method below. `vaF` selects the whole method and `viF`
#    only its body. `daF` deletes it.
def checkout(cart)
  total = cart.sum { |line| line[:price_cents] * line[:quantity] }
  total - discount_for(total)
end

# 2. In the one-line method below, with the cursor on `compute`, `viF` takes
#    only the body after the `=` (a query of your config's own). With the
#    cursor on the `def`, it does not: mini.ai only finds objects that cover
#    the cursor.
def endless = compute(1, 2)

# 3. Cursor inside the class, `vac` selects the whole class and `vic` its
#    inside. `vaM` does the same (vim-ruby's old key, pointed at mini.ai).
class Receipt
  def initialize(id)
    @id = id
  end
end

# 4. `o` is a block, a conditional or a loop. Cursor on `log` below, `vio`
#    selects the body of the `do ... end` and `vao` goes from `do` to `end`
#    (`lines.each` stays out). Try it inside the `if`, the `while` and the
#    one-line `x if y` too.
def blocks(lines)
  lines.each do |line|
    log(line)
  end
  if lines.empty?
    warn_empty
  end
  while lines.any?
    lines.shift
  end
  notify if lines.empty?
end

# 5. Quotes and pairs. Inside the string, `ciq` changes the contents of any
#    quote (`q` stands for ", ' and `). Inside the bracket, `cib` changes the
#    contents of any pair (`b` stands for (), [] and {}).
def quotes_and_brackets
  compute("change me", [base, {qty: 2}])
end

# 6. Argument. Cursor on `start_date`, `daa` deletes the argument along with
#    the right comma. `cia` changes only the argument.
def arguments
  build_report(customer_id, start_date, end_date)
end

# 7. Function call. Cursor inside `format(...)`, `vaf` selects the whole call
#    and `vif` only its arguments.
def function_call
  format("%s-%s", prefix, suffix)
end

# 8. Next and last. With the cursor at the start of the line below (outside
#    any string), `ciNq` changes the NEXT string. `cilq` changes the previous
#    one. `g]q` jumps to the end of the next string and `g[q` to its start.
def next_and_last
  pair("first", "second", "third")
end

# 9. Made-to-measure object. Cursor between the pipes, `ci?` asks for the
#    left and the right delimiter: `|`, `<CR>`, `|`, `<CR>`. It changes the
#    block's parameters.
def custom_object(items)
  items.map { |item, index| [index, item] }
end

# 10. Incremental selection (nvim 0.12). Cursor on `BRL`, `v`, then `an`
#     several times: the selection grows node by node. `in` shrinks it back
#     along the same path and `]n` / `[n` move between siblings.
def tree
  {store: {name: "Downtown", currency: "BRL", tags: ["retail", "food"]}}
end

# 11. Yank without losing your place. Cursor inside `keep me`, `<Space>yiq`
#     copies the string and the cursor stays put. Paste it elsewhere with `p`.
def yank_in_place
  label("keep me")
end

# 12. The whole buffer is `aB`: `yaB` copies the entire file.
