(module
	(memory $mem (export "memory") 1)
	(global $ptr (mut i32) (i32.const 0))
	(global $data_start (export "data_start") (mut i32) (i32.const 0))
	(global $data_len (export "data_len") (mut i32) (i32.const 0))
	(global $output_start (export "output_start") (mut i32) (i32.const 0))

	(func $next_i32
		(result i32)
		(local $i i32)
		(local $v i32)

		(local.set $i (i32.const 4))
		(block $done
			(loop $loop
				;; v = (v >>> 8) | *ptr)
				(local.set $v
					(i32.or
						(i32.rotl
							(local.get $v)
							(i32.const 8)
						)
						(i32.load8_u (global.get $ptr))
					)
				)
				;; ptr++
				(global.set $ptr
					(i32.add
						(global.get $ptr)
						(i32.const 1)
					)
				)
				;; i--
				(local.set $i
					(i32.sub
						(local.get $i)
						(i32.const 1)
					)
				)
				;; if(i == 0) break;
				(br_if $done
					(i32.eqz (local.get $i))
				)
				;; continue
				(br $loop)
			)
		)
		(local.get $v)
	)

	(func $assert_next_i32
		(param $expected i32)
		(if
			(i32.ne
				(call $next_i32)
				(local.get $expected)
			)
			(then (unreachable))
		)
	)

	(func $not
		(param $v i32)
		(result i32)

		(i32.xor
			(local.get $v)
			(i32.const -1)
		)
	)
	
	;; Returns the next address equal or larger than 
	;; $addr that has 2^$align alignment.
	(func $align
		(param $addr i32)
		(param $align i32) ;; Should prob only be 1, 2 or 3
		(result i32)

		(local $mask i32)

		(local.set $mask
			(i32.sub
				(i32.shl
					(i32.const 1)
					(local.get $align)
				)
				(i32.const 1)
			)
		)

		(i32.and
			(i32.add
				(local.get $addr)
				(local.get $mask)
			)
			(call $not
				(local.get $mask)
			)
		)
	)

	(func $decode_header
		;; Assert $start is 4 byte aligned
		(if 
			(i32.ne
				(global.get $ptr)
				(call $align (global.get $ptr) (i32.const 2))
			)
			(then (unreachable))
		)
		;; Assert first 4 bytes are "qoif"
		(call $assert_next_i32
			(i32.const 0x716f6966)
		)
		(i32.store
			offset=0
			(global.get $output_start)
			(call $next_i32)
		)
		(i32.store
			offset=4
			(global.get $output_start)
			(call $next_i32)
		)
	)

	(func (export "decode")
		(param $start i32)
		(param $len i32)

		(global.set $ptr (local.get $start))
		(global.set $data_start (local.get $start))
		(global.set $data_len (local.get $len))

		(global.set $output_start 
			(call $align
				(i32.add
					(global.get $data_start)
					(global.get $data_len)
				)
				(i32.const 2)
			)
		)
		(call $decode_header)
	)
)
