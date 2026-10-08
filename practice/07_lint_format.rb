# frozen_string_literal: true

# 07. Lint and formatting. This directory has no Gemfile, so nvim-lint runs
# standardrb and the quick fixes come from `ruby_fixes`, your config's
# in-process server. `:e!` undoes.

# 1. `]d` and `[d` walk through the diagnostics of the methods below. `<C-w>d`
#    shows the whole message.
def single_quotes = 'prefer double quotes'

def hash_rockets = {:count => 1}

def redundant_return
  return 42
end

def bad_spacing( a,b )
  a+b
end

# 2. `gQ` formats the file with `--fix-layout`, which touches only spaces and
#    line breaks. `bad_spacing` above comes out right, but the quotes, the
#    hash rocket and the `return` stay diagnostics. Style is not layout.

# 3. Quick fix. Cursor on the `'prefer double quotes'` line, `gra` offers to
#    fix only that cop on the line, to disable the cop on the line, or to fix
#    everything.

# 4. `gq` on a range. `gqip` on the method below formats only that method. On
#    comment-only lines, like this paragraph, `gqip` wraps the text to the
#    width.
def range_format
  value =  1
  value  +  1
end

# 5. `gw` always wraps text, never formats code. Join the two comment lines
#    below into one with `J`, then `gwip` to wrap them again.
# This is a long comment that was written on a single line and should be wrapped back
# to the configured width by gw.
