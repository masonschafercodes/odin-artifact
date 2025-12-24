package artifact

import "core:mem"

MAX_COMPONENTS :: 64
DEFAULT_ARCHETYPE_CAPACITY :: 1024

Archetype_Mask :: bit_set[0 ..< MAX_COMPONENTS;u64]

Archetype :: struct {
	id:              u32,
	mask:            Archetype_Mask,
	type_indices:    [MAX_COMPONENTS]int,
	type_ids:        [MAX_COMPONENTS]typeid,
	component_count: int,
	entities:        [dynamic]Entity,
	count:           int,
	columns:         [MAX_COMPONENTS]Component_Column,
	column_map:      map[typeid]int,
	allocator:       mem.Allocator,
}

archetype_create :: proc(
	id: u32,
	component_indices: []int,
	infos: []Component_Info,
	initial_capacity := DEFAULT_ARCHETYPE_CAPACITY,
	allocator := context.allocator,
) -> (
	Archetype,
	bool,
) #optional_ok {
	arch := Archetype {
		id              = id,
		mask            = {},
		component_count = len(component_indices),
		entities        = make([dynamic]Entity, 0, initial_capacity, allocator),
		count           = 0,
		column_map      = make(map[typeid]int, len(component_indices), allocator),
		allocator       = allocator,
	}

	for i in 0 ..< len(component_indices) {
		idx := component_indices[i]
		arch.mask += {idx}
		arch.type_indices[i] = idx
		arch.type_ids[i] = infos[i].id
		arch.column_map[infos[i].id] = i
		col, ok := column_create(infos[i], initial_capacity, allocator)
		if !ok {
			for j in 0 ..< i {
				column_destroy(&arch.columns[j], allocator)
			}
			delete(arch.entities)
			delete(arch.column_map)
			return Archetype{}, false
		}
		arch.columns[i] = col
	}

	return arch, true
}

archetype_destroy :: proc(arch: ^Archetype) {
	for i in 0 ..< arch.component_count {
		column_destroy(&arch.columns[i], arch.allocator)
	}
	delete(arch.entities)
	delete(arch.column_map)
	arch.count = 0
}

archetype_add_entity :: proc(arch: ^Archetype, entity: Entity) -> (u32, bool) #optional_ok {
	row := u32(arch.count)

	if !archetype_ensure_capacity(arch, arch.count + 1) {
		return 0, false
	}

	append(&arch.entities, entity)

	for i in 0 ..< arch.component_count {
		arch.columns[i].count += 1
	}

	arch.count += 1
	return row, true
}

// Returns the entity that was swapped into this row (for record update)
archetype_remove_entity :: proc(arch: ^Archetype, row: u32) -> Maybe(Entity) {
	if arch.count == 0 || int(row) >= arch.count {
		return nil
	}

	last := arch.count - 1
	swapped: Maybe(Entity) = nil

	if int(row) != last {
		for i in 0 ..< arch.component_count {
			column_swap(&arch.columns[i], int(row), last)
		}
		arch.entities[row] = arch.entities[last]
		swapped = arch.entities[row]
	}

	for i in 0 ..< arch.component_count {
		arch.columns[i].count -= 1
	}
	arch.count -= 1
	pop(&arch.entities)

	return swapped
}

archetype_ensure_capacity :: proc(arch: ^Archetype, needed: int) -> bool {
	if needed <= cap(arch.entities) {
		return true
	}

	reserve(&arch.entities, needed)

	for i in 0 ..< arch.component_count {
		if !column_ensure_capacity(&arch.columns[i], needed, arch.allocator) {
			return false
		}
	}
	return true
}

archetype_find_column :: proc(arch: ^Archetype, type_index: int) -> int {
	for i in 0 ..< arch.component_count {
		if arch.type_indices[i] == type_index {
			return i
		}
	}
	return -1
}

archetype_find_column_by_id :: proc(arch: ^Archetype, id: typeid) -> int {
	if col_idx, ok := arch.column_map[id]; ok {
		return col_idx
	}
	return -1
}

archetype_get_component :: proc(arch: ^Archetype, row: u32, $T: typeid) -> ^T {
	col_idx := archetype_find_column_by_id(arch, T)
	if col_idx < 0 {
		return nil
	}
	return column_get(&arch.columns[col_idx], int(row), T)
}

archetype_get_column :: proc(arch: ^Archetype, $T: typeid) -> []T {
	col_idx := archetype_find_column_by_id(arch, T)
	if col_idx < 0 {
		return nil
	}
	return column_slice(&arch.columns[col_idx], T)
}

archetype_set_component :: proc(arch: ^Archetype, row: u32, value: $T) {
	col_idx := archetype_find_column_by_id(arch, T)
	if col_idx >= 0 {
		column_set(&arch.columns[col_idx], int(row), value)
	}
}

archetype_has_component :: proc(arch: ^Archetype, type_index: int) -> bool {
	return type_index in arch.mask
}

archetype_matches :: proc(arch: ^Archetype, required: Archetype_Mask) -> bool {
	return required & arch.mask == required
}

archetype_matches_with_exclusion :: proc(
	arch: ^Archetype,
	required: Archetype_Mask,
	excluded: Archetype_Mask,
) -> bool {
	has_required := required & arch.mask == required
	has_excluded := excluded & arch.mask != {}
	return has_required && !has_excluded
}
