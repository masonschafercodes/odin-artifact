package artifact

import "core:mem"

Component_Info :: struct {
	id:    typeid,
	size:  int,
	align: int,
}

Component_Registration :: struct {
	info:  Component_Info,
	index: int,
}

component_info :: proc($T: typeid) -> Component_Info {
	return Component_Info{id = T, size = size_of(T), align = align_of(T)}
}

component_get :: proc(world: ^World, entity: Entity, $T: typeid) -> ^T {
	if !entity_alive(world, entity) {
		return nil
	}

	record := &world.entities[entity_index(entity)]
	arch := &world.archetypes[record.archetype_index]

	return archetype_get_component(arch, record.row_index, T)
}

component_has :: proc(world: ^World, entity: Entity, $T: typeid) -> bool {
	if !entity_alive(world, entity) {
		return false
	}

	reg, ok := world.components[T]
	if !ok {
		return false
	}

	record := &world.entities[entity_index(entity)]
	arch := &world.archetypes[record.archetype_index]

	return reg.index in arch.mask
}

component_set :: proc(world: ^World, entity: Entity, value: $T) -> bool {
	if !entity_alive(world, entity) {
		return false
	}

	record := &world.entities[entity_index(entity)]
	arch := &world.archetypes[record.archetype_index]

	col_idx := archetype_find_column_by_id(arch, T)
	if col_idx < 0 {
		return false
	}

	column_set(&arch.columns[col_idx], int(record.row_index), value)
	return true
}

component_add :: proc(world: ^World, entity: Entity, value: $T) -> bool {
	if !entity_alive(world, entity) {
		return false
	}

	reg, ok := world.components[T]
	if !ok {
		return false
	}

	entity_idx := entity_index(entity)
	record := &world.entities[entity_idx]
	source_arch := &world.archetypes[record.archetype_index]

	if reg.index in source_arch.mask {
		return component_set(world, entity, value)
	}

	new_row, add_ok := component_add_internal(world, entity, reg)
	if !add_ok {
		return false
	}

	target_arch := &world.archetypes[world.entities[entity_idx].archetype_index]
	col_idx := archetype_find_column_by_id(target_arch, T)
	if col_idx >= 0 {
		column_set(&target_arch.columns[col_idx], int(new_row), value)
	}

	return true
}

component_add_raw :: proc(world: ^World, entity: Entity, value: any) -> bool {
	if !entity_alive(world, entity) {
		return false
	}

	reg, ok := world.components[value.id]
	if !ok {
		return false
	}

	entity_idx := entity_index(entity)
	record := &world.entities[entity_idx]
	source_arch := &world.archetypes[record.archetype_index]

	if reg.index in source_arch.mask {
		col_idx := archetype_find_column_by_id(source_arch, value.id)
		if col_idx >= 0 {
			col := &source_arch.columns[col_idx]
			if dest, ok := column_get_ptr(col, int(record.row_index)); ok {
				mem.copy(dest, value.data, col.info.size)
			}
		}
		return true
	}

	new_row, add_ok := component_add_internal(world, entity, reg)
	if !add_ok {
		return false
	}

	target_arch := &world.archetypes[world.entities[entity_idx].archetype_index]
	col_idx := archetype_find_column_by_id(target_arch, value.id)
	if col_idx >= 0 {
		col := &target_arch.columns[col_idx]
		if dest, ok := column_get_ptr(col, int(new_row)); ok {
			mem.copy(dest, value.data, col.info.size)
		}
	}

	return true
}

component_remove :: proc(world: ^World, entity: Entity, $T: typeid) -> bool {
	if !entity_alive(world, entity) {
		return false
	}

	reg, ok := world.components[T]
	if !ok {
		return false
	}

	return component_remove_internal(world, entity, reg, T)
}

component_remove_by_id :: proc(world: ^World, entity: Entity, type_id: typeid) -> bool {
	if !entity_alive(world, entity) {
		return false
	}

	reg, ok := world.components[type_id]
	if !ok {
		return false
	}

	return component_remove_internal(world, entity, reg, type_id)
}

// Internal helper for component addition - handles archetype transition
@(private = "file")
component_add_internal :: proc(
	world: ^World,
	entity: Entity,
	reg: Component_Registration,
) -> (
	u32,
	bool,
) {
	entity_idx := entity_index(entity)
	record := &world.entities[entity_idx]
	source_arch := &world.archetypes[record.archetype_index]

	new_mask := source_arch.mask + {reg.index}

	new_count := source_arch.component_count + 1
	new_indices := make([]int, new_count, context.temp_allocator)
	new_infos := make([]Component_Info, new_count, context.temp_allocator)

	for i in 0 ..< source_arch.component_count {
		new_indices[i] = source_arch.type_indices[i]
		new_infos[i] = source_arch.columns[i].info
	}

	new_indices[source_arch.component_count] = reg.index
	new_infos[source_arch.component_count] = reg.info

	source_arch_idx := record.archetype_index
	source_row := record.row_index

	target_arch_idx, arch_ok := world_get_or_create_archetype(
		world,
		new_mask,
		new_indices,
		new_infos,
	)
	if !arch_ok {
		return 0, false
	}

	return move_entity_to_archetype(world, entity, source_arch_idx, source_row, target_arch_idx)
}

// Internal helper for component removal - handles archetype transition
@(private = "file")
component_remove_internal :: proc(
	world: ^World,
	entity: Entity,
	reg: Component_Registration,
	type_id: typeid,
) -> bool {
	entity_idx := entity_index(entity)
	record := &world.entities[entity_idx]
	source_arch := &world.archetypes[record.archetype_index]

	if reg.index not_in source_arch.mask {
		return false
	}

	new_mask := source_arch.mask - {reg.index}
	new_count := source_arch.component_count - 1

	source_arch_idx := record.archetype_index
	source_row := record.row_index

	if new_count == 0 {
		target_arch_idx, arch_ok := world_get_or_create_archetype(world, new_mask, nil, nil)
		if !arch_ok {
			return false
		}
		_, move_ok := move_entity_to_archetype(
			world,
			entity,
			source_arch_idx,
			source_row,
			target_arch_idx,
		)
		return move_ok
	}

	new_indices := make([]int, new_count, context.temp_allocator)
	new_infos := make([]Component_Info, new_count, context.temp_allocator)

	j := 0
	for i in 0 ..< source_arch.component_count {
		if source_arch.type_ids[i] == type_id {
			continue
		}
		new_indices[j] = source_arch.type_indices[i]
		new_infos[j] = source_arch.columns[i].info
		j += 1
	}

	target_arch_idx, arch_ok := world_get_or_create_archetype(
		world,
		new_mask,
		new_indices,
		new_infos,
	)
	if !arch_ok {
		return false
	}

	_, move_ok := move_entity_to_archetype(
		world,
		entity,
		source_arch_idx,
		source_row,
		target_arch_idx,
	)
	return move_ok
}

// Move entity between archetypes, copying common components
@(private = "file")
move_entity_to_archetype :: proc(
	world: ^World,
	entity: Entity,
	source_arch_idx: u32,
	source_row: u32,
	target_arch_idx: u32,
) -> (
	u32,
	bool,
) {
	target_arch := &world.archetypes[target_arch_idx]

	new_row, add_ok := archetype_add_entity(target_arch, entity)
	if !add_ok {
		return 0, false
	}

	source_arch := &world.archetypes[source_arch_idx]

	for src_col_idx in 0 ..< source_arch.component_count {
		src_type_id := source_arch.type_ids[src_col_idx]

		tgt_col_idx := archetype_find_column_by_id(target_arch, src_type_id)
		if tgt_col_idx < 0 {
			continue
		}

		src_col := &source_arch.columns[src_col_idx]
		tgt_col := &target_arch.columns[tgt_col_idx]

		src_ptr, src_ok := column_get_ptr(src_col, int(source_row))
		tgt_ptr, tgt_ok := column_get_ptr(tgt_col, int(new_row))
		if src_ok && tgt_ok {
			mem.copy(tgt_ptr, src_ptr, src_col.info.size)
		}
	}

	if swapped, ok := archetype_remove_entity(source_arch, source_row).?; ok {
		swapped_idx := entity_index(swapped)
		swapped_record := &world.entities[swapped_idx]
		swapped_record.row_index = source_row
	}

	entity_idx := entity_index(entity)
	record := &world.entities[entity_idx]
	record.archetype_index = target_arch_idx
	record.row_index = new_row

	return new_row, true
}
