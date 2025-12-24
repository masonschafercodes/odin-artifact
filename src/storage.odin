package artifact

import "core:mem"

// 32-byte alignment for SIMD (AVX)
COLUMN_ALIGNMENT :: 32

Component_Column :: struct {
	data:     rawptr,
	count:    int,
	capacity: int,
	info:     Component_Info,
}

column_create :: proc(
	info: Component_Info,
	capacity: int,
	allocator := context.allocator,
) -> (
	Component_Column,
	bool,
) #optional_ok {
	data: rawptr = nil
	if capacity > 0 && info.size > 0 {
		alloc_size := info.size * capacity
		err: mem.Allocator_Error
		data, err = mem.alloc(alloc_size, COLUMN_ALIGNMENT, allocator)
		if err != .None {
			return Component_Column{}, false
		}
	}

	return Component_Column{data = data, count = 0, capacity = capacity, info = info}, true
}

column_destroy :: proc(col: ^Component_Column, allocator := context.allocator) {
	if col.data != nil {
		mem.free(col.data, allocator)
		col.data = nil
	}
	col.count = 0
	col.capacity = 0
}

column_ensure_capacity :: proc(
	col: ^Component_Column,
	needed: int,
	allocator := context.allocator,
) -> bool {
	if needed <= col.capacity {
		return true
	}

	new_capacity := max(col.capacity * 2, needed, 16)
	new_size := col.info.size * new_capacity

	new_data, err := mem.alloc(new_size, COLUMN_ALIGNMENT, allocator)
	if err != .None {
		return false
	}

	if col.data != nil && col.count > 0 {
		mem.copy(new_data, col.data, col.info.size * col.count)
		mem.free(col.data, allocator)
	}

	col.data = new_data
	col.capacity = new_capacity
	return true
}

column_get :: proc(col: ^Component_Column, index: int, $T: typeid) -> ^T {
	if col.data == nil || index >= col.count {
		return nil
	}
	base := cast([^]T)col.data
	return &base[index]
}

column_slice :: proc(col: ^Component_Column, $T: typeid) -> []T {
	if col.data == nil || col.count == 0 {
		return nil
	}
	base := cast([^]T)col.data
	return base[:col.count]
}

column_set :: proc(col: ^Component_Column, index: int, value: $T) -> bool {
	if col.data == nil || index < 0 || index >= col.count {
		return false
	}
	base := cast([^]T)col.data
	base[index] = value
	return true
}

column_swap :: proc(col: ^Component_Column, a, b: int) -> bool {
	if a == b {
		return true
	}
	if col.data == nil || a < 0 || a >= col.count || b < 0 || b >= col.count {
		return false
	}

	size := col.info.size
	ptr_a := rawptr(uintptr(col.data) + uintptr(a * size))
	ptr_b := rawptr(uintptr(col.data) + uintptr(b * size))

	if size <= 64 {
		temp: [64]u8
		mem.copy(&temp[0], ptr_a, size)
		mem.copy(ptr_a, ptr_b, size)
		mem.copy(ptr_b, &temp[0], size)
	} else {
		temp := make([]u8, size)
		defer delete(temp)
		mem.copy(&temp[0], ptr_a, size)
		mem.copy(ptr_a, ptr_b, size)
		mem.copy(ptr_b, &temp[0], size)
	}
	return true
}
