class_name CGOShip
extends RefCounted

## Shared mount runtime entity (CA.exe RTTI .?AVCGOShip@@ @ 0xe30264, embedded at CGOBomber + 2104).
## Base class for all mounts (Airship, Owl, Turtle, Octopus, Chicken, RailCar, Kart, Tank) so future
## mount-specific behaviors (e.g. Shark/Kart/Tank) can extend CGOShip cleanly.

const CShipAttrClass = preload("res://scripts/objects/cship_attr.gd")
const MOUNT_TICKS := 15 # From sub_5A3F7D (0x5a47c3)
const DISMOUNT_TICKS := 50 # From sub_5A3F7D (0x5a47d4)
const KART_BOOST_TICKS := 12 # Ship/Kart states 08..11 Boost duration (4 frames x 3 ticks = 12 ticks @ 30ms, sub_5BCA63)
const KART_BOOST_COOLDOWN_TICKS := 33 # ~1.0s cooldown between Kart boosts
const TICK_SEC := 0.03

var attr: CShipAttrClass = null
var valid: bool = false
var variant: int = 0
var ride_count: int = 0
var speed_override: int = -1
var kart_fuel_ticks: int = -1 # >= 0 enables Kart fuel speed curve (ca.exe.c:349464..349476)
var kart_boosting: bool = false # sub_5BC639 (2x speed when boosting)
var kart_boost_ticks: int = 0
var kart_boost_cooldown_ticks: int = 0

func init_ship(ship_attr: CShipAttrClass, ship_variant: int = 0) -> bool:
	# From sub_5BC88E (CGOShip::Init)
	if ship_attr == null:
		clear()
		return false
	attr = ship_attr
	variant = ship_variant
	valid = true
	ride_count = MOUNT_TICKS
	speed_override = -1
	kart_fuel_ticks = -1
	kart_boosting = false
	kart_boost_ticks = 0
	kart_boost_cooldown_ticks = 0
	return true

func clear() -> void:
	attr = null
	valid = false
	variant = 0
	ride_count = 0
	speed_override = -1
	kart_fuel_ticks = -1
	kart_boosting = false
	kart_boost_ticks = 0
	kart_boost_cooldown_ticks = 0

func trigger_kart_boost() -> bool:
	# From sub_5BCBB5 / sub_5BC639: enters Boost state 8..11 for KART_BOOST_TICKS
	if not is_kart() or kart_boosting or kart_boost_cooldown_ticks > 0:
		return false
	kart_boosting = true
	kart_boost_ticks = KART_BOOST_TICKS
	kart_boost_cooldown_ticks = KART_BOOST_TICKS + KART_BOOST_COOLDOWN_TICKS
	return true

func tick_ship() -> void:
	if kart_boost_ticks > 0:
		kart_boost_ticks -= 1
		if kart_boost_ticks <= 0:
			kart_boosting = false
	if kart_boost_cooldown_ticks > 0:
		kart_boost_cooldown_ticks -= 1

func is_valid() -> bool:
	return valid and attr != null

func is_kart() -> bool:
	return is_valid() and (attr.id == 10 or attr.id == 11 or attr.ab_kart)

func is_shark() -> bool:
	return is_valid() and attr.id == 16

static func calc_kart_speed(base_speed: int, fuel_ticks: int, boosting: bool) -> int:
	# From sub_5A6244 @ ca.exe.c:349464..349476 & sub_5BC639
	var s: int = base_speed
	if fuel_ticks <= 0:
		s = 2
	elif fuel_ticks < 240:
		s = int(base_speed / 2)
	if boosting:
		s *= 2
	return s

static func calc_shark_variant(bombs_eaten: int) -> int:
	# From sub_5BC7C9 @ ca.exe.c:368373: 0 -> 0, 1..2 -> 1, >=3 -> 2
	if bombs_eaten <= 0:
		return 0
	return 2 if bombs_eaten >= 3 else 1

func update_shark_variant(bombs_eaten: int) -> int:
	if is_shark():
		variant = calc_shark_variant(bombs_eaten)
	return variant

func get_speed(on_special_tile: bool = false) -> int:
	# From sub_59EC93, sub_597EC6 (CGOShip::GetAltSpeed) & sub_5BC639 (Kart boost/fuel)
	if not is_valid():
		return 5
	if speed_override > 0:
		return speed_override
	var base: int = attr.speed_alt if (on_special_tile and attr.speed_alt > 0) else attr.speed
	if is_kart() and kart_fuel_ticks >= 0:
		return calc_kart_speed(base, kart_fuel_ticks, kart_boosting)
	if is_kart() and kart_boosting:
		return base * 2
	return base

func get_pixels_per_sec(on_special_tile: bool = false) -> float:
	# From sub_59EC93: ship speed is integer pixels per 30ms tick
	return float(get_speed(on_special_tile)) / TICK_SEC

func get_sprite_path(dir: int, shooting: bool = false) -> String:
	# From sub_5BC742 (CGOShip::ResolveSpriteName)
	if not is_valid():
		return ""
	var dirs_capital: Array[String] = ["-Down", "-Up", "-Left", "-Right"]
	var dirs_lower: Array[String] = ["_down", "_up", "_left", "_right"]
	var dirs_kart: Array[String] = ["_Down", "_Up", "_Left", "_Right"]
	var clean_id: String = attr.short_name
	if clean_id == "Tank" or clean_id == "MonS2Tank":
		var suffix: String = dirs_lower[dir]
		if shooting:
			suffix += "_shooting"
		return "Ship/Tank" + suffix
	if clean_id.begins_with("Kart"):
		if kart_boosting:
			return "Ship/KartBoost" + dirs_kart[dir]
		return "Ship/Kart" + dirs_kart[dir]
	if clean_id == "Chicken":
		return "Ship/Chicken_Box00" + dirs_capital[dir]
	if is_shark():
		return "Ship/%s%02d%s" % [clean_id, variant, dirs_capital[dir]]
	return "Ship/" + clean_id + dirs_capital[dir]

static func calc_jump_arc_dy(c: int) -> int:
	# From sub_5990D6 (CGOBomber::GetShipRenderPos): integer division matches x86 idiv
	if c > 0:
		var term: int = int(3 * c / 2) - 13
		return int(16 * term * term / 169) - 16
	if c > -30:
		var term: int = c + 17
		return int(36 * term * term / 169) - 36
	return 0

static func calc_visible_for_ride_count(c: int) -> bool:
	# From sub_59923A (CGOBomber::RenderShip)
	if c >= 0:
		return true
	return c <= -10 and ((-c) % 8) >= 4

func to_mount_dict() -> Dictionary:
	if not is_valid():
		return {}
	return {
		"id": attr.short_name,
		"short_name": attr.short_name,
		"speed": get_speed(false),
		"speed_alt": attr.speed_alt,
		"can_pass_box": attr.ab_pass_box,
		"can_shoot": attr.ab_tank,
		"is_kart": attr.ab_kart,
		"is_flying": attr.is_flying,
		"ab_not_eat_item": attr.ab_not_eat_item,
	}
