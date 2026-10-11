class_name AvatarStyle
extends RefCounted
## Cosmetic choices players can pick. Sent over the wire as indices, so only
## append to these lists; reordering changes what existing players look like.

const COLORS: Array[Color] = [
	Color(0.85, 0.82, 0.75), # bone
	Color(0.45, 0.43, 0.48), # ash
	Color(0.62, 0.12, 0.12), # blood
	Color(0.30, 0.42, 0.22), # moss
	Color(0.38, 0.24, 0.45), # bruise
	Color(0.70, 0.36, 0.14), # rust
	Color(0.13, 0.40, 0.42), # deep teal
	Color(0.78, 0.64, 0.20), # mustard
]

const HATS: Array[String] = ["None", "Horns", "Top Hat", "Halo", "Antenna"]


static func color(index: int) -> Color:
	return COLORS[clean_color(index)]


static func clean_color(index: int) -> int:
	return index if index >= 0 and index < COLORS.size() else 0


static func clean_hat(index: int) -> int:
	return index if index >= 0 and index < HATS.size() else 0
