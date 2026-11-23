#!/usr/bin/env python3
"""Extract + CRC-verify VN client data tables from AnalizeVNClient/fx.idd + fx_masks.json -> Client/data/."""
import json
import struct
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VN = ROOT / "AnalizeVNClient"
OUT = ROOT / "Client" / "data"

sys.path.insert(0, str(ROOT / "AnalizeTWClient" / "tools"))
import decrypt as d  # entry_decrypt, checksum


def u32(b: bytes, o: int) -> int:
    return struct.unpack_from("<I", b, o)[0]


def read_str(b: bytes, o: int) -> tuple[str, int]:
    n = u32(b, o)
    s = b[o + 4 : o + 4 + n].rstrip(b"\0").decode("cp949", errors="replace")
    return s, o + 4 + n


def read_entry(idd, masks: dict, path: str) -> bytes:
    e = masks[path]
    idd.seek(e["offset"])
    raw = idd.read(e["size"])
    dec = d.entry_decrypt(raw, e["mask"])
    if e["mask"] and e["checksum"] not in (0, 1):
        crc = d.checksum(dec, e["mask"])
        assert crc == e["checksum"], f"CRC mismatch {path}: {crc:08x} != {e['checksum']:08x}"
    return dec


def parse_objecttable(b: bytes) -> list[dict]:
    cnt = u32(b, 0)
    o = 4
    index = []
    for i in range(cnt):
        ln = u32(b, o); o += 4
        name = b[o : o + ln].decode("cp949", errors="replace"); o += ln
        off = u32(b, o); o += 4
        index.append((i, name, off))

    out = []
    for i, name, off in index:
        if off == 0xFFFFFFFF:
            out.append({"id": i, "name": name, "states": None})
            continue
        p = off
        sc = u32(b, p); p += 4
        states = []
        for _ in range(sc):
            sname, p = read_str(b, p)
            sprite, p = read_str(b, p)
            fc = u32(b, p); p += 4
            frames = []
            for _ in range(fc):
                idx, dur = struct.unpack_from("<ii", b, p); p += 8
                frames.append([idx, dur])
            states.append({"state": sname, "sprite": sprite, "frames": frames})
        out.append({"id": i, "name": name, "states": states})
    return out


def parse_tile_info(b: bytes) -> dict:
    n = u32(b, 0)
    root = ET.fromstring(b[4 : 4 + n].decode("cp949", errors="replace"))
    tiles = {}
    for t in root.iter("Tile"):
        raw = bytes.fromhex(t.attrib["Data"])
        dw = struct.unpack("<13I", raw)
        tiles[t.attrib["Name"]] = {
            "type": dw[0],  # 0=ground, 1=static, 2=box, 3=passable
            "width": dw[1],
            "height": dw[2],
            "raw": raw.hex(),
        }
    return tiles


def parse_bomber_attr(b: bytes) -> list[dict]:
    o = 0
    chars = []
    while o < len(b):
        name, o = read_str(b, o)
        # VN adds a leading id dword before the 10 TW stats -> 11 dwords total
        st = list(struct.unpack_from("<11I", b, o)); o += 44
        chars.append({
            "id": st[0],
            "name": name,
            "class": st[1],
            "base_speed": st[2], "max_speed": st[3],
            "base_bomb": st[4], "max_bomb": st[5],
            "base_power": st[6], "max_power": st[7],
            "stats": st,
        })
    assert o == len(b), f"BomberAttr trailing bytes: {len(b) - o}"
    return chars


def parse_item_attr(b: bytes) -> dict:
    hdr = list(struct.unpack_from("<3I", b, 0))
    o = 12
    cats = []
    for _ in range(hdr[2]):
        cid = u32(b, o); o += 4
        name, o = read_str(b, o)
        fields = list(struct.unpack_from("<8I", b, o)); o += 32
        cats.append({"id": cid, "name": name, "fields": fields})
    items = []
    while o < len(b):
        n1, o = read_str(b, o)
        n2, o = read_str(b, o)
        # VN items have 8 dwords (same as TW)
        fields = list(struct.unpack_from("<8I", b, o)); o += 32
        items.append({"name": n1, "sprite": n2, "fields": fields})
    assert o == len(b), f"ItemAttr trailing bytes: {len(b) - o}"
    return {"header": hdr, "categories": cats, "items": items}


def parse_map_group(b: bytes) -> list[dict]:
    o = 0
    n = u32(b, o); o += 4
    groups = []
    for _ in range(n):
        name, o = read_str(b, o)
        cnt = u32(b, o); o += 4
        maps = []
        for _ in range(cnt):
            m, o = read_str(b, o)
            maps.append(m)
        groups.append({"name": name, "maps": maps})
    assert o == len(b), f"MapGroup trailing bytes: {len(b) - o}"
    return groups


def parse_nametable(b: bytes) -> list[str]:
    n = u32(b, 0)
    root = ET.fromstring(b[4 : 4 + n].decode("cp949", errors="replace"))
    return [el.attrib["name"] for el in root.iter("Desc") if "name" in el.attrib]


def parse_client_strings(b: bytes) -> dict[str, str]:
    n = u32(b, 0)
    root = ET.fromstring(b[4 : 4 + n].decode("utf-16", errors="replace"))
    out = {}
    for el in root.iter("Elem"):
        k = el.findtext("key")
        v = el.findtext("string")
        if k is not None and v is not None:
            out[k] = v
    return out


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    masks_list = json.loads((VN / "fx_masks.json").read_text(encoding="utf-8"))
    masks = {e["path"]: e for e in masks_list}

    with (VN / "fx.idd").open("rb") as idd:
        # 1. Verify CRC of every encrypted entry in VN fx.idd
        enc_ok = 0
        for e in masks_list:
            if e["mask"]:
                read_entry(idd, masks, e["path"])
                enc_ok += 1

        # 2. Extract core tables
        obj = parse_objecttable(read_entry(idd, masks, "ObjectTable/ObjectTable"))
        tiles = parse_tile_info(read_entry(idd, masks, "TileInfo/TileInfoList"))
        bombers = parse_bomber_attr(read_entry(idd, masks, "Attr/BomberAttr"))
        items = parse_item_attr(read_entry(idd, masks, "Attr/ItemAttr"))
        groups = parse_map_group(read_entry(idd, masks, "Attr/MapGroup"))
        names = parse_nametable(read_entry(idd, masks, "ObjectTable/NameTable"))
        strings = parse_client_strings(read_entry(idd, masks, "ClientData/ClientString"))

        # 3. Verify all Map/* entries match existing Client/Assets/fx/Map/*/map.json masks
        map_entries = [e for e in masks_list if e["path"].startswith("Map/")]
        map_ok = 0
        map_missing = []
        for e in map_entries:
            mname = e["path"][4:]
            mj_path = ROOT / "Client" / "Assets" / "fx" / "Map" / mname / "map.json"
            if not mj_path.exists():
                map_missing.append(mname)
                continue
            mj = json.loads(mj_path.read_text(encoding="utf-8"))
            if mj.get("mask") == e["mask"]:
                map_ok += 1
            else:
                map_missing.append(f"{mname}(mask_diff)")

    (OUT / "objecttable.json").write_text(json.dumps(obj, ensure_ascii=False, indent=1), encoding="utf-8")
    (OUT / "tile_info.json").write_text(json.dumps(tiles, ensure_ascii=False, indent=1), encoding="utf-8")
    (OUT / "bomber_attr.json").write_text(json.dumps(bombers, ensure_ascii=False, indent=1), encoding="utf-8")
    (OUT / "item_attr.json").write_text(json.dumps(items, ensure_ascii=False, indent=1), encoding="utf-8")
    (OUT / "map_group.json").write_text(json.dumps(groups, ensure_ascii=False, indent=1), encoding="utf-8")
    (OUT / "nametable.json").write_text(json.dumps(names, ensure_ascii=False, indent=1), encoding="utf-8")
    (OUT / "client_strings.json").write_text(json.dumps(strings, ensure_ascii=False, indent=1), encoding="utf-8")

    print(
        f"CRC-verified {enc_ok} encrypted entries | "
        f"objecttable={len(obj)} tile_info={len(tiles)} bombers={len(bombers)} "
        f"items={len(items['items'])} map_groups={len(groups)} nametable={len(names)} "
        f"client_strings={len(strings)} maps_verified={map_ok}/{len(map_entries)} missing={len(map_missing)}"
    )
    if map_missing:
        print("Map mismatches:", map_missing[:10])


if __name__ == "__main__":
    main()
