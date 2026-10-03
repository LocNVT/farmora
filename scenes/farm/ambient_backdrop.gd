class_name AmbientBackdrop
extends Node2D

## Placeholder ambient backdrop drift/sway (Phase 9 Task 9 item 6):
## simple cloud shapes drifting slowly across the sky layer, and grass
## tufts swaying gently in the meadow/soil layer. Attached to a node
## added under FarmWorld's existing `Backdrop` container (farm_world.tscn
## is never itself instanced/inherited elsewhere, so adding children to
## its Backdrop subtree carries none of AnimalView's inherited-scene-
## with-indices risk -- verified before this file was added).
##
## Purely decorative/visual: never touches Game.state, never read by any
## other system. Respects Motion.reduced (Task 9 rule 7): all drift/sway
## stops/freezes when reduced motion is on.

## Cloud drift speed (this task's spec: "~8 dp/s").
const CLOUD_SPEED := 8.0
## Grass sway: a small angular oscillation, not a translation.
const GRASS_SWAY_DEGREES := 4.0
const GRASS_SWAY_SECONDS := 2.6

var _cloud_nodes: Array[Node2D] = []
var _cloud_start_x: Array[float] = []
var _cloud_wrap_width: float = 1200.0
var _grass_nodes: Array[Node2D] = []
var _time: float = 0.0

func _ready() -> void:
	for child: Node in get_children():
		if child.name.begins_with("Cloud"):
			var node2d: Node2D = child as Node2D
			if node2d != null:
				_cloud_nodes.append(node2d)
				_cloud_start_x.append(node2d.position.x)
		elif child.name.begins_with("GrassTuft"):
			var node2d: Node2D = child as Node2D
			if node2d != null:
				_grass_nodes.append(node2d)

func _process(delta: float) -> void:
	if Motion.reduced:
		return
	_time += delta
	for i in range(_cloud_nodes.size()):
		var cloud: Node2D = _cloud_nodes[i]
		cloud.position.x += CLOUD_SPEED * delta
		var start_x: float = _cloud_start_x[i]
		if cloud.position.x > start_x + _cloud_wrap_width:
			cloud.position.x = start_x
	for grass: Node2D in _grass_nodes:
		grass.rotation = deg_to_rad(GRASS_SWAY_DEGREES) * sin(_time / GRASS_SWAY_SECONDS * TAU)
