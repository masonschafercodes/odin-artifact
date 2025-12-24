package artifact

Query_Key :: struct {
	required: Archetype_Mask,
	excluded: Archetype_Mask,
}

Query_Result :: struct {
	archetypes: []^Archetype,
	mask:       Archetype_Mask,
}

Query_Builder :: struct {
	world:    ^World,
	required: Archetype_Mask,
	excluded: Archetype_Mask,
}

query :: proc(world: ^World, required: ..typeid) -> Query_Result {
	mask := build_mask(world, ..required)
	return query_by_mask(world, mask)
}

query_by_mask :: proc(world: ^World, mask: Archetype_Mask) -> Query_Result {
	return query_by_masks(world, mask, {})
}

query_by_masks :: proc(
	world: ^World,
	required: Archetype_Mask,
	excluded: Archetype_Mask,
) -> Query_Result {
	key := Query_Key{required, excluded}

	if cached, ok := world.query_cache[key]; ok {
		return Query_Result{archetypes = cached[:], mask = required}
	}

	matching := make([dynamic]^Archetype, world.allocator)
	for &arch in world.archetypes {
		if archetype_matches_with_exclusion(&arch, required, excluded) {
			append(&matching, &arch)
		}
	}

	world.query_cache[key] = matching

	return Query_Result{archetypes = matching[:], mask = required}
}

query_builder :: proc(world: ^World) -> Query_Builder {
	return Query_Builder{world = world, required = {}, excluded = {}}
}

query_with :: proc(qb: ^Query_Builder, $T: typeid) -> ^Query_Builder {
	if reg, ok := qb.world.components[T]; ok {
		qb.required += {reg.index}
	}
	return qb
}

query_without :: proc(qb: ^Query_Builder, $T: typeid) -> ^Query_Builder {
	if reg, ok := qb.world.components[T]; ok {
		qb.excluded += {reg.index}
	}
	return qb
}

query_execute :: proc(qb: ^Query_Builder) -> Query_Result {
	return query_by_masks(qb.world, qb.required, qb.excluded)
}

build_mask :: proc(world: ^World, types: ..typeid) -> Archetype_Mask {
	mask := Archetype_Mask{}
	for t in types {
		if reg, ok := world.components[t]; ok {
			mask += {reg.index}
		}
	}
	return mask
}

query_count :: proc(world: ^World, required: ..typeid) -> int {
	result := query(world, ..required)
	total := 0
	for arch in result.archetypes {
		total += arch.count
	}
	return total
}

for_each_1 :: proc(world: ^World, $T1: typeid, callback: proc(entity: Entity, c1: ^T1)) {
	result := query(world, T1)
	for arch in result.archetypes {
		col1 := archetype_get_column(arch, T1)
		for i in 0 ..< arch.count {
			callback(arch.entities[i], &col1[i])
		}
	}
}

for_each_2 :: proc(
	world: ^World,
	$T1: typeid,
	$T2: typeid,
	callback: proc(entity: Entity, c1: ^T1, c2: ^T2),
) {
	result := query(world, T1, T2)
	for arch in result.archetypes {
		col1 := archetype_get_column(arch, T1)
		col2 := archetype_get_column(arch, T2)
		for i in 0 ..< arch.count {
			callback(arch.entities[i], &col1[i], &col2[i])
		}
	}
}

for_each_3 :: proc(
	world: ^World,
	$T1: typeid,
	$T2: typeid,
	$T3: typeid,
	callback: proc(entity: Entity, c1: ^T1, c2: ^T2, c3: ^T3),
) {
	result := query(world, T1, T2, T3)
	for arch in result.archetypes {
		col1 := archetype_get_column(arch, T1)
		col2 := archetype_get_column(arch, T2)
		col3 := archetype_get_column(arch, T3)
		for i in 0 ..< arch.count {
			callback(arch.entities[i], &col1[i], &col2[i], &col3[i])
		}
	}
}
