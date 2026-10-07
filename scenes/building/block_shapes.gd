class_name BlockShapes
extends RefCounted
## Grid math and meshes for building blocks, shared by the server (placement
## checks) and clients (held block, preview, placed block).
## A block is anchored at its minimum cell; axis 0 = upright, 1 = lying along X,
## 2 = lying along Z.

## Leaves a visible seam between neighbouring blocks.
const INSET := 0.015


static func size_cells(type_id: int, axis: int) -> Vector3i:
	return Economy.oriented_size(type_id, axis)


static func size_m(type_id: int, axis: int) -> Vector3:
	return Vector3(size_cells(type_id, axis)) * Economy.CELL


static func center(cell: Vector3i, type_id: int, axis: int) -> Vector3:
	return (Vector3(cell) + Vector3(size_cells(type_id, axis)) * 0.5) * Economy.CELL


## The anchor cell that puts a block's centre as close as possible to a point.
static func cell_for_center(point: Vector3, type_id: int, axis: int) -> Vector3i:
	var corner := point / Economy.CELL - Vector3(size_cells(type_id, axis)) * 0.5
	return Vector3i(roundi(corner.x), roundi(corner.y), roundi(corner.z))


static func cells(cell: Vector3i, type_id: int, axis: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var size := size_cells(type_id, axis)
	for x in size.x:
		for y in size.y:
			for z in size.z:
				out.append(cell + Vector3i(x, y, z))
	return out


static func make_mesh(type_id: int, axis: int) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = size_m(type_id, axis) - Vector3.ONE * INSET * 2.0
	return box


static func material(type_id: int) -> Material:
	return MapMaterials.get_material(Economy.BLOCKS[type_id].surface)


## Which way a held block should lie: along the world axis its long side
## (the block's local Y) points most closely to.
static func axis_from_basis(basis: Basis) -> int:
	var up := basis.y.abs()
	if up.y >= up.x and up.y >= up.z:
		return 0
	return 1 if up.x >= up.z else 2
