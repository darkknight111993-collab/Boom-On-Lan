#!/usr/bin/env python3
"""Generates Client/data/game_modes.json by categorizing all extracted maps
according to BnB original client game modes and MapGroup data.
"""
import os, json, re

MAP_DIR = os.path.join(os.path.dirname(__file__), '..', 'Assets', 'fx', 'Map')
OUT_FILE = os.path.join(os.path.dirname(__file__), '..', 'data', 'game_modes.json')

all_maps = sorted([m for m in os.listdir(MAP_DIR) if os.path.isdir(os.path.join(MAP_DIR, m))])

def natural_sort_key(s):
    return [int(text) if text.isdigit() else text.lower() for text in re.split(r'(\d+)', s)]

def is_test_map(m):
    return m.startswith('DevTest') or m.endswith('Test') or '_test' in m.lower() or 'test_' in m.lower()

monster_prefixes = [
    'Monster', 'MonGolem', 'MonPen', 'MonRobot', 'MonSeal', 'MonSnowBear', 'MonTurtle',
    'MonS2Fire', 'MonS2Sand', 'MonBig', 'MonHorde', 'MonUnlimited', 'IamBoss', 'iamboss', 'DarkKnight', 'Wriggle'
]
superf_prefixes = ['SuperFighter', 'Super2Fighter', 'Super2Special', 'SuperSpecial', 'Super', 'FighterOfLegend']
zzolman_prefixes = ['Zzolman']
snowball_prefixes = ['SnowBallFight', 'BonusSnowBall']
battle_prefixes = ['Ladder', 'Tournament', 'NXCL_', 'WS_', 'WinningStreak_', 'GoldFlag', 'ConfusedFight']
rpg_prefixes = ['CAhero', 'RPG', 'BonusBigRPG']

mode_maps = {
    'normal': [],
    'gametype': [],
    'battle': [],
    'monster2': [],
    'superf2': [],
    'zzolman': [],
    'snowball': [],
    'rpg': []
}

# 1. Assign specialized non-normal game modes first
for m in all_maps:
    if is_test_map(m):
        continue
    if any(m.startswith(p) for p in monster_prefixes):
        mode_maps['monster2'].append(m)
    elif any(m.startswith(p) for p in superf_prefixes):
        mode_maps['superf2'].append(m)
    elif any(m.startswith(p) for p in zzolman_prefixes):
        mode_maps['zzolman'].append(m)
    elif any(m.startswith(p) for p in snowball_prefixes):
        mode_maps['snowball'].append(m)
    elif any(m.startswith(p) for p in battle_prefixes):
        mode_maps['battle'].append(m)
    elif any(m.startswith(p) for p in rpg_prefixes):
        mode_maps['rpg'].append(m)

for k in ['battle', 'monster2', 'superf2', 'zzolman', 'snowball', 'rpg']:
    mode_maps[k].sort(key=natural_sort_key)

# 2. Normal PVP Mode (Đại Chiến)
# Excludes: single-player bonus stages (Bonus*), lobby/square/shops (Lobby*, Square*, shopmap*),
# minigames (olympic*, GolemRun*, WhiteAngel*), dev test maps, zombie maps.
# Canonical ordering: Ladder / Hot maps first, then themes in standard Boom Online order.
top_maps = [
    'Camp08', 'Village10', 'Factory07', 'Forest07', 'Patrit14', 'Tomb12',
    'Ocean02', 'Desert00', 'Ice13', 'Mine01', 'Xmas03', 'Bula01',
    'PangLand15', 'Cemetery01', 'Aqua01', 'Cookie02'
]

theme_order = [
    'Camp', 'ExCamp', 'EventCamp',
    'Village', 'ExVillage',
    'Factory', 'ExFactory', 'EventFactory',
    'Forest', 'forest', 'ExForest', 'EventForest',
    'Tomb', 'ExTomb',
    'Patrit', 'patrit', 'ExPatrit', 'EventPatrit',
    'Ice',
    'Desert',
    'Mine', 'mine',
    'Ocean', 'EventOcean', 'SeaFields', 'seafields',
    'Cemetery',
    'Xmas', 'xmas',
    'Cookie',
    'KFG', 'Kfg', 'kfg',
    'PangLand', 'Pangland',
    'Aqua',
    'Bula', 'ExBula',
    'Rabbit',
    'BlackRabbit',
    'Javelin',
    'Clover',
    'Pharaoh',
    'Kart',
    'SnowyFields', 'Antarctic',
    'Hidden',
    'UserContest'
]

seen_normal = set()
for m in top_maps:
    if m in all_maps and m not in seen_normal:
        mode_maps['normal'].append(m)
        seen_normal.add(m)

for theme in theme_order:
    theme_maps = []
    for m in all_maps:
        if m in seen_normal or is_test_map(m):
            continue
        if m.startswith(theme):
            theme_maps.append(m)
    theme_maps.sort(key=natural_sort_key)
    for m in theme_maps:
        if m not in seen_normal:
            mode_maps['normal'].append(m)
            seen_normal.add(m)

# 3. Gametype Mode (Kiểu Chơi: Đội trưởng, Săn nhím, Sinh tồn, Hẹn giờ)
# Canonical maps from LadderMapGroup + PraticeMapGroup + popular battle maps
popular_gametype = [
    'Camp08', 'Village10', 'Factory07', 'Forest07', 'Patrit14', 'Tomb12',
    'Village00', 'Village05', 'Village06', 'Village09',
    'Factory00', 'Factory02',
    'Forest02', 'Forest03', 'Forest12', 'Forest14',
    'Desert00', 'Desert03', 'Desert04', 'Desert06', 'Desert07',
    'Ice00', 'Ice01', 'Ice06', 'Ice07', 'Ice09', 'Ice13',
    'Mine00', 'Mine01', 'Mine02', 'Mine05', 'Mine06',
    'Ocean00', 'Ocean01', 'Ocean02', 'Ocean04', 'Ocean08',
    'Patrit01', 'Patrit04', 'Patrit05', 'Patrit07',
    'Xmas01', 'Xmas03', 'Xmas06', 'Xmas09', 'Xmas10',
    'KFG01', 'KFG02', 'KFG03',
    'Cookie01', 'Cookie02',
    'Aqua01', 'Bula01', 'PangLand15', 'Cemetery01'
]
mode_maps['gametype'] = [m for m in popular_gametype if m in all_maps]

data = {
    "modes": [
        {
            "id": "normal",
            "name_vn": "Đại Chiến",
            "description": "Chế độ đặt bom truyền thống kinh điển của Boom Online.",
            "default_map": "Camp08",
            "maps": mode_maps["normal"]
        },
        {
            "id": "gametype",
            "name_vn": "Kiểu Chơi",
            "description": "Các kiểu chơi biến thể: Đội trưởng, Săn nhím, Sinh tồn, Hẹn giờ.",
            "default_map": "Camp08",
            "maps": mode_maps["gametype"]
        },
        {
            "id": "battle",
            "name_vn": "Đấu Trường",
            "description": "Chế độ thi đấu tính điểm xếp hạng và cúp thi đấu.",
            "default_map": "Ladder01" if "Ladder01" in all_maps else mode_maps["battle"][0],
            "maps": mode_maps["battle"]
        },
        {
            "id": "monster2",
            "name_vn": "Săn Boss",
            "description": "Chế độ vượt ải đánh quái và diệt trùm Season 2.",
            "default_map": "Monster01" if "Monster01" in all_maps else mode_maps["monster2"][0],
            "maps": mode_maps["monster2"]
        },
        {
            "id": "superf2",
            "name_vn": "Super Fighter 2",
            "description": "Chế độ đấu đối kháng siêu chiến binh đặc biệt.",
            "default_map": "Super2Fighter01" if "Super2Fighter01" in all_maps else mode_maps["superf2"][0],
            "maps": mode_maps["superf2"]
        },
        {
            "id": "zzolman",
            "name_vn": "Đất Sét",
            "description": "Chế độ người đất sét vui nhộn.",
            "default_map": "Zzolman01" if "Zzolman01" in all_maps else mode_maps["zzolman"][0],
            "maps": mode_maps["zzolman"]
        },
        {
            "id": "snowball",
            "name_vn": "Ném Tuyết",
            "description": "Chế độ ném bóng tuyết đối kháng.",
            "default_map": "SnowBallFight01" if "SnowBallFight01" in all_maps else mode_maps["snowball"][0],
            "maps": mode_maps["snowball"]
        },
        {
            "id": "rpg",
            "name_vn": "Anh Hùng RPG",
            "description": "Chế độ phiêu lưu nhập vai thám hiểm bản đồ.",
            "default_map": "CAhero01" if "CAhero01" in all_maps else mode_maps["rpg"][0],
            "maps": mode_maps["rpg"]
        }
    ]
}

os.makedirs(os.path.dirname(OUT_FILE), exist_ok=True)
with open(OUT_FILE, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print(f"Generated {OUT_FILE} with {len(data['modes'])} modes.")
for m in data['modes']:
    print(f"  Mode {m['id']} ({m['name_vn']}): {len(m['maps'])} maps, default: {m['default_map']}")
