#!/usr/bin/env python3
"""Render all 5 Godot screen JSONs (+ live 15x13 map on game_stage) to PNGs for visual verification."""
import json
from pathlib import Path
from PIL import Image, ImageColor

ROOT = Path(__file__).resolve().parents[2]
FX = ROOT / "Client" / "Assets" / "fx"
DATA = ROOT / "Client" / "data"
OUT = ROOT / "Client" / "previews"
OUT.mkdir(parents=True, exist_ok=True)


def render_map_into(canvas: Image.Image, map_name: str = "Camp08") -> None:
    obj_list = json.loads((DATA / "objecttable.json").read_text(encoding="utf-8"))
    table = {int(t["id"]): t for t in obj_list}
    mpath = FX / "Map" / map_name / "map.json"
    if not mpath.exists():
        mpath = FX / "Map" / "Factory15" / "map.json"
    m = json.loads(mpath.read_text(encoding="utf-8"))
    cols, rows = min(int(m["cols"]), 15), min(int(m["rows"]), 13)
    ox = 40 * (15 - cols) // 2 + 20
    oy = 40 * (13 - rows) // 2 + 41

    sprite_cache = {}
    def get_frame(obj_id: int):
        if obj_id < 0 or obj_id not in table or not table[obj_id]["states"]:
            return None
        states = table[obj_id]["states"]
        st = next((s for s in states if s["state"] == "Default"), states[0])
        if not st["frames"]:
            return None
        sp, fidx = st["sprite"], int(st["frames"][0][0])
        key = (sp, fidx)
        if key not in sprite_cache:
            mp = FX / sp / "sprite.json"
            if not mp.exists():
                sprite_cache[key] = None
            else:
                meta = json.loads(mp.read_text(encoding="utf-8"))
                if 0 <= fidx < len(meta["frames"]) and meta["frames"][fidx].get("file"):
                    fr = meta["frames"][fidx]
                    im = Image.open(FX / sp / fr["file"]).convert("RGBA")
                    sprite_cache[key] = (im, fr["offset"])
                else:
                    sprite_cache[key] = None
        return sprite_cache[key]

    for layer in ("ground", "object"):
        for y in range(rows):
            for x in range(cols):
                res = get_frame(int(m["grid"][y][x][layer]))
                if not res:
                    continue
                im, off = res
                # CGOTile::sub_45D6CA anchor=(40*x, 40*y+39); CRenderD3D9::sub_68B7A0 draws at anchor - offset
                px = ox + x * 40 - off[0]
                py = oy + y * 40 + 39 - off[1]
                canvas.paste(im, (px, py), im)


def paste_elements(canvas: Image.Image, elements: list, ox: int = 0, oy: int = 0, screen_name: str = "") -> None:
    for i, e in enumerate(elements):
        x, y = ox + int(e["x"]), oy + int(e["y"])
        kind = e["kind"]
        if kind == "jpg":
            bg = Image.open(FX / e["sprite"] / "image.jpg").convert("RGBA")
            canvas.paste(bg, (x, y))
            if screen_name == "game_stage" and i == 0:
                render_map_into(canvas, "Camp08")
        elif kind == "color_rect":
            c = ImageColor.getrgb(e.get("color", "#003875"))
            rect_im = Image.new("RGBA", (int(e["w"]), int(e["h"])), c + (255,))
            canvas.paste(rect_im, (x, y))
        elif kind in ("image", "button"):
            sp = e["sprite"]
            meta_path = FX / sp / "sprite.json"
            if not meta_path.exists():
                print(f"  WARN missing {sp}")
                continue
            sdata = json.loads(meta_path.read_text(encoding="utf-8"))
            frame_idx = int(e.get("frame", 0))
            if frame_idx >= len(sdata["frames"]) or not sdata["frames"][frame_idx].get("file"):
                print(f"  WARN missing frame {frame_idx} of {sp}")
                continue
            fr = sdata["frames"][frame_idx]
            img = Image.open(FX / sp / fr["file"]).convert("RGBA")
            off_x, off_y = fr["offset"][0], fr["offset"][1]
            # CA.exe (CRenderD3D9::sub_68B7A0): draw_pos = anchor - offset
            canvas.paste(img, (x - off_x, y - off_y), img)
        elif kind == "mode_strip":
            cx = x
            clip_right = x + int(e["w"])
            for mi, m in enumerate(e["modes"]):
                sp = m["sprite"]
                sdata = json.loads((FX / sp / "sprite.json").read_text(encoding="utf-8"))
                fr = sdata["frames"][3 if mi == 0 else 0]
                img = Image.open(FX / sp / fr["file"]).convert("RGBA")
                if cx >= clip_right:
                    break
                # draw relative to 186px tall card strip (offset y=-10 shifts normal down 10px)
                dy = -fr["offset"][1]
                crop_w = min(img.width, clip_right - cx)
                canvas.paste(img.crop((0, 0, crop_w, img.height)), (cx, y + dy), img.crop((0, 0, crop_w, img.height)))
                if m.get("sub_icons") and cx + img.width <= clip_right:
                    for si, sub in enumerate(m["sub_icons"]):
                        smeta = json.loads((FX / sub["sprite"] / "sprite.json").read_text(encoding="utf-8"))
                        simg = Image.open(FX / sub["sprite"] / smeta["frames"][0]["file"]).convert("RGBA")
                        canvas.paste(simg, (cx + 14, y + 54 + si * 33), simg)
                cx += img.width + 3


def render_screen(screen_name: str) -> Path:
    data = json.loads((DATA / "screens" / f"{screen_name}.json").read_text(encoding="utf-8"))
    canvas = Image.new("RGBA", (800, 600), (0, 0, 0, 255))
    paste_elements(canvas, data["elements"], 0, 0, screen_name)
    out_path = OUT / f"preview_{screen_name}.png"
    canvas.save(out_path)
    print(f"Rendered {screen_name} -> {out_path}")
    return out_path


def render_dialog_preview(screen_name: str, dlg_id: str) -> Path:
    base = Image.open(OUT / f"preview_{screen_name}.png").convert("RGBA")
    dialogs = json.loads((DATA / "dialogs.json").read_text(encoding="utf-8"))
    d = dialogs[dlg_id]
    if d.get("modal", True):
        dim = Image.new("RGBA", (800, 600), (0, 0, 0, 90))
        base = Image.alpha_composite(base, dim)
    paste_elements(base, d["elements"], int(d["x"]), int(d["y"]))
    out_path = OUT / f"preview_dlg_{dlg_id}.png"
    base.save(out_path)
    print(f"Rendered dialog {dlg_id} on {screen_name} -> {out_path}")
    return out_path


if __name__ == "__main__":
    for name in ("login", "select_server", "lobby", "prepare", "game_stage"):
        render_screen(name)
    if (DATA / "dialogs.json").exists():
        for scr, dlg in (
            ("login", "notice"),
            ("login", "forgot_pw"),
            ("login", "register"),
            ("login", "login_wait"),
            ("lobby", "create_room"),
            ("prepare", "select_map"),
            ("lobby", "option"),
            ("lobby", "tutorial"),
        ):
            render_dialog_preview(scr, dlg)
