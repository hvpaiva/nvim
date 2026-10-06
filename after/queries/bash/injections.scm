; extends

; The single-quoted argument of jq (and yq, gojq) is a jq filter, and of awk
; a program: highlight them as code instead of an opaque string.
;   jq -r '.items[] | .name'      awk -F: '{ print $1 }'
((command
  name: (command_name) @_command
  argument: (raw_string) @injection.content)
  (#any-of? @_command "jq" "yq" "gojq")
  (#offset! @injection.content 0 1 0 -1)
  (#set! injection.language "jq"))

((command
  name: (command_name) @_command
  argument: (raw_string) @injection.content)
  (#any-of? @_command "awk" "gawk" "mawk")
  (#offset! @injection.content 0 1 0 -1)
  (#set! injection.language "awk"))
