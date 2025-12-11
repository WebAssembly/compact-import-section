;; Auxiliary modules to import
(module
  (func (export "b") (result i32) (i32.const 0x0f))
  (func (export "c") (result i32) (i32.const 0xf0))
)
(register "a")
(module
  (func (export "") (result i32) (i32.const 0xab))
)
(register "")

;; Valid compact encodings
(module binary
  "\00asm" "\01\00\00\00"
  "\01\05\01\60\00\01\7f"     ;; Type section: (type (func (result i32)))
  "\02\0e"                    ;; Import section
  "\01"                       ;;   1 group
  "\01a"                      ;;     "a"
  "\00" "\7f"                 ;;     "" + 0x7f (compact encoding)
  "\02"                       ;;     2 items
  "\01b" "\00\00"             ;;       "b" (func (type 0))
  "\01c" "\00\00"             ;;       "c" (func (type 0))
)
(module binary
  "\00asm" "\01\00\00\00"
  "\01\05\01\60\00\01\7f"     ;; Type section: (type (func (result i32)))
  "\02\11"                    ;; Import section
  "\01"                       ;;   1 group
  "\01a"                      ;;     "a"
  "\00" "\7e"                 ;;     "" + 0x7e (compact encoding)
  "\00\00"                    ;;     (func (type 0))
  "\02"                       ;;     2 items
  "\01b"                      ;;       "b"
  "\01c"                      ;;       "c"
)

;; Overly-long empty name encodings are valid
(module binary
  "\00asm" "\01\00\00\00"
  "\01\05\01\60\00\01\7f"     ;; Type section: (type (func (result i32)))
  "\02\11"                    ;; Import section
  "\01"                       ;;   1 group
  "\01a"                      ;;     "a"
  "\80\80\80\00" "\7f"        ;;     "" (long encoding) + 0x7f
  "\02"                       ;;     2 items
  "\01b" "\00\00"             ;;       "b" (func (type 0))
  "\01c" "\00\00"             ;;       "c" (func (type 0))
)
(module binary
  "\00asm" "\01\00\00\00"
  "\01\05\01\60\00\01\7f"     ;; Type section: (type (func (result i32)))
  "\02\0f"                    ;; Import section
  "\01"                       ;;   1 group
  "\01a"                      ;;     "a"
  "\80\80\80\00" "\7e"        ;;     "" (long encoding) + 0x7e
  "\00\00"                    ;;     (func (type 0))
  "\02"                       ;;     2 items
  "\01b"                      ;;       "b"
  "\01c"                      ;;       "c"
)

;; Discriminator is not valid except after empty names
(assert_malformed
  (module binary
    "\00asm" "\01\00\00\00"
    "\01\05\01\60\00\01\7f"   ;; Type section: (type (func (result i32)))
    "\02\12"                  ;; Import section
    "\01"                     ;;   1 group
    "\01a"                    ;;     "a"
    "\01b" "\7f"              ;;     "b" + 0x7f
    "\02"                     ;;     2 items
    "\01b" "\00\00"           ;;       "b" (func (type 0))
    "\01c" "\00\00"           ;;       "c" (func (type 0))
  )
  "malformed import kind"
)
(assert_malformed
  (module binary
    "\00asm" "\01\00\00\00"
    "\01\05\01\60\00\01\7f"   ;; Type section: (type (func (result i32)))
    "\02\10"                  ;; Import section
    "\01"                     ;;   1 group
    "\01a"                    ;;     "a"
    "\01b" "\7e"              ;;     "" + 0x7e (long encoding)
    "\00\00"                  ;;     (func (type 0))
    "\02"                     ;;     2 items
    "\01b"                    ;;       "b"
    "\01c"                    ;;       "c"
  )
  "malformed import kind"
)

;; Discriminator is not to be interpreted as LEB128
(assert_malformed
  (module binary
    "\00asm" "\01\00\00\00"
    "\01\05\01\60\00\01\7f"   ;; Type section: (type (func (result i32)))
    "\02\11"                  ;; Import section
    "\01"                     ;;   1 group
    "\01a"                    ;;     "a"
    "\00\ff\80\80\00"         ;;     "" + 0x7f (long encoding)
    "\02"                     ;;     2 items
    "\01b" "\00\00"           ;;       "b" (func (type 0))
    "\01c" "\00\00"           ;;       "c" (func (type 0))
  )
  "malformed import kind"
)
(assert_malformed
  (module binary
    "\00asm" "\01\00\00\00"
    "\01\05\01\60\00\01\7f"   ;; Type section: (type (func (result i32)))
    "\02\0f"                  ;; Import section
    "\01"                     ;;   1 group
    "\01a"                    ;;     "a"
    "\00\fe\80\80\00"         ;;     "" + 0x7e (long encoding)
    "\00\00"                  ;;     (func (type 0))
    "\02"                     ;;     2 items
    "\01b"                    ;;       "b"
    "\01c"                    ;;       "c"
  )
  "malformed import kind"
)

;; Empty names are still valid if not followed by a discriminator
(module binary
  "\00asm" "\01\00\00\00"
  "\01\05\01\60\00\01\7f"     ;; Type section: (type (func (result i32)))
  "\02\05"                    ;; Import section
  "\01"                       ;;   1 group
  "\00\00\00\00"              ;;     "" "" (func (type 0))
)
