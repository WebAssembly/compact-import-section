(module
  (func (export "func->11") (result i32) (i32.const 11))
  (func (export "func->22") (result f32) (f32.const 22))
  (global (export "global->1") i32 (i32.const 55))
  (global (export "global->20") i32 (i32.const 44))
)
(register "test")

(module
  (import "test"
    (item "func->11" (func $f11 (result i32)))
    (item "func->22" (func $f22 (result f32)))
  )

  (func (export "sum") (result i32)
    (local i32)

    call $f11
    (i32.trunc_f32_s (call $f22))
    i32.add
  )
)

(assert_return (invoke "sum" (i32.const 33)))
