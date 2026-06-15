; extends

; ── Run command syntax highlighting ──
; Depends on the `is-mise?` predicate defined in treesitter plugin config

; Multiline shebang using env (e.g. """#!/usr/bin/env python""")
(pair
  (bare_key) @key (#eq? @key "run")
  (string) @injection.content @injection.language

  (#is-mise?)
  (#match? @injection.language "^['\"]{3}\n*#!(/\\w+)+/env\\s+\\w+")
  (#gsub! @injection.language "^.*#!/.*/env%s+([^%s]+).*" "%1")
  (#offset! @injection.content 0 3 0 -3)
)

; Multiline shebang (e.g. """#!/usr/bin/python""")
(pair
  (bare_key) @key (#eq? @key "run")
  (string) @injection.content @injection.language

  (#is-mise?)
  (#match? @injection.language "^['\"]{3}\n*#!(/\\w+)+\s*\n")
  (#gsub! @injection.language "^.*#!/.*/([^/%s]+).*" "%1")
  (#offset! @injection.content 0 3 0 -3)
)

; Multiline without shebang — default to bash
(pair
  (bare_key) @key (#eq? @key "run")
  (string) @injection.content

  (#is-mise?)
  (#match? @injection.content "^['\"]{3}\n*.*")
  (#not-match? @injection.content "^['\"]{3}\n*#!")
  (#offset! @injection.content 0 3 0 -3)
  (#set! injection.language "bash")
)

; ── MISE / USAGE comments in file tasks ──
; Inline TOML config embedded in scripts via //MISE comments
((comment) @injection.content
  (#lua-match? @injection.content "^//MISE ")
  (#offset! @injection.content 0 7 0 1)
  (#set! injection.language "toml"))

((comment) @injection.content
  (#lua-match? @injection.content "^//%[MISE%] ")
  (#offset! @injection.content 0 9 0 1)
  (#set! injection.language "toml"))

((comment) @injection.content
  (#lua-match? @injection.content "^// %[MISE%] ")
  (#offset! @injection.content 0 10 0 1)
  (#set! injection.language "toml"))

; Inline USAGE config in comments
((comment) @injection.content
  (#lua-match? @injection.content "^//USAGE ")
  (#offset! @injection.content 0 8 0 1)
  (#set! injection.combined)
  (#set! injection.language "kdl"))

((comment) @injection.content
  (#lua-match? @injection.content "^//%[USAGE%] ")
  (#offset! @injection.content 0 10 0 1)
  (#set! injection.combined)
  (#set! injection.language "kdl"))

((comment) @injection.content
  (#lua-match? @injection.content "^// %[USAGE%] ")
  (#offset! @injection.content 0 11 0 1)
  (#set! injection.combined)
  (#set! injection.language "kdl"))
