# 14. Git

This directory is a repository of its own, created by `:Practice`. Before
starting, open `01_motions.rb`, change two lines far apart and save. At the
end, `:Practice!` starts over.

## Hunks in the buffer (mini.diff)

1. In the changed `01_motions.rb`, the gutter marks what changed against the
   index. `]h` and `[h` move between hunks, `[H` and `]H` go to the first and
   the last.
2. `<Space>go` turns the overlay on, showing the old text next to the new.
3. Cursor on a hunk, `ghgh` stages it and `gHgh` undoes the change in the
   buffer. `gh` and `gH` are operators, so `ghip` stages the paragraph.
4. `<Space>fm` lists the modified hunks of every file, `<Space>fM` only this
   file's, and `<Space>fa` / `<Space>fA` the staged ones.

## Fugitive

5. `<Space>gg` opens the status in a tab. There, `s` stages the file, `u`
   unstages it, `=` shows the diff inline, `dv` opens the diff side by side,
   `cc` opens the commit and `g?` shows all the keys. `gq` closes it.
6. `<Space>gd` shows the project's diff and `<Space>gD` only this file's.
   `<Space>ga` and `<Space>gA` show what is staged.
7. `<Space>gv` opens this file's diff side by side with the index.
8. `<Space>gl` shows the log and `<Space>gL` this file's log. `<Space>fc` and
   `<Space>fC` show the commits in a picker, with a preview.
9. `<Space>gc` commits and `<Space>gC` amends.
