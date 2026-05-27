## Floating damage number that rises and fades out.
## Spawned by the HUD in response to damage_popup_requested events.
extends Label3D

var _velocity: Vector3 = Vector3.UP * 2.0
var _lifetime: float = 0.0

func setup(amount: int, is_player_damage: bool) -> void:
	text = str(amount)
	if is_player_damage:
		modulate = Color(1.0, 0.3, 0.2)
	else:
		modulate = Color(1.0, 1.0, 1.0)
	font_size = 32
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true

func _process(delta: float) -> void:
	_lifetime += delta
	position += _velocity * delta
	_velocity *= 0.95

	var alpha := 1.0 - (_lifetime / Config.damage_popup_duration)
	modulate.a = maxf(0.0, alpha)

	if _lifetime >= Config.damage_popup_duration:
		queue_free()
