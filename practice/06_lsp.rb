# frozen_string_literal: true

# 06. LSP, with ruby-lsp and Solargraph together. Wait a few seconds after
# opening. `:e!` undoes; the constant rename (exercise 7) also renames a file,
# which `:Practice!` undoes.

require_relative "lib/item"

# 1. Cursor on `Item`, `K` shows the documentation (the class comment). `K`
#    again enters the floating window; `q` leaves it.
SAMPLE = Item.new(sku: "A-1", name: "Pen", price_cents: 250, quantity: 3)

# 2. `<C-]>` goes to the definition (in Ruby, the ftplugin drops vim-ruby's
#    keys and leaves the LSP's). `<C-o>` goes back. `<C-w>]` opens it in a
#    split.
def total = SAMPLE.total_cents

# 3. Inside the parentheses of `Item.new(` below, in Normal mode, `gK` shows
#    the signature.
OTHER = Item.new(sku: "B-2", name: "Pad", price_cents: 990)

# 4. Type. Cursor on `item` inside the method, `grt` goes to the `Item` class
#    (the type comes from Solargraph, which reads the `@param`).
# @param item [Item]
def describe(item)
  "#{item.name}: #{item.price_cents}"
end

# 5. References. Cursor on `total_cents`, `grr` opens the list in the
#    quickfix and `<Space>fR` shows it in the picker.
def grand_total = SAMPLE.total_cents + OTHER.total_cents

# 6. Local variable rename (Solargraph). Cursor on `subtotal`, `grn`, type
#    `partial`, `<CR>`, and the three occurrences change.
def rename_local
  subtotal = 10
  subtotal += 5
  subtotal * 2
end

# 7. Constant rename (ruby-lsp). Cursor on `Item` below, `grn`, `Product`. It
#    changes the class and renames lib/item.rb to lib/product.rb, but does not
#    update the `require_relative`. `:Practice!` starts over.
CATALOG = [Item.new(sku: "C-3", name: "Ink", price_cents: 120)].freeze

# 8. Code actions. Select `price * quantity` below with `v` and `gra`, and
#    ruby-lsp offers to extract a variable or a method. Extract Variable
#    creates `new_variable = price * quantity` above and uses the name in the
#    expression. Extract Method creates `new_method` with no parameters, so
#    the extracted code loses `price` and `quantity`; rename it and pass the
#    arguments by hand.
def code_action(price, quantity)
  price * quantity + 100
end

# 9. Symbols. `gO` lists the file's symbols in a location list, `<Space>fS`
#    in the picker, and `<Space>fs` searches the project as you type.

# 10. Inlay hints. `<Space>oh` turns them on and off. Note the `rescue` with
#     no class (`StandardError` shows up) and the hash with an implicit value.
def inlay_hints(sku)
  {sku:}
rescue
  nil
end

# 11. Typed completion (Solargraph). On the `puts lines` line below, `A`, type
#     `.`, and Array's methods show up, because Solargraph knows that
#     `File.readlines` returns an Array. ruby-lsp would only guess the type
#     from the variable's name, and its guesses go away when Solargraph
#     answers. `ma` narrows the list to `map`. `<C-n>` and `<C-p>` move,
#     `<C-y>` accepts; `<CR>` only breaks the line, it never accepts. `<C-e>`
#     closes the list and `<M-Space>` (or `<C-x><C-o>`) opens it again.
def typed_completion
  lines = File.readlines("05_csv.txt")
  puts lines
end

# 12. ruby-lsp's on-type edits. Open a line right below (`o`), type
#     `def fresh` and `<CR>`, and the `end` goes in by itself. In a block,
#     type `[1].each do |` and the closing pipe shows up.

# 13. Diagnostics. `]d` and `[d` move between them, `<C-w>d` opens the whole
#     message in a window, `<Space>fD` lists the file's and `<Space>fd` the
#     project's.
