package artifact

import "core:mem"

Deferred_Op :: union {
	Deferred_Destroy,
	Deferred_Add,
	Deferred_Remove,
}

Deferred_Destroy :: struct {
	entity: Entity,
}

Deferred_Add :: struct {
	entity: Entity,
	value:  any,
}

Deferred_Remove :: struct {
	entity:  Entity,
	type_id: typeid,
}

deferred_destroy :: proc(world: ^World, entity: Entity) {
	append(&world.deferred_ops, Deferred_Op(Deferred_Destroy{entity = entity}))
}

deferred_add :: proc(world: ^World, entity: Entity, value: $T) {
	data, _ := mem.alloc(size_of(T), align_of(T), world.allocator)
	(cast(^T)data)^ = value
	append(
		&world.deferred_ops,
		Deferred_Op(Deferred_Add{entity = entity, value = any{data = data, id = typeid_of(T)}}),
	)
}

deferred_remove :: proc(world: ^World, entity: Entity, $T: typeid) {
	append(&world.deferred_ops, Deferred_Op(Deferred_Remove{entity = entity, type_id = T}))
}

world_flush :: proc(world: ^World) {
	for op in world.deferred_ops {
		switch o in op {
		case Deferred_Destroy:
			entity_destroy(world, o.entity)
		case Deferred_Add:
			component_add_raw(world, o.entity, o.value)
			mem.free(o.value.data, world.allocator)
		case Deferred_Remove:
			component_remove_by_id(world, o.entity, o.type_id)
		}
	}
	clear(&world.deferred_ops)
}

deferred_ops_clear :: proc(world: ^World) {
	for op in world.deferred_ops {
		switch o in op {
		case Deferred_Destroy:
		case Deferred_Add:
			mem.free(o.value.data, world.allocator)
		case Deferred_Remove:
		}
	}
	clear(&world.deferred_ops)
}
