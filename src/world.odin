package artifact

import "core:mem"

DEFAULT_ENTITY_POOL_CAPACITY :: 65536

World :: struct {
	entities:                   [dynamic]Entity_Record,
	free_list:                  [dynamic]u32,
	entity_count:               int,
	archetypes:                 [dynamic]Archetype,
	archetype_map:              map[Archetype_Mask]u32,
	components:                 map[typeid]Component_Registration,
	next_comp_idx:              int,
	default_archetype_capacity: int,
	allocator:                  mem.Allocator,
	deferred_ops:               [dynamic]Deferred_Op,
	query_cache:                map[Query_Key][dynamic]^Archetype,
}

world_create :: proc(
	default_archetype_capacity := DEFAULT_ARCHETYPE_CAPACITY,
	allocator := context.allocator,
) -> World {
	return World {
		entities = make([dynamic]Entity_Record, 0, DEFAULT_ENTITY_POOL_CAPACITY, allocator),
		free_list = make([dynamic]u32, allocator),
		entity_count = 0,
		archetypes = make([dynamic]Archetype, allocator),
		archetype_map = make(map[Archetype_Mask]u32, allocator = allocator),
		components = make(map[typeid]Component_Registration, allocator = allocator),
		next_comp_idx = 0,
		default_archetype_capacity = default_archetype_capacity,
		allocator = allocator,
		deferred_ops = make([dynamic]Deferred_Op, allocator),
		query_cache = make(map[Query_Key][dynamic]^Archetype, allocator = allocator),
	}
}

world_destroy :: proc(world: ^World) {
	for &arch in world.archetypes {
		archetype_destroy(&arch)
	}

	query_cache_clear(world)
	delete(world.query_cache)

	deferred_ops_clear(world)
	delete(world.deferred_ops)

	delete(world.archetypes)
	delete(world.archetype_map)
	delete(world.entities)
	delete(world.free_list)
	delete(world.components)
}

world_register_component :: proc(world: ^World, $T: typeid) -> (int, bool) #optional_ok {
	if existing, ok := world.components[T]; ok {
		return existing.index, true
	}

	if world.next_comp_idx >= MAX_COMPONENTS {
		return -1, false
	}

	idx := world.next_comp_idx
	world.next_comp_idx += 1

	world.components[T] = Component_Registration {
		info  = component_info(T),
		index = idx,
	}

	return idx, true
}

world_get_component_info :: proc(world: ^World, $T: typeid) -> (Component_Registration, bool) {
	reg, ok := world.components[T]
	return reg, ok
}

@(private = "file")
allocate_entity_slot :: proc(world: ^World) -> (u32, ^Entity_Record) {
	idx: u32

	if len(world.free_list) > 0 {
		idx = pop(&world.free_list)
	} else {
		idx = u32(len(world.entities))
		append(&world.entities, Entity_Record{})
	}

	record := &world.entities[idx]
	record.is_alive = true
	world.entity_count += 1

	return idx, record
}

@(private = "file")
rollback_entity_slot :: proc(world: ^World, idx: u32, record: ^Entity_Record) {
	record.is_alive = false
	append(&world.free_list, idx)
	world.entity_count -= 1
}

@(private = "file")
query_cache_clear :: proc(world: ^World) {
	for _, &cached in world.query_cache {
		delete(cached)
	}
	clear(&world.query_cache)
}

entity_create :: proc(world: ^World) -> (Entity, bool) #optional_ok {
	idx, record := allocate_entity_slot(world)
	entity := entity_make(idx, record.generation)

	empty_mask := Archetype_Mask{}
	arch_idx, arch_ok := world_get_or_create_archetype(world, empty_mask, nil, nil)
	if !arch_ok {
		rollback_entity_slot(world, idx, record)
		return INVALID_ENTITY, false
	}

	arch := &world.archetypes[arch_idx]
	row, add_ok := archetype_add_entity(arch, entity)
	if !add_ok {
		rollback_entity_slot(world, idx, record)
		return INVALID_ENTITY, false
	}

	record.archetype_index = u32(arch_idx)
	record.row_index = row

	return entity, true
}

entity_spawn :: proc(world: ^World, components: ..any) -> (Entity, bool) #optional_ok {
	if len(components) == 0 {
		return entity_create(world)
	}

	mask := Archetype_Mask{}
	indices := make([]int, len(components), context.temp_allocator)
	infos := make([]Component_Info, len(components), context.temp_allocator)

	for i in 0 ..< len(components) {
		comp := components[i]
		id := comp.id
		reg, ok := world.components[id]
		if !ok {
			return INVALID_ENTITY, false
		}
		mask += {reg.index}
		indices[i] = reg.index
		infos[i] = reg.info
	}

	arch_idx, arch_ok := world_get_or_create_archetype(world, mask, indices, infos)
	if !arch_ok {
		return INVALID_ENTITY, false
	}
	arch := &world.archetypes[arch_idx]

	idx, record := allocate_entity_slot(world)
	entity := entity_make(idx, record.generation)

	row, add_ok := archetype_add_entity(arch, entity)
	if !add_ok {
		rollback_entity_slot(world, idx, record)
		return INVALID_ENTITY, false
	}
	record.archetype_index = u32(arch_idx)
	record.row_index = row

	for i in 0 ..< len(components) {
		comp := components[i]
		id := comp.id
		col_idx := archetype_find_column_by_id(arch, id)
		if col_idx >= 0 {
			col := &arch.columns[col_idx]
			dest := rawptr(uintptr(col.data) + uintptr(int(row) * col.info.size))
			mem.copy(dest, comp.data, col.info.size)
		}
	}

	return entity, true
}

entity_destroy :: proc(world: ^World, entity: Entity) -> bool {
	if !entity_alive(world, entity) {
		return false
	}

	idx := entity_index(entity)
	record := &world.entities[idx]
	arch := &world.archetypes[record.archetype_index]
	row := record.row_index

	if swapped, ok := archetype_remove_entity(arch, row).?; ok {
		swapped_idx := entity_index(swapped)
		swapped_record := &world.entities[swapped_idx]
		swapped_record.row_index = row
	}

	record.is_alive = false
	record.generation += 1

	append(&world.free_list, idx)
	world.entity_count -= 1

	return true
}

entity_alive :: proc(world: ^World, entity: Entity) -> bool {
	if !entity_is_valid(entity) {
		return false
	}

	idx := entity_index(entity)
	gen := entity_generation(entity)

	if int(idx) >= len(world.entities) {
		return false
	}

	record := &world.entities[idx]
	return record.is_alive && record.generation == gen
}

world_get_or_create_archetype :: proc(
	world: ^World,
	mask: Archetype_Mask,
	indices: []int,
	infos: []Component_Info,
) -> (
	u32,
	bool,
) #optional_ok {
	if arch_idx, ok := world.archetype_map[mask]; ok {
		return arch_idx, true
	}

	id := u32(len(world.archetypes))

	actual_indices := indices if indices != nil else make([]int, 0, context.temp_allocator)
	actual_infos := infos if infos != nil else make([]Component_Info, 0, context.temp_allocator)

	arch, ok := archetype_create(
		id,
		actual_indices,
		actual_infos,
		world.default_archetype_capacity,
		world.allocator,
	)
	if !ok {
		return 0, false
	}

	query_cache_clear(world)

	append(&world.archetypes, arch)
	world.archetype_map[mask] = id

	return id, true
}

world_get_archetype :: proc(world: ^World, types: ..typeid) -> ^Archetype {
	mask := Archetype_Mask{}
	indices := make([]int, len(types), context.temp_allocator)
	infos := make([]Component_Info, len(types), context.temp_allocator)

	for i in 0 ..< len(types) {
		t := types[i]
		reg, ok := world.components[t]
		if !ok {
			world_register_component_by_id(world, t)
			reg = world.components[t]
		}
		mask += {reg.index}
		indices[i] = reg.index
		infos[i] = reg.info
	}

	arch_idx, arch_ok := world_get_or_create_archetype(world, mask, indices, infos)
	if !arch_ok {
		return nil
	}
	return &world.archetypes[arch_idx]
}

@(private = "file")
world_register_component_by_id :: proc(world: ^World, id: typeid) -> int {
	if existing, ok := world.components[id]; ok {
		return existing.index
	}

	idx := world.next_comp_idx
	world.next_comp_idx += 1

	world.components[id] = Component_Registration {
		info = Component_Info{id = id, size = 0, align = 0},
		index = idx,
	}

	return idx
}

world_entity_count :: proc(world: ^World) -> int {
	return world.entity_count
}

world_archetype_count :: proc(world: ^World) -> int {
	return len(world.archetypes)
}

world_query_cache_count :: proc(world: ^World) -> int {
	return len(world.query_cache)
}
