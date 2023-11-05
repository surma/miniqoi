(module
	(memory $mem (export "memory") 1)

	(func (export "decode")
		(param $start i32)
		(param $len i32)
		(result i32)
		;; Assert $start is 4 byte aligned

		(if 
			(i32.eqz
				(i32.rem_u
					(local.get $start)
					(i32.const 4)
				)
			)
			(then (nop))
			(else (return (i32.const -1)))
		)
		;; Assert first 4 bytes are "qoif"
		(if
			(i32.ne
				(i32.load (local.get $start))
				(i32.const 0x66696f71)
			)
			(then (return (i32.const -2)))
		)
		(i32.const 0)
	)
)
