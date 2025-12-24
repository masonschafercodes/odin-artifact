package artifact

// Entity handle: [32-bit index][32-bit generation]
// Generation increments on reuse to detect stale handles.

Entity :: distinct u64

ENTITY_INDEX_BITS :: 32
ENTITY_INDEX_MASK :: (1 << ENTITY_INDEX_BITS) - 1
INVALID_ENTITY :: Entity(0xFFFF_FFFF_FFFF_FFFF)

entity_index :: proc(e: Entity) -> u32 {
	return u32(u64(e) & ENTITY_INDEX_MASK)
}

entity_generation :: proc(e: Entity) -> u32 {
	return u32(u64(e) >> ENTITY_INDEX_BITS)
}

entity_make :: proc(index: u32, generation: u32) -> Entity {
	return Entity(u64(index) | (u64(generation) << ENTITY_INDEX_BITS))
}

entity_is_valid :: proc(e: Entity) -> bool {
	return e != INVALID_ENTITY
}

Entity_Record :: struct {
	generation:      u32,
	is_alive:        bool,
	archetype_index: u32,
	row_index:       u32,
}
