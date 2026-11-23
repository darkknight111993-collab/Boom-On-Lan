class_name CItemAttr
extends RefCounted

## CItemAttr - Nạp và tra cứu dữ liệu thuộc tính vật phẩm từ item_attr.json
## Phản ánh cấu trúc CItemAttr trong CA.exe

const CShipAttrClass = preload("res://scripts/objects/cship_attr.gd")

static var _data: Dictionary = {}
static var _items: Array = []
static var _ships_by_id: Dictionary = {}
static var _ships_by_name: Dictionary = {}
static var _ship_res_by_id: Dictionary = {}
static var _ship_res_by_name: Dictionary = {}
static var _drop_pool: Array = []
static var _total_drop_weight: int = 0
static var _loaded: bool = false

static func load_data(file_path: String = "res://data/item_attr.json") -> void:
	if _loaded and not _data.is_empty():
		return
	if not FileAccess.file_exists(file_path):
		push_warning("CItemAttr: File not found: %s" % file_path)
		return
	var f := FileAccess.open(file_path, FileAccess.READ)
	if not f:
		push_warning("CItemAttr: Failed to open %s" % file_path)
		return
	var text := f.get_as_text()
	var json := JSON.new()
	if json.parse(text) == OK and json.data is Dictionary:
		_data = json.data
		_items = _data.get("items", [])
		_build_ship_table(_data.get("categories", []))
		_build_drop_pool()
		_loaded = true
	else:
		push_error("CItemAttr: Invalid JSON in %s" % file_path)

static func _build_ship_table(cats: Array) -> void:
	_ships_by_id.clear()
	_ships_by_name.clear()
	_ship_res_by_id.clear()
	_ship_res_by_name.clear()
	for entry in cats:
		if not entry is Dictionary:
			continue
		var res: CShipAttrClass = CShipAttrClass.from_dict(entry)
		var ship_info: Dictionary = res.to_dict()
		_ship_res_by_id[res.id] = res
		_ship_res_by_name[res.ship_name] = res
		_ship_res_by_name[res.short_name] = res
		_ships_by_id[res.id] = ship_info
		_ships_by_name[res.ship_name] = ship_info
		_ships_by_name[res.short_name] = ship_info

static func get_ship_resource(ship_key: Variant) -> CShipAttrClass:
	if not _loaded:
		load_data()
	if ship_key is int or (ship_key is float and int(ship_key) == ship_key):
		return _ship_res_by_id.get(int(ship_key), null)
	var k := str(ship_key)
	if _ship_res_by_name.has(k):
		return _ship_res_by_name[k]
	if k.begins_with("Ship/") and _ship_res_by_name.has(k.substr(5)):
		return _ship_res_by_name[k.substr(5)]
	if not k.begins_with("Ship/") and _ship_res_by_name.has("Ship/" + k):
		return _ship_res_by_name["Ship/" + k]
	if k == "MonS2Tank":
		return get_ship_resource("Tank")
	if k == "Kart0":
		return get_ship_resource("Kart")
	return null

static func get_ship_attr(ship_key: Variant) -> Dictionary:
	var res: CShipAttrClass = get_ship_resource(ship_key)
	return res.to_dict() if res != null else {}

static func _build_drop_pool() -> void:
	_drop_pool.clear()
	_total_drop_weight = 0
	for it in _items:
		if not it is Dictionary:
			continue
		var fields: Array = it.get("fields", [])
		if fields.size() > 0:
			var weight: int = int(fields[0])
			if weight > 0:
				var item_name: String = it.get("name2", it.get("name", ""))
				_drop_pool.append({
					"name": item_name,
					"weight": weight,
					"item": it
				})
				_total_drop_weight += weight

static func get_total_weight() -> int:
	if not _loaded:
		load_data()
	return _total_drop_weight

static func get_random_drop_item(rng: RandomNumberGenerator = null) -> String:
	if not _loaded:
		load_data()
	if _drop_pool.is_empty() or _total_drop_weight <= 0:
		return "Item/Bomb"
	
	var roll: int = rng.randi_range(0, _total_drop_weight - 1) if rng else randi() % _total_drop_weight
	var acc: int = 0
	for entry in _drop_pool:
		acc += entry.weight
		if roll < acc:
			return entry.name
	return _drop_pool[0].name

static func is_ship_or_item_name(obj_name: String) -> bool:
	# From sub_8D8DA0 (IsShipOrItemName)
	return obj_name.begins_with("Ship/") or obj_name.begins_with("Item/")

static func get_item_info(item_name: String) -> Dictionary:
	if not _loaded:
		load_data()
	for it in _items:
		if it is Dictionary:
			if it.get("name2", "") == item_name or it.get("name", "") == item_name:
				return it
	return {}
