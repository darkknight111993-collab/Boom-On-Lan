class_name CShipAttr
extends Resource

## Static mount attribute record from Attr/ItemAttr (CA.exe RTTI .?AVCShipAttr@@ @ 0xe4853c, loaded by sub_89F3DE).
## Shared by all 12 mounts (Airship, AirshipBroken, Owl, Turtle0/1, Octopus0/1, RailCar, Chicken, Kart, Tank).

@export var id: int = 0
@export var ship_name: String = ""
@export var short_name: String = ""
@export var ship_type: int = 1 # 1 = ground, 2 = flying
@export var is_flying: bool = false
@export var speed: int = 5 # pixels per 30ms tick (normal ground)
@export var speed_alt: int = 0 # pixels per 30ms tick (special tile: rail/ice)
@export var ab_not_eat_item: bool = false # ability 1 (sub_89B0D4 -> sub_599BAC)
@export var ab_pass_box: bool = false # ability 2 (sub_89B0D4 -> sub_599B78)
@export var ab_kart: bool = false # ability 4 (sub_89B0D4 -> sub_599C0F)
@export var ab_tank: bool = false # ability 5 (sub_89B0D4 -> sub_599C68)

static func from_dict(entry: Dictionary) -> CShipAttr:
	var res: CShipAttr = new()
	res.id = int(entry.get("id", 0))
	res.ship_name = str(entry.get("name", ""))
	res.short_name = res.ship_name.substr(5) if res.ship_name.begins_with("Ship/") else res.ship_name
	var fields: Array = entry.get("fields", [])
	res.ship_type = int(fields[0]) if fields.size() > 0 else 1
	res.is_flying = res.ship_type == 2
	res.speed = int(fields[1]) if fields.size() > 1 else 5
	res.speed_alt = int(fields[2]) if fields.size() > 2 else 0
	for i in range(3, fields.size()):
		var f_val: int = int(fields[i])
		if f_val == 1:
			res.ab_not_eat_item = true
		elif f_val == 2:
			res.ab_pass_box = true
		elif f_val == 4:
			res.ab_kart = true
		elif f_val == 5:
			res.ab_tank = true
	return res

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": ship_name,
		"short_name": short_name,
		"ship_type": ship_type,
		"is_flying": is_flying,
		"speed": speed,
		"speed_alt": speed_alt,
		"ab_not_eat_item": ab_not_eat_item,
		"ab_pass_box": ab_pass_box,
		"ab_kart": ab_kart,
		"ab_tank": ab_tank,
	}
