#!/usr/bin/env python3
"""Template-match VN UI sprites onto 800x600 screenshots in GameStage/ to recover exact (x, y) coords.

For every sprite frame drawn by CA.exe (CRenderD3D9::sub_68B7A0):
  draw_x = x - offset[0],  draw_y = y - offset[1]
So once we find the top-left (draw_x, draw_y) where frame PNG matches the 800x600 screenshot,
  x = draw_x + offset[0],  y = draw_y + offset[1].
"""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
FX = ROOT / "Client" / "Assets" / "fx"
SHOTS = ROOT / "GameStage"


def load_frame(sprite: str, frame_idx: int = 0):
    meta = json.loads((FX / sprite / "sprite.json").read_text(encoding="utf-8"))
    fr = meta["frames"][frame_idx]
    if fr.get("file") is None:
        fr = next(f for f in meta["frames"] if f.get("file"))
    im = Image.open(FX / sprite / fr["file"]).convert("RGBA")
    return im, fr["offset"], fr.get("extra", [im.width, im.height, 0, 0])


def sample_points(im: Image.Image, max_pts: int = 120):
    w, h = im.size
    px = im.load()
    step = max(1, int(((w * h) / max_pts) ** 0.5))
    pts = []
    for y in range(0, h, step):
        for x in range(0, w, step):
            r, g, b, a = px[x, y]
            if a >= 200:
                pts.append((x, y, r, g, b))
    if not pts:
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a >= 128:
                    pts.append((x, y, r, g, b))
    return pts


def match_sprite(shot_rgb: Image.Image, sprite: str, frame_idx: int = 0, roi=None):
    im, off, extra = load_frame(sprite, frame_idx)
    tw, th = im.size
    sw, sh = shot_rgb.size
    pts = sample_points(im, 140)
    spx = shot_rgb.load()

    x0, y0, x1, y1 = roi if roi else (0, 0, sw - tw, sh - th)
    x0 = max(0, x0); y0 = max(0, y0)
    x1 = min(sw - tw, x1); y1 = min(sh - th, y1)

    def score_at(ox, oy, sample):
        tot = 0
        for px, py, r, g, b in sample:
            sr, sg, sb = spx[ox + px, oy + py]
            tot += abs(sr - r) + abs(sg - g) + abs(sb - b)
        return tot / (len(sample) * 3)

    # Coarse pass (step 4)
    coarse_pts = pts[::2] if len(pts) > 40 else pts
    best = (999.0, x0, y0)
    for y in range(y0, y1 + 1, 4):
        for x in range(x0, x1 + 1, 4):
            sc = score_at(x, y, coarse_pts)
            if sc < best[0]:
                best = (sc, x, y)

    # Fine pass (+/- 5 px around coarse best)
    _, bx, by = best
    fine_pts = sample_points(im, 300)
    best = (999.0, bx, by)
    for y in range(max(y0, by - 5), min(y1, by + 5) + 1):
        for x in range(max(x0, bx - 5), min(x1, bx + 5) + 1):
            sc = score_at(x, y, fine_pts)
            if sc < best[0]:
                best = (sc, x, y)

    sc, dx, dy = best
    # CA.exe draws at anchor - offset => anchor = draw + offset
    ax, ay = dx + off[0], dy + off[1]
    return {"sprite": sprite, "frame": frame_idx, "draw": (dx, dy), "anchor": (ax, ay),
            "offset": tuple(off), "size": (tw, th), "err": round(sc, 1)}


def run_screen(shot_name: str, items: list):
    shot = Image.open(SHOTS / shot_name).convert("RGB").resize((800, 600), Image.Resampling.BILINEAR)
    print(f"\n=== {shot_name} (resized -> 800x600) ===")
    for item in items:
        sp, fr, roi = item if len(item) == 3 else (item[0], item[1], None)
        if not (FX / sp / "sprite.json").exists():
            print(f"  MISSING: {sp}")
            continue
        try:
            res = match_sprite(shot, sp, fr, roi)
            print(f"  {sp:42s} f={fr} draw={str(res['draw']):10s} anchor={str(res['anchor']):10s} off={str(res['offset']):9s} sz={str(res['size']):10s} err={res['err']}")
        except Exception as ex:
            print(f"  SKIP {sp}: {ex}")


if __name__ == "__main__":
    run_screen("LoginStage.png", [
        ("LoginStage/LO_LogTable00", 0, (160, 390, 220, 440)),
        ("LoginStage/LO_Bt1P", 0, (170, 410, 230, 460)),
        ("LoginStage/LO_Bt2P", 0, (500, 410, 560, 460)),
        ("LoginStage/LO_BtLogPW", 0, (170, 540, 220, 580)),
        ("LoginStage/LO_BtLogNewId", 0, (280, 540, 330, 580)),
        ("LoginStage/LO_BtLogOk", 0, (380, 540, 440, 580)),
        ("LoginStage/LO_BtLogExit", 0, (490, 540, 550, 580)),
    ])

    run_screen("SelectServerStage.png", [
        ("SelectServerStage/CH_GameMode_Normal_CA", 0, (280, 0, 520, 150)),
        ("SelectServerStage/CH_bt_GameModeSelectLeftArrow", 0, (240, 0, 360, 140)),
        ("SelectServerStage/CH_bt_GameModeSelectRightArrow", 0, (480, 0, 600, 140)),
        ("SelectServerStage/CH_Tab_Novice", 0, (390, 110, 480, 230)),
        ("SelectServerStage/CH_Tab_Free", 0, (460, 110, 560, 230)),
        ("SelectServerStage/CH_Tab_Special", 3, (520, 100, 680, 230)),
        ("SelectServerStage/CH_Tab_Event", 0, (630, 110, 760, 230)),
        ("SelectServerStage/CH_ChBar_Special", 0, (390, 200, 795, 280)),
        ("SelectServerStage/CH_Bt_Channel", 0, (410, 260, 595, 345)),
        ("SelectServerStage/CH_Bt_Channel", 0, (585, 260, 795, 345)),
        ("SelectServerStage/CH_Bt_Channel", 0, (410, 320, 595, 405)),
        ("SelectServerStage/CH_Bt_Channel", 0, (410, 380, 595, 465)),
        ("SelectServerStage/CH_Bt_Channel", 0, (410, 440, 595, 535)),
        ("SelectServerStage/CH_Bt_Left", 0, (460, 500, 560, 570)),
        ("SelectServerStage/CH_Bt_Right", 0, (640, 500, 740, 570)),
        ("GlobalUI/GlobalBar", 0, (0, 555, 800, 600)),
        ("GlobalUI/BtMenu", 0, (0, 560, 130, 600)),
        ("GlobalUI/BtBack", 0, (80, 560, 160, 600)),
        ("GlobalUI/BtShop", 0, (120, 560, 240, 600)),
        ("GlobalUI/BtSquare", 0, (200, 560, 300, 600)),
        ("GlobalUI/BtMessenger", 0, (240, 560, 350, 600)),
        ("GlobalUI/BtGachapon", 0, (440, 560, 580, 600)),
        ("GlobalUI/BtQuest", 0, (530, 560, 650, 600)),
        ("GlobalUI/BtMyInfo", 0, (610, 560, 720, 600)),
        ("GlobalUI/BtExit", 0, (730, 560, 800, 600)),
    ])

    run_screen("Lobby.png", [
        ("Lobby/LB_Bt_T_CreateRenew", 0, (200, 0, 420, 120)),
        ("Lobby/LB_Bt_T_QuickJoinRenew", 0, (340, 0, 540, 120)),
        ("Lobby/LB_Bt_T_GameTypeRenew", 0, (480, 0, 620, 120)),
        ("Lobby/LB_Bt_T_ShowAllRenew", 0, (560, 0, 720, 120)),
        ("Lobby/LB_Bt_T_PracticeRenew", 0, (660, 0, 800, 120)),
        ("Lobby/LB_Bt_SessionSlot", 0, (210, 60, 520, 200)),
        ("Lobby/LB_Bt_SessionSlot", 0, (480, 60, 795, 200)),
        ("Lobby/LB_Bt_SessionSlot", 0, (210, 150, 520, 280)),
        ("Lobby/LB_Bt_SessionSlot", 0, (210, 230, 520, 360)),
        ("Lobby/LB_Bt_RoomInfo", 0, (430, 100, 520, 180)),
        ("Lobby/LB_Bt_Left01", 0, (400, 310, 520, 390)),
        ("Lobby/LB_Bt_Right01", 0, (480, 310, 600, 390)),
        ("Lobby/LB_Bt_All", 0, (0, 220, 120, 320)),
        ("Lobby/LB_Bt_Guild", 0, (70, 220, 180, 320)),
        ("Lobby/LB_Bt_Left02", 0, (20, 500, 120, 580)),
        ("Lobby/LB_Bt_Right02", 0, (70, 500, 180, 580)),
        ("Etc/BtSpeaker_Speaker", 0, (720, 500, 800, 580)),
    ])

    run_screen("Room.png", [
        ("Prepare/PRE_Bt_Roominfo", 0, (300, 40, 480, 110)),
        ("Prepare/PRE_Bt_Selectmap", 0, (600, 380, 790, 500)),
        ("Prepare/PRE_Bt_Start", 0, (480, 470, 740, 570)),
        ("Prepare/PRE_Bt_CheckBox", 0, (690, 490, 780, 570)),
        ("Prepare/PRE_SelTeam-Basic00", 0, (470, 260, 540, 330)),
        ("Prepare/PRE_SelTeam-Basic01", 0, (490, 260, 580, 330)),
    ])

    run_screen("GameStage.png", [
        ("Game/BtExit", 0, (620, 530, 800, 600)),
        ("Game/Timer", 0, (690, 60, 790, 115)),
        ("Game/ItemBox01", 0, (630, 440, 790, 560)),
    ])
