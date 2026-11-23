"""Generates Client/data/screens/*.json with verified coordinates from CA.exe.c,
AnalizeTWClient/src/client/stages/*.ts, native 800x600 CAStage JPGs, and GameStage/*.png."""
import json
import pathlib

out = pathlib.Path(__file__).parent.parent / "data" / "screens"


def el(kind, x, y, sprite=None, src="", **kw):
    d = {"kind": kind, "x": x, "y": y, "src": src}
    if sprite:
        d["sprite"] = sprite
    d.update(kw)
    return d


def taskbar(back_action="quit"):
    return [
        el("color_rect", 0, 572, w=800, h=28, color="#003875", src="CGlobalButtonDlg bar @y=572"),
        el("button", 18, 575, "GlobalUI/BtMenu", "GameStage/SelectServerStage.png match (72x24)", action="dialog:menu"),
        el("button", 104, 575, "GlobalUI/BtBack", "GameStage/SelectServerStage.png match (31x24)", action=back_action),
        el("button", 147, 575, "GlobalUI/BtShop", "GameStage/SelectServerStage.png match (66x24)", action="shop"),
        el("button", 221, 575, "GlobalUI/BtSquare", "GameStage/SelectServerStage.png match (69x24)", action="square"),
        el("button", 298, 575, "GlobalUI/BtMessenger", "GlobalUI taskbar (31x24)", action="messenger"),
        el("button", 468, 576, "GlobalUI/BtGachapon", "GameStage/SelectServerStage.png match (77x22)", action="gachapon"),
        el("button", 554, 575, "GlobalUI/BtQuest", "GameStage/SelectServerStage.png match (63x24)", action="quest"),
        el("button", 626, 575, "GlobalUI/BtMyitem", "GlobalUI taskbar (67x24)", action="myitem"),
        el("button", 706, 575, "GlobalUI/BtMyInfo", "GlobalUI taskbar (31x24)", action="dialog:option"),
        el("button", 752, 575, "GlobalUI/BtExit", "GameStage/SelectServerStage.png match (31x24)", action="quit"),
    ]


# --- 1. LOGIN STAGE ---
LOGIN_SRC = "CLoginStage::sub_5694A3 + GameStage/LoginStage.png"
login = [
    el("jpg", 0, 0, "LoginStage/CAStage", "CStage default bg sub_4AF36A"),
    el("image", 188, 413, "LoginStage/LO_LogTable00", "GameStage/LoginStage.png match (424x137 centered)", id="log_table"),
    # White input rects baked into LO_LogTable00 at local (215,50) & (215,75), size 91x19
    el("edit", 403, 463, id="user_id", w=91, h=19, text="ID", src="LO_LogTable00 white box 1: (188+215, 413+50)"),
    el("edit", 403, 488, id="password", w=91, h=19, text="Password", secret=True, src="LO_LogTable00 white box 2: (188+215, 413+75)"),
    # 2P input rects for LO_LogTable01 at (143,413): local (308,50) & (308,75), size 88x19
    el("edit", 451, 463, id="user2_id", w=88, h=19, visible=False, src="LO_LogTable01 2P box 1: (143+308, 413+50)"),
    el("edit", 451, 488, id="password2", w=88, h=19, secret=True, visible=False, src="LO_LogTable01 2P box 2: (143+308, 413+75)"),
    el("button", 196, 437, "LoginStage/LO_Bt1P", "GameStage/LoginStage.png match (196, 437)", action="login_mode:1p", id="btn_1p"),
    el("button", 529, 437, "LoginStage/LO_Bt2P", "GameStage/LoginStage.png match (529, 437)", action="login_mode:2p", id="btn_2p"),
    el("button", 189, 560, "LoginStage/LO_BtLogPW", LOGIN_SRC + " (189, 560)", action="dialog:forgot_pw"),
    el("button", 297, 560, "LoginStage/LO_BtLogNewId", LOGIN_SRC + " (297, 560)", action="dialog:register"),
    el("button", 405, 560, "LoginStage/LO_BtLogOk", LOGIN_SRC + " (405, 560)", action="login", id="btn_login"),
    el("button", 514, 560, "LoginStage/LO_BtLogExit", LOGIN_SRC + " (514, 560)", action="quit"),
    el("label", 280, 525, id="Notice", text="", font_size=12, font_color="#ff4444", src="Notice under table"),
]

# --- 2. SELECT SERVER STAGE (Renew) ---
SS_SRC = "SelectServerStage/CAStage_Renew + GameStage/SelectServerStage.png"
ss = [
    el("jpg", 0, 0, "SelectServerStage/CAStage_Renew", "CAStage_Renew 800x600 background"),
    # 4 Tabs anchored at y=122: inactive frames have offset=(0,-25) -> draw y=147 (bottom=224);
    # active CH_Tab_Special frame=3 has offset=(0,0) -> draw y=122, height=102 (bottom=224)
    el("button", 404, 122, "SelectServerStage/CH_Tab_Novice", SS_SRC + " tab 0 (draw 404,147)", action="unsupported"),
    el("button", 475, 122, "SelectServerStage/CH_Tab_Free", SS_SRC + " tab 1 (draw 475,147)", action="unsupported"),
    el("button", 546, 122, "SelectServerStage/CH_Tab_Special", SS_SRC + " tab 2 active (draw 546,122)", frame=3, action="unsupported"),
    el("button", 650, 122, "SelectServerStage/CH_Tab_Event", SS_SRC + " tab 3 (draw 650,147)", action="unsupported"),
    el("image", 404, 224, "SelectServerStage/CH_ChBar_Special", SS_SRC + " pink header bar (388x34)"),
    el("label", 418, 234, text="Đây là kênh siêu cấp. Có thể chơi siêu cấp đúng với cấp độ.", font_size=11, font_color="#222222", src="CH_ChBar_Special text"),
]

# 8 Channels (4 rows x 2 cols) matching exact recesses on CAStage_Renew:
# Baked boxes at draw x=431/598, y=281+56*row (161x52). CH_Bt_Channel f0 offset=(-3,-3) -> anchor x=428/595, y=278+56*row.
channels = [
    ("WinWin-Free", 3), ("LT-01", 1),
    ("LT-02", 2), ("CB-01", 1),
    ("CB-02", 4), ("TD-01", 8),
    ("TD-02", 6), ("TD-03", 2),
]
for i, (name, load) in enumerate(channels):
    col = i % 2
    row = i // 2
    x = 595 if col else 428
    y = 278 + 56 * row
    ss.append(el("button", x, y, "SelectServerStage/CH_Bt_Channel", SS_SRC + " exact recess (draw 431/598, 281+56r)", action="goto:lobby"))
    ss.append(el("label", x + 16, y + 9, text=name, font_size=11, font_color="#e0ffff", src="Channel name"))
    ss.append(el("image", x + 15, y + 35, "SelectServerStage/CH_Bar_User", SS_SRC + " load bar in recess (442,313)", frame=load))

# Channel pagination aligned to dark box (517, 516, 156x25) on CAStage_Renew
ss.append(el("button", 490, 516, "SelectServerStage/CH_Bt_Left", SS_SRC + " left of pagination box", action="unsupported"))
ss.append(el("button", 676, 516, "SelectServerStage/CH_Bt_Right", SS_SRC + " right of pagination box", action="unsupported"))
# CH_NuBg only defines frame 3 (selected page pill)
ss.append(el("image", 521, 519, "SelectServerStage/CH_NuBg", SS_SRC + " active page pill", frame=3))
for i in range(5):
    ss.append(el("button", 529 + 30 * i, 522, "SelectServerStage/CH_Bt_ChNum", SS_SRC + " page digit", frame=i + 1, action="unsupported"))

ss += taskbar(back_action="goto:login")
ss.append(el("label", 10, 10, id="Notice", text="", src="Notice"))

# --- 3. LOBBY STAGE (CAStageRenew) ---
LB_SRC = "CLobbyStage (AnalizeTWClient/LobbyStage.ts + Lobby/CAStageRenew recesses)"
lobby = [
    el("jpg", 0, 0, "Lobby/CAStageRenew", "CAStageRenew 800x600 background"),
    # Top Action buttons aligned to exact recesses at y=48..111 on CAStageRenew
    el("button", 218, 48, "Lobby/LB_Bt_T_CreateRenew", LB_SRC + " exact 136x63 recess (218, 48)", action="dialog:create_room"),
    el("button", 359, 48, "Lobby/LB_Bt_T_QuickJoinRenew", LB_SRC + " exact recess (359, 48)", action="goto:prepare"),
    el("button", 488, 60, "Lobby/LB_Bt_T_GameTypeRenew", LB_SRC + " GameType (488, 60)", action="unsupported"),
    el("button", 571, 64, "Lobby/LB_Bt_T_ShowAllRenew", LB_SRC + " ShowAll (571, 64)", action="unsupported"),
    el("button", 674, 64, "Lobby/LB_Bt_T_PracticeRenew", LB_SRC + " Practice -> Tutorial (674, 64)", action="dialog:tutorial"),
    # Left User Profile & Player list tabs (above user box y=281..546)
    el("label", 68, 205, id="Nick", text="BazziPro", font_size=12, font_color="#ffffff", src="Left profile box"),
    el("label", 38, 232, text="cấp.449   30.7%", font_size=10, font_color="#ffffaa", src="Left profile stats"),
    el("button", 21, 255, "Lobby/LB_Bt_All", LB_SRC + " All Tab (81x22)", action="unsupported"),
    el("button", 102, 255, "Lobby/LB_Bt_Guild", LB_SRC + " Guild Tab (80x22)", action="unsupported"),
    el("button", 56, 524, "Lobby/LB_Bt_Left02", LB_SRC + " User list prev", action="unsupported"),
    el("button", 103, 524, "Lobby/LB_Bt_Right02", LB_SRC + " User list next", action="unsupported"),
]

# 6 Room Slots (2 cols x 3 rows) matching exact dark-navy recesses on CAStageRenew & AnalizeTWClient/LobbyStage.ts:
# Baked recesses: draw x=218/494, y=125/209/293 (272x81). LB_Bt_SessionSlot f0 offset=(-4,-4) -> anchor x=214/490, y=121/205/289.
rooms = [
    ("S02", "Càng Xấu Càng Tốt", "1/8"),
    ("S08", "Pro BnB [Giao lưu]", "2/8"),
    ("S22", "Post 3 t? 2c 2f (4cs)", "3/8"),
    ("S35", "Team 2 vs 2", "4/8"),
    ("S37", "Chiến thôi anh em", "1/8"),
    ("051", "Solo 1-1", "2/8"),
]
for i, (num, title, cnt) in enumerate(rooms):
    col = i % 2
    row = i // 2
    x = 490 if col else 214
    y = 121 + 84 * row
    lobby.append(el("button", x, y, "Lobby/LB_Bt_SessionSlot", LB_SRC + " exact recess (draw 218/494, 125+84r)", action="goto:prepare"))
    lobby.append(el("label", x + 70, y + 14, text=num, font_size=12, font_color="#ffff55", src="Room num"))
    lobby.append(el("label", x + 110, y + 14, text=title, font_size=11, font_color="#ffffff", src="Room title"))
    lobby.append(el("label", x + 70, y + 48, text="WAITING", font_size=11, font_color="#ffaa33", src="Room state"))
    lobby.append(el("label", x + 206, y + 52, text=cnt, font_size=11, font_color="#aaffff", src="Room count"))
    lobby.append(el("button", x + 242, y + 49, "Lobby/LB_Bt_RoomInfo", LB_SRC + " (+242, +49)", action="dialog:lobby_room_info"))

# Room pagination (AnalizeTWClient/LobbyStage.ts exact coords)
lobby.append(el("button", 431, 376, "Lobby/LB_Bt_Left01", LB_SRC + " (431, 376)", action="unsupported"))
lobby.append(el("button", 494, 376, "Lobby/LB_Bt_Right01", LB_SRC + " (494, 376)", action="unsupported"))

# Chat section aligned to exact recess (359, 526, 357x23) on CAStageRenew
lobby.append(el("edit", 362, 527, id="chat_input", w=352, h=21, text="Nhập nội dung trò chuyện...", font_color="#ffffff", src="CAStageRenew chat recess (359, 526)"))
lobby.append(el("button", 722, 524, "Etc/BtSpeaker_Speaker", LB_SRC + " Shout btn beside chat", action="unsupported"))

lobby += taskbar(back_action="goto:select_server")
lobby.append(el("label", 20, 10, id="Notice", text="", src="Notice"))

# --- 4. PREPARE STAGE (Room / CAStage_1) ---
PREP_SRC = "CPrepareStage (AnalizeTWClient/PrepareStage.ts + GameStage/Room.png + CAStage_1 recesses)"
prepare = [
    el("jpg", 0, 0, "Prepare/CAStage_1", "CAStage_1 800x600 background"),
    # Room Title Header
    el("label", 32, 63, text="119", font_size=12, font_color="#ffff55", src="Room ID box"),
    el("label", 80, 63, id="RoomTitle", text="Cang Xau Cang Tot", font_size=12, font_color="#ffffff", src="Room title"),
    el("button", 344, 61, "Prepare/PRE_Bt_Roominfo", PREP_SRC + " exact match (344, 61)", action="dialog:room_info"),
    # Player Slot 0 (Host at 27, 94)
    el("label", 36, 198, id="Slot0Nick", text="BazziPro", font_size=11, font_color="#ffffff", src="Slot 0 nick"),
    el("image", 30, 217, "Prepare/PRE_Img", PREP_SRC + " host badge frame=2", frame=2),
    # Chat Input aligned to exact recess (140, 523, 253x21)
    el("edit", 143, 524, id="room_chat", w=248, h=20, text="Tán gẫu...", font_color="#ffffff", src="CAStage_1 chat recess (140, 523)"),
    el("button", 398, 520, "Etc/BtSpeaker_Speaker", PREP_SRC + " Shout btn", action="unsupported"),
]

# 11 Character Select buttons in the 4x3 grid on CAStage_1 (recesses x=490,562,634,706; y=116,163,210; 63x41)
# Shop/S_SelChara* & Prepare/S_Selrandom are 65x43 with offset=(-2,-2) -> anchor = (recess_x - 3, recess_y - 3)
# Top character info banner box on CAStage_1 is (490, 22, 279x84) -> Etc/ChaInfo_Char*
prepare.append(el("image", 490, 22, "Etc/ChaInfo_Char00", PREP_SRC + " top char banner (279x84)", id="CharBanner"))
char_sprites = [
    "Shop/S_SelChara00", "Shop/S_SelChara01", "Shop/S_SelChara03", "Shop/S_SelChara05",
    "Shop/S_SelChara04", "Shop/S_SelChara06", "Shop/S_SelChara02", "Shop/S_SelChara07",
    "Shop/S_SelChara14", "Shop/S_SelChara15", "Prepare/S_Selrandom",
]
for idx, csp in enumerate(char_sprites):
    cx = 490 + (idx % 4) * 72 - 3
    cy = 116 + (idx // 4) * 47 - 3
    prepare.append(el("button", cx, cy, csp, PREP_SRC + f" char slot {idx}", id=f"CharBtn{idx}", action=f"select_char:{idx}"))
prepare.append(el("image", 490 + 38, 116 - 5, "Prepare/PRE_Img", PREP_SRC + " selected char check mark", id="CharCheck", frame=7))

# Team buttons inside team bar (480..785, y=275..320)
for t in range(8):
    prepare.append(el("button", 484 + t * 37, 280, f"Prepare/PRE_SelTeam-Basic0{t}", PREP_SRC + f" team {t}", action="unsupported"))

# Right Map Panel + Start + AutoReady (exact match with Room.png & PrepareStage.ts)
# Map preview square on CAStage_1 is (487, 347, 157x132) -> 148x128 minimap centered at (491, 349)
prepare += [
    el("image", 491, 349, "Etc/Camp08_mm", PREP_SRC + " 148x128 minimap preview", id="MapPreview"),
    el("label", 648, 351, id="MapName", text="Camp08", font_size=11, font_color="#ffffff", src="CAStage_1 map info line 1"),
    el("label", 648, 371, text="Người: 8", font_size=11, font_color="#aaffaa", src="CAStage_1 map info line 2"),
    el("button", 646, 428, "Prepare/PRE_Bt_Selectmap", PREP_SRC + " exact match (646, 428)", action="dialog:select_map"),
    el("button", 512, 494, "Prepare/PRE_Bt_Start", PREP_SRC + " exact match (512, 494)", action="goto:game_stage"),
    el("button", 719, 525, "Prepare/PRE_Bt_CheckBox", PREP_SRC + " exact match (719, 525)", action="unsupported"),
]
prepare += taskbar(back_action="goto:lobby")
prepare.append(el("label", 20, 10, id="Notice", text="", src="Notice"))

# --- 5. GAME STAGE ---
GAME_SRC = "CGameStage (AnalizeTWClient/GameStage.ts + GameStage/GameStage.png)"
game_stage = [
    el("jpg", 0, 0, "Game/CAStage", "Game/CAStage 800x600 background (map viewport 20,41 size 600x520)"),
    # Timer digits on right sidebar flanking the baked ':' at x=744..745
    el("image", 720, 78, "Game/Timer", GAME_SRC + " min tens", frame=0),
    el("image", 732, 78, "Game/Timer", GAME_SRC + " min ones", frame=2),
    el("image", 748, 78, "Game/Timer", GAME_SRC + " sec tens", frame=5),
    el("image", 760, 78, "Game/Timer", GAME_SRC + " sec ones", frame=7),
    el("image", 647, 466, "Game/ItemBox01", GAME_SRC + " ItemBox01 (647, 466)"),
    el("button", 647, 561, "Game/BtExit", GAME_SRC + " exact match (647, 561)", action="goto:prepare"),
]

for name, els, bgm in (
    ("login", login, "StageLogin"),
    ("select_server", ss, "StageChannel"),
    ("lobby", lobby, "StageSquare"),
    ("prepare", prepare, "Prepare"),
    ("game_stage", game_stage, "Village"),
):
    payload = {"bgm": bgm, "elements": els}
    (out / f"{name}.json").write_text(json.dumps(payload, ensure_ascii=False, indent=1), encoding="utf-8")

print("Generated all 5 screens successfully!")
