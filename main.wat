(module
	;; Memory layout:
	;; |-------+------------+------------------+--------
	;; | input | last pixel | pixelbuckets[64] | output
	;; |-------|------------|------------------|-------
	;; 0      $base      base + 4    base + 4 + 64 *4
	
	(memory $mem (export "memory") 1)
	(global $base (mut i32) (i32.const 0))
	(global $output_base (export "output_base") (mut i32) (i32.const 0))
	(global $data_len  (mut i32) (i32.const 0))
	(global $iptr (export "iptr") (mut i32) (i32.const 0))
	(global $optr (export "optr") (mut i32) (i32.const 0))

	(func $abort
		unreachable
	)

	(func $advance_iptr
		(param $delta i32)

		(global.set $iptr
			(i32.add
				(global.get $iptr)
				(local.get $delta)
			)
		)
	)

	(func $mem_size
		(result i32)

		(i32.mul
			(memory.size)
			(i32.const 65536)
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

		(if
			(i32.ge_u
				(global.get $optr)
				(call $mem_size)
			)
			(then (drop (memory.grow (i32.const 1))))
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
	
	(func $next_u32
		(result i32)
		(local $v i32)

		(local.set $v
			(i32.load (global.get $iptr))
		)
		(call $advance_iptr (i32.const 4))
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
			(then (call $abort))
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

	(func $calc_hash
		(param $pixel i32)
		(result i32)

		(local $acc i32)

		(local.set $acc
			(i32.add
				(local.get $acc)
				(i32.mul
					(i32.and
						(i32.shr_u
							(local.get $pixel)
							(i32.const 0)
						)
						(i32.const 0xff)
					)
					(i32.const 3)
				)
			)
		)
		(local.set $acc
			(i32.add
				(local.get $acc)
				(i32.mul
					(i32.and
						(i32.shr_u
							(local.get $pixel)
							(i32.const 8)
						)
						(i32.const 0xff)
					)
					(i32.const 5)
				)
			)
		)
		(local.set $acc
			(i32.add
				(local.get $acc)
				(i32.mul
					(i32.and
						(i32.shr_u
							(local.get $pixel)
							(i32.const 16)
						)
						(i32.const 0xff)
					)
					(i32.const 7)
				)
			)
		)
		(local.set $acc
			(i32.add
				(local.get $acc)
				(i32.mul
					(i32.and
						(i32.shr_u
							(local.get $pixel)
							(i32.const 24)
						)
						(i32.const 0xff)
					)
					(i32.const 11)
				)
			)
		)
		(i32.rem_u
			(local.get $acc)
			(i32.const 64)
		)
	)

	(func $update_pixel_bucket
		(param $pixel i32)

		(i32.store
			(call $bucket_addr
				(call $calc_hash (local.get $pixel))
			)
			(local.get $pixel)
		)
	)

	(func $to_f32
		(param $v i32)
		(result f32)

		(f32.div
			(f32.convert_i32_u (local.get $v))
			(f32.const 255.0)
		)
	)

	(func $from_f32
		(param $v f32)
		(result i32)

		(i32.and
			(i32.trunc_f32_u
				(f32.mul
					(local.get $v)
					(f32.const 255.0)
				)
			)
			(i32.const 0xFF)
		)
	)

	(func $premultiply
		(param $pixel i32)
		(result i32)

		(local $alpha f32)

		(local.set $alpha
			(call $to_f32
				(call $get_byte_in_u32
					(local.get $pixel)
					(i32.const 3)
				)
			)
		)

		(local.set $pixel
			(call $set_byte_in_u32
				(local.get $pixel)
				(i32.const 0)
				(call $from_f32
					(f32.mul
						(call $to_f32
							(call $get_byte_in_u32
								(local.get $pixel)
								(i32.const 0)
							)
						)
						(local.get $alpha)
					)
				)
			)
		)
		(local.set $pixel
			(call $set_byte_in_u32
				(local.get $pixel)
				(i32.const 1)
				(call $from_f32
					(f32.mul
						(call $to_f32
							(call $get_byte_in_u32
								(local.get $pixel)
								(i32.const 1)
							)
						)
						(local.get $alpha)
					)
				)
			)
		)
		(local.set $pixel
			(call $set_byte_in_u32
				(local.get $pixel)
				(i32.const 2)
				(call $from_f32
					(f32.mul
						(call $to_f32
							(call $get_byte_in_u32
								(local.get $pixel)
								(i32.const 2)
							)
						)
						(local.get $alpha)
					)
				)
			)
		)
		(local.get $pixel)
	)

	(func $write_pixel
		(param $pixel i32)

		(call $set_last_pixel (local.get $pixel))
		(call $update_pixel_bucket (local.get $pixel))
		(call $write_u32 
			(call $premultiply
				(local.get $pixel)
			)
		)
	)

	(func $qoi_op_rgb
		(local $pixel i32)

		;; 0xrr
		(local.set $pixel
			(call $next_u8)
		)
		;; 0xrr0000gg
		(local.set $pixel
			(i32.or
				(i32.rotr
					(local.get $pixel)
					(i32.const 8)
				)
				(call $next_u8)
			)
		)
		;; 0xggrr00bb
		(local.set $pixel
			(i32.or
				(i32.rotr
					(local.get $pixel)
					(i32.const 8)
				)
				(call $next_u8)
			)
		)
		;; 0xbbggrraa
		(local.set $pixel
			(i32.or
				(i32.rotr
					(local.get $pixel)
					(i32.const 8)
				)
				(i32.shr_u 
					(call $get_last_pixel)
					(i32.const 24)
				)
			)
		)
		;; 0xaabbggrr
		(call $write_pixel
			(i32.rotr
				(local.get $pixel)
				(i32.const 8)
			)
		)
	)

	(func $qoi_op_rgba
		(call $write_pixel
			(call $next_u32)
		)
	)

	(func $bucket_addr
		(param $index i32)
		(result i32)

		(i32.add
			(global.get $base)
			(i32.add
				(i32.mul
					(local.get $index)
					(i32.const 4)
				)
				(i32.const 4)
			)
		)
	)

	(func $get_bucket_pixel
		(param $index i32)
		(result i32)
		
		(i32.load (call $bucket_addr (local.get $index)))
	)

	(func $set_bucket_pixel
		(param $index i32)
		(param $pixel i32)
		
		(i32.store
			(call $bucket_addr (local.get $index))
			(local.get $pixel)
		)
	)

	(func $qoi_op_index
		(param $header i32)

		(call $write_pixel
			(call $get_bucket_pixel 
				(local.get $header)
			)
		)
	)

	(func $qoi_op_run
		(param $ctr i32)

		(local.set $ctr
			(i32.add
				(local.get $ctr)
				(i32.const 1)
			)
		)

		;; while($ctr > 0)
		(block $loop_end
			(loop $loop
				(call $write_pixel (call $get_last_pixel))
				;; $ctr--
				(local.set $ctr
					(i32.sub
						(local.get $ctr)
						(i32.const 1)
					)
				)
				;; if($ctr == 0) break;
				(br_if $loop_end 
					(i32.eqz (local.get $ctr))
				)
				;; continue
				(br $loop)
			)
		)
	)

	(func $get_byte_in_u32
		(param $v i32)
		(param $idx i32)
		(result i32)

		(i32.and
			(i32.shr_u
				(local.get $v)
				(i32.mul
					(local.get $idx)
					(i32.const 8)
				)
			)
			(i32.const 0xFF)
		)
	)

	(func $set_byte_in_u32
		(param $v i32)
		(param $idx i32)
		(param $b i32)
		(result i32)

		(local $shift i32)
		(local $mask i32)

		;; Bit shift
		(local.set $shift
			(i32.mul
				(local.get $idx)
				(i32.const 8)
			)
		)
		;; Mask of the shape 0b00..00ffff_ffff00..000
		(local.set $mask
			(i32.shl
				(i32.const 0xff)
				(local.get $shift)
			)
		)

		;; Set byte to zero
		(local.set $v
			(i32.and
				(local.get $v)
				(call $not
					(local.get $mask)
				)
			)
		)

		;; Put new value in
		(i32.or
			(local.get $v)
			(i32.shl
				(i32.and
					(local.get $b)
					(i32.const 0xFF)
				)
				(local.get $shift)
			)
		)
	)

	(func $qoi_op_diff
		(param $deltas i32)

		(local $last_pixel i32)

		(local.set $last_pixel (call $get_last_pixel))

		;; Apply db
		(local.set $last_pixel
			(call $set_byte_in_u32
				(local.get $last_pixel)
				(i32.const 2)
				(i32.add
					(call $get_byte_in_u32
						(local.get $last_pixel)
						(i32.const 2)
					)
					(i32.sub
						(i32.and
							(local.get $deltas)
							(i32.const 0x03)
						)
						(i32.const 2)
					)
				)
			)
		)

		;; Shift so db gets replaced with dg
		(local.set $deltas
			(i32.shr_u
				(local.get $deltas)
				(i32.const 2)
			)
		)
		(local.set $last_pixel
			(call $set_byte_in_u32
				(local.get $last_pixel)
				(i32.const 1)
				(i32.add
					(call $get_byte_in_u32
						(local.get $last_pixel)
						(i32.const 1)
					)
					(i32.sub
						(i32.and
							(local.get $deltas)
							(i32.const 0x03)
						)
						(i32.const 2)
					)
				)
			)
		)

		;; Shift so dg gets replaced with dr
		(local.set $deltas
			(i32.shr_u
				(local.get $deltas)
				(i32.const 2)
			)
		)
		(local.set $last_pixel
			(call $set_byte_in_u32
				(local.get $last_pixel)
				(i32.const 0)
				(i32.add
					(call $get_byte_in_u32
						(local.get $last_pixel)
						(i32.const 0)
					)
					(i32.sub
						(i32.and
							(local.get $deltas)
							(i32.const 0x03)
						)
						(i32.const 2)
					)
				)
			)
		)

		(call $write_pixel (local.get $last_pixel))
	)

	(func $qoi_op_luma
		(param $dg i32)

		(local $dr i32)
		(local $db i32)
		(local $last_pixel i32)

		(local.set $last_pixel
			(call $get_last_pixel)
		)

		;; $dg is 6-bit signed integer with a bias of 32
		(local.set $dg
			(i32.sub
				(local.get $dg)
				(i32.const 32)
			)
		)

		;; For now $dr contains $dr-$dg in the upper nibble
		;; and $db-$dg in the lower nibble. 
		;; Both values are 4-bit signed integers with a bias of 8.
		(local.set $dr
			(call $next_u8)
		)

		;; Extract $db
		(local.set $db
			;; Add $dg
			(i32.add
				;; Add bias (0 means -8, 1 means -7 etc)
				(i32.sub
					;; Lower nibble
					(i32.and
						(local.get $dr)
						(i32.const 0x0F)
					)
					(i32.const 8)
				)
				(local.get $dg)
			)
		)

		;; Same for $dr
		(local.set $dr
			;; Add $dg
			(i32.add
				;; Add bias (0 means -8, 1 means -7 etc)
				(i32.sub
					;; Higher nibble
					(i32.shr_u
						(local.get $dr)
						(i32.const 4)
					)
					(i32.const 8)
				)
				(local.get $dg)
			)
		)

		;; Add $dr to old pixel’s red value
		(local.set $last_pixel
			(call $set_byte_in_u32
				(local.get $last_pixel)
				(i32.const 0)
				(i32.add
					(call $get_byte_in_u32
						(local.get $last_pixel)
						(i32.const 0)
					)
					(local.get $dr)
				)
			)
		)

		;; Add $dg to old pixel’s green value
		(local.set $last_pixel
			(call $set_byte_in_u32
				(local.get $last_pixel)
				(i32.const 1)
				(i32.add
					(call $get_byte_in_u32
						(local.get $last_pixel)
						(i32.const 1)
					)
					(local.get $dg)
				)
			)
		)

		;; Add $db to old pixel’s blue value
		(local.set $last_pixel
			(call $set_byte_in_u32
				(local.get $last_pixel)
				(i32.const 2)
				(i32.add
					(call $get_byte_in_u32
						(local.get $last_pixel)
						(i32.const 2)
					)
					(local.get $db)
				)
			)
		)

		;; Alpha remains unchanged
		(call $write_pixel (local.get $last_pixel))
	)

	(func $decode_block
		(local $block_header i32)
		(local $header_value i32)

		(local.set $block_header
			(call $next_u8)
		)

		;; QOI_OP_RGB
		(if
			(i32.eq
				(local.get $block_header)
				(i32.const 0xFE)
			)
			(then 
				(call $qoi_op_rgb)
				(return)
			)
		)

		;; QOI_OP_RGBA
		(if
			(i32.eq
				(local.get $block_header)
				(i32.const 0xFF)
			)
			(then 
				(call $qoi_op_rgba)
				(return)
			)
		)

		;; Ops below only use the leading 2 bits 

		;; Strip the leading 2 bits and store the rest as value
		(local.set $header_value
			(i32.and
				(local.get $block_header)
				(i32.const 0x3F)
			)
		)

		(local.set $block_header
			(i32.and
				(local.get $block_header)
				(i32.const 0xC0)
			)
		)
		
		;; QOI_OP_INDEX
		(if
			(i32.eqz (local.get $block_header))
			(then 
				(call $qoi_op_index (local.get $header_value))
				(return)
			)
		)

		;; QOI_OP_DIFF
		(if
			(i32.eq
				(i32.const 0x40)
				(local.get $block_header)
			)
			(then 
				(call $qoi_op_diff (local.get $header_value))
				(return)
			)
		)

		;; QOI_OP_LUMA
		(if
			(i32.eq
				(i32.const 0x80)
				(local.get $block_header)
			)
			(then 
				(call $qoi_op_luma (local.get $header_value))
				(return)
			)
		)

		;; QOI_OP_RUN
		(if
			(i32.eq
				(i32.const 0xC0)
				(local.get $block_header)
			)
			(then 
				(call $qoi_op_run (local.get $header_value))
				(return)
			)
		)
		;; Invalid op code
		(call $abort)
	)

	(func $get_last_pixel
		(result i32)
		(i32.load (global.get $base))
	)

	(func $set_last_pixel
		(param $pixel i32)
		(i32.store
			(global.get $base)
			(local.get $pixel)
		)
	)

	(func (export "decode")
		(param $data_len i32)
		(result i32)

		(global.set $data_len (local.get $data_len))
		(global.set $iptr (i32.const 0))
		(global.set $base 
			(call $align
				(local.get $data_len)
				(i32.const 2)
			)
		)

		;; Leave space for the temporary data we need
		;; 64 previous pixel values: 64 * 4 = 256
		;; Last pixel: 4
		;; Total: 260
		(global.set $output_base
			(call $align
				(i32.add
					(global.get $base)
					(i32.const 260)
				)
				(i32.const 2)
			)
		)
		(global.set $optr (global.get $output_base))
		(call $set_last_pixel (i32.const 0xff000000))
		(call $decode_header)
		(block $decode_loop_done
			(loop $decode_loop
				(call $decode_block)
				(br_if $decode_loop_done
					(i32.eq
						(global.get $iptr)
						(global.get $data_len)
					)
				)
				(br $decode_loop)
			)
		)
		;; TODO: Verify trailer
		(global.get $output_base)
	)
)
