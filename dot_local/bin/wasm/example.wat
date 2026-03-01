(module
  (func $main (export "main")
    ;; Just a simple example of a compiled module interface
    ;; In reality, this would be compiled from Rust using `cargo build --target wasm32-wasi`
    nop
  )
)
