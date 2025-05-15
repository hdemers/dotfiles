;extends

;; Match a SQL query in the form of:
;;    query = "select ... from ..."
((assignment
  left: (identifier)
  right: (string (string_content) @injection.content
  (#vim-match? @injection.content "\\cselect.*from")
))
(#set! injection.language "sql")
)

;; match a SQL query in the form of:
;;    query = "select ... from ...".format(...)
((assignment
  left: (identifier)
  right: (call (attribute (string (string_content) @injection.content))
  (#vim-match? @injection.content "\\cselect.*from")
))
(#set! injection.language "sql")
)

