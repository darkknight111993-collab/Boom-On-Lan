class_name CShopItemMan
extends RefCounted

## Shop catalog manager (CA.exe .?AVCShopItemMan@@ @ 0xe48660, ctor 0x8B1D42, dtor 0x8B2AD6).
## Pure headless-testable catalog loader, 5-tab/currency/keyword filter, and paginator.

const DEFAULT_CATALOG_PATH: String = "res://data/shop_catalog.json"
const VALID_TABS: Array[String] = ["special", "item", "set", "char", "slot"]

var catalog: Array[Dictionary] = []

func _init(auto_load: bool = true) -> void:
	if auto_load:
		load_catalog(DEFAULT_CATALOG_PATH)

func load_catalog(path: String = DEFAULT_CATALOG_PATH) -> void:
	catalog.clear()
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Array):
		return
	for entry: Variant in parsed:
		if entry is Dictionary:
			catalog.append((entry as Dictionary).duplicate(true))

func get_items(tab: String, sub_tab: String = "all", currency_filter: String = "all", keyword: String = "") -> Array[Dictionary]:
	var norm_tab: String = tab.strip_edges().to_lower()
	var norm_sub: String = sub_tab.strip_edges().to_lower()
	var norm_cur: String = currency_filter.strip_edges().to_lower()
	var norm_kw: String = keyword.strip_edges().to_lower()
	var result: Array[Dictionary] = []
	for entry: Dictionary in catalog:
		if norm_tab != "" and norm_tab != "all" and str(entry.get("tab", "")).to_lower() != norm_tab:
			continue
		if norm_sub != "" and norm_sub != "all" and str(entry.get("sub_tab", "")).to_lower() != norm_sub:
			continue
		if norm_cur != "" and norm_cur != "all" and str(entry.get("currency", "")).to_lower() != norm_cur:
			continue
		if norm_kw != "":
			var name_vn: String = str(entry.get("name_vn", "")).to_lower()
			var item_id: String = str(entry.get("id", "")).to_lower()
			var item_code: String = str(entry.get("item_code", "")).to_lower()
			if not name_vn.contains(norm_kw) and not item_id.contains(norm_kw) and not item_code.contains(norm_kw):
				continue
		result.append(entry)
	return result

func get_page(items: Array[Dictionary], page: int, page_size: int = 8) -> Dictionary:
	var ps: int = maxi(page_size, 1)
	var total_pages: int = maxi(1, int(ceili(float(items.size()) / float(ps))))
	var clamped_page: int = clampi(page, 0, total_pages - 1)
	var start_idx: int = clamped_page * ps
	var end_idx: int = mini(start_idx + ps, items.size())
	var page_items: Array[Dictionary] = []
	for i in range(start_idx, end_idx):
		page_items.append(items[i])
	return {
		"items": page_items,
		"page": clamped_page,
		"total_pages": total_pages,
	}

func get_item_by_id(item_id: String) -> Dictionary:
	for entry: Dictionary in catalog:
		if str(entry.get("id", "")) == item_id:
			return entry
	return {}
