(module
	(type $op_func (func (param i32)))

	;; Memory layout:
	;; |-------+------------+------------------+--------
	;; | input | last pixel |    index[64]     | output
	;; |-------|------------|------------------|-------
	;; 0      $base      base + 4    base + 4 + 64 *4
	(memory $mem (export "memory") 1)
	(global $base (mut i32) (i32.const 0))
	(global $output_base (export "output_base") (mut i32) (i32.const 0))
	(global $data_len  (mut i32) (i32.const 0))
	(global $iptr (export "iptr") (mut i32) (i32.const 0))
	(global $optr (export "optr") (mut i32) (i32.const 0))
		
	(table $op_table funcref
		(elem $qoi_op_index $qoi_op_diff $qoi_op_luma $qoi_op_run)
	)

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

	(func $mem_grow
		(if
			(i32.lt_s
				(memory.grow (i32.const 1))
				(i32.const 0)
			)
			(then (call $abort))
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

		(loop $loop
			(if
				(i32.ge_u
					(global.get $optr)
					(call $mem_size)
				)
				(then 
					(call $mem_grow)
					(br $loop)
				)
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
	
	(func $read_u8
		(result i32)
		(local $v i32)

		(local.set $v
			(i32.load8_u (global.get $iptr))
		)
		(call $advance_iptr (i32.const 1))
		(local.get $v)
	)
	
	(func $read_u32
		(result i32)
		(local $v i32)

		(local.set $v
			(i32.load (global.get $iptr))
		)
		(call $advance_iptr (i32.const 4))
		(local.get $v)
	)

	;; Reads a big-endian u32
	(func $read_u32_be
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
				(call $read_u8)
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
	
	(func $decode_header
		;; Assert first 4 bytes are "qoif"
		(call $assert_next_u8 (i32.const 0x71))
		(call $assert_next_u8 (i32.const 0x6f))
		(call $assert_next_u8 (i32.const 0x69))
		(call $assert_next_u8 (i32.const 0x66))

		;; Read width in big-endian from header
		;; And write it to output
		(call $write_u32
			;; Reads a big-endian u32
			(call $read_u32_be)
		)
		;; Same for height
		(call $write_u32
			;; Reads a big-endian u32
			(call $read_u32_be)
		)
		;; Read and ignore channel
		(drop (call $read_u8))
		;; Read and ignore colorspace
		(drop (call $read_u8))
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

	(func $save_pixel_in_index
		(param $pixel i32)

		(i32.store
			(call $index_addr
				(call $calc_hash (local.get $pixel))
			)
			(local.get $pixel)
		)
	)

	(func $write_pixel
		(param $pixel i32)

		(call $set_last_pixel (local.get $pixel))
		(call $save_pixel_in_index (local.get $pixel))
		(call $write_u32 
			(local.get $pixel)
		)
	)

	(func $qoi_op_rgb
		(local $pixel i32)

		;; Pretend there’s RGBA coming for a simpler read
		(local.set $pixel
			(call $read_u32)
		)
		;; and backtrack the iptr once
		(call $advance_iptr (i32.const -1))
		;; Copy alpha from previous pixel
		(call $write_pixel
			(call $set_byte_in_u32
				(local.get $pixel)
				(i32.const 3)
				(call $get_byte_in_u32
					(call $get_last_pixel)
					(i32.const 3)
				)
			)
		)
	)

	(func $qoi_op_rgba
		(call $write_pixel
			(call $read_u32)
		)
	)

	(func $index_addr
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

	(func $get_pixel_from_index
		(param $index i32)
		(result i32)
		
		(i32.load (call $index_addr (local.get $index)))
	)

	(func $qoi_op_index
		(param $header i32)

		(call $write_pixel
			(call $get_pixel_from_index 
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
			(call $read_u8)
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

	(func $decode_chunk
		(local $block_header i32)
		(local $header_value i32)

		(local.set $block_header
			(call $read_u8)
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

		;; Use the first two bits as an index for the $op_table,
		;; And use the remaining 6 bits as a parameter
		(call_indirect $op_table 
			(type $op_func)
			(i32.and
				(local.get $block_header)
				(i32.const 0x3F)
			)
			(i32.shr_u
				(local.get $block_header)
				(i32.const 6)
			)
		)
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
		;; Set the base at 4-byte aligned address
		(global.set $base 
			(i32.add
				(i32.and 
					(local.get $data_len)
					(call $not
						(i32.const 0x3)
					)
				)
				(i32.const 4)
			)
		)

		;; Leave space for the temporary data we need
		;; 64 previous pixel values: 64 * 4 = 256
		;; Last pixel: 4
		;; Total: 260
		(global.set $output_base
			(i32.add
				(global.get $base)
				(i32.const 260)
			)
		)
		(call $set_last_pixel (i32.const 0xff000000))

		;; This grows memory as a side-effect
		(global.set $optr (global.get $output_base))
		(call $advance_optr (i32.const 0))

		;; Decode loop
		(call $decode_header)
		(block $decode_loop_done
			(loop $decode_loop
				(call $decode_chunk)
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
