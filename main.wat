(module
	(memory $mem (export "memory") 1)
	(global $base (export "base") i32 (i32.const 64))
	(global $iptr (mut i32) (i32.const 0))
	(global $data_len  (mut i32) (i32.const 0))
	(global $optr (mut i32) (i32.const 0))

	(func $advance_iptr
		(param $delta i32)

		(global.set $iptr
			(i32.add
				(global.get $iptr)
				(local.get $delta)
			)
		)
	)

	(func $advance_optr
		(param $delta i32)

		(global.set $optr
			(i32.add
				(global.get $optr)
				(local.get $delta)
			)
		)
	)

	(func $write_u8
		(param $v i32)

		(i32.store8
			(global.get $optr)
			(local.get $v)
		)
		(call $advance_optr (i32.const 1))
	)
	
	(func $write_u32
		(param $v i32)

		(i32.store 
			(global.get $optr)
			(local.get $v)
		)
		(call $advance_optr (i32.const 4))
	)
	
	(func $next_u8
		(result i32)
		(local $v i32)

		(local.set $v
			(i32.load8_u (global.get $iptr))
		)
		(call $advance_iptr (i32.const 1))
		(local.get $v)
	)

	(func $next_i32_be
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
						(i32.load8_u (global.get $iptr))
					)
				)
				;; ptr++
				(call $advance_iptr (i32.const 1))

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

	(func $assert_next_u8
		(param $expected i32)
		(if
			(i32.ne
				(call $next_u8)
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
				(global.get $iptr)
				(call $align (global.get $iptr) (i32.const 2))
			)
			(then (unreachable))
		)
		;; Assert first 4 bytes are "qoif"
		(call $assert_next_u8 (i32.const 0x71))
		(call $assert_next_u8 (i32.const 0x6f))
		(call $assert_next_u8 (i32.const 0x69))
		(call $assert_next_u8 (i32.const 0x66))

		;; Read width in big-endian from header
		;; And write it to output
		(call $write_u32
			(call $next_i32_be)
		)
		;; Same for height
		(call $write_u32
			(call $next_i32_be)
		)
		;; Read channel
		;; FIXME
		(drop (call $next_u8))
		;; Read colorspace
		;; FIXME
		(drop (call $next_u8))
	)

	(func (export "decode")
		(result i32)

		(local $output_base i32)
		
		(global.set $iptr (global.get $base))

		(global.set $optr
			(call $align
				(i32.add
					(global.get $base)
					(global.get $data_len)
				)
				(i32.const 2)
			)
		)
		(local.set $output_base (global.get $optr))
		(call $decode_header)
		(local.get $output_base)
	)
)
