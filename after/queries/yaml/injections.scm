; extends

; Crossplane function-go-templating: the inline template is Go template around
; YAML, the same shape as a Helm template, so it is highlighted as `helm`.
;   input:
;     inline:
;       template: |
(block_mapping_pair
  key: (flow_node) @_inline
  (#eq? @_inline "inline")
  value: (block_node
    (block_mapping
      (block_mapping_pair
        key: (flow_node) @_template
        (#eq? @_template "template")
        value: (block_node
          (block_scalar) @injection.content
          (#set! injection.language "helm")
          (#offset! @injection.content 0 1 0 0))))))
