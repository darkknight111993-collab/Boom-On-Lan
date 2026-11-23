#!/usr/bin/env python3
"""Generates Client/data/dialogs.json for all VN sub-screens / modal dialogs.
Every local coordinate is measured directly from the decoded PNG recesses in Client/Assets/fx/."""
import json
import pathlib

OUT = pathlib.Path(__file__).parent.parent / "data" / "dialogs.json"


def el(kind, x, y, sprite=None, **kw):
    d = {"kind": kind, "x": x, "y": y}
    if sprite:
        d["sprite"] = sprite
    d.update(kw)
    return d


def centered(w, h):
    return (800 - w) // 2, (600 - h) // 2


dialogs = {}

# 1. BẢNG THÔNG BÁO (Etc/Dlg_Notice 320x252, matches GameStage/LoginStage-wrongpass.png)
dialogs["notice"] = {
    "x": centered(320, 252)[0], "y": centered(320, 252)[1], "w": 320, "h": 252, "modal": True,
    "elements": [
        el("image", 0, 0, "Etc/Dlg_Notice"),
        el("label", 28, 78, id="msg", text="", w=242, h=104, font_size=12, font_color="#ffffff", wrap=True),
        el("button", 109, 206, "Etc/BtClose", action="dialog:close", sfx_click="Bt_c_Cancle"),
    ],
}

# 2. QUÊN MẬT KHẨU (LoginStage/Dlg_LO-PW 414x213)
dialogs["forgot_pw"] = {
    "x": centered(414, 213)[0], "y": centered(414, 213)[1], "w": 414, "h": 213, "modal": True,
    "elements": [
        el("image", 0, 0, "LoginStage/Dlg_LO-PW"),
        el("label", 28, 73, text="Tên tài khoản", font_size=11, font_color="#e0ffff"),
        el("label", 28, 100, text="Email đăng ký", font_size=11, font_color="#e0ffff"),
        el("label", 28, 127, text="Câu hỏi bí mật", font_size=11, font_color="#e0ffff"),
        el("edit", 136, 72, id="pw_id", w=250, h=19, text="Nhập tên nhân vật"),
        el("edit", 136, 99, id="pw_email", w=250, h=19, text="example@email.com"),
        el("edit", 136, 126, id="pw_ans", w=250, h=19, text="Nhập câu trả lời"),
        el("button", 98, 167, "Etc/BtOk", action="dialog:submit_forgot_pw"),
        el("button", 214, 167, "Etc/BtCancel", action="dialog:close", sfx_click="Bt_c_Cancle"),
    ],
}

# 3. ĐĂNG KÝ TÀI KHOẢN (LoginStage/Dlg_LO-NewID 414x294)
dialogs["register"] = {
    "x": centered(414, 294)[0], "y": centered(414, 294)[1], "w": 414, "h": 294, "modal": True,
    "elements": [
        el("image", 0, 0, "LoginStage/Dlg_LO-NewID"),
        el("label", 28, 73, text="Tên nhân vật", font_size=11, font_color="#e0ffff"),
        el("label", 28, 100, text="Mật khẩu", font_size=11, font_color="#e0ffff"),
        el("label", 28, 127, text="Xác nhận MK", font_size=11, font_color="#e0ffff"),
        el("label", 28, 154, text="Email", font_size=11, font_color="#e0ffff"),
        el("label", 28, 181, text="Giới tính", font_size=11, font_color="#e0ffff"),
        el("label", 28, 208, text="Điều khoản", font_size=11, font_color="#e0ffff"),
        el("edit", 136, 72, id="reg_id", w=165, h=19, text="Tên đăng nhập"),
        el("button", 308, 71, "LoginStage/LO_Bt_IDCheck", action="dialog:check_id"),
        el("edit", 136, 99, id="reg_pw", w=250, h=19, text="Mật khẩu", secret=True),
        el("edit", 136, 126, id="reg_pw2", w=250, h=19, text="Nhập lại mật khẩu", secret=True),
        el("edit", 136, 153, id="reg_email", w=250, h=19, text="example@email.com"),
        el("checkbox", 136, 180, id="reg_male", checked=True),
        el("checkbox", 262, 180, id="reg_female", checked=False),
        el("label", 138, 208, text="Chấp nhận quy định LAN", font_size=10, font_color="#ffffff"),
        el("checkbox", 265, 207, id="reg_agree", checked=True),
        el("button", 98, 248, "Etc/BtOk", action="dialog:submit_register"),
        el("button", 214, 248, "Etc/BtCancel", action="dialog:close", sfx_click="Bt_c_Cancle"),
    ],
}

# 4. ĐANG TẢI VỀ / CHỜ ĐĂNG NHẬP (LoginStage/Dlg_LO-Wait 245x246, matches LoginStage-loading.png)
dialogs["login_wait"] = {
    "x": centered(245, 246)[0], "y": centered(245, 246)[1], "w": 245, "h": 246, "modal": True,
    "elements": [
        el("image", 0, 0, "LoginStage/Dlg_LO-Wait"),
        el("image", 76, 114, "LoginStage/Dlg_LO-WaitingNumber", id="wait_d1", frame=0),
        el("image", 124, 114, "LoginStage/Dlg_LO-WaitingNumber", id="wait_d2", frame=3),
        el("button", 72, 203, "Etc/BtCancel", action="dialog:cancel_login_wait", sfx_click="Bt_c_Cancle"),
    ],
}

# 5. TẠO PHÒNG ĐẦY ĐỦ CHẾ ĐỘ CHƠI (Lobby/Dlg_Creat_MS2_Extension 743x430)
create_modes = [
    {"id": "normal", "sprite": "Lobby/Normal_bt01", "label": "1. Đại Chiến (Mặc định)"},
    {
        "id": "gametype",
        "sprite": "Lobby/Gametype_bt01",
        "label": "2. Kiểu Chơi (Đội trưởng / Nhím / Sinh tồn / Hẹn giờ)",
        "sub_icons": [
            {"sprite": "Lobby/Gametype_bt_Captain", "label": "Đội trưởng"},
            {"sprite": "Lobby/Gametype_bt_Hedgehog", "label": "Săn nhím"},
            {"sprite": "Lobby/Gametype_bt_Survival", "label": "Sinh tồn"},
            {"sprite": "Lobby/Gametype_bt_TimeBomb", "label": "Hẹn giờ"},
        ],
    },
    {"id": "battle", "sprite": "Lobby/Battle_bt01", "label": "3. Đấu Trường"},
    {"id": "monster2", "sprite": "Lobby/Monster2_bt01", "label": "4. Kiểu Nhiệm Vụ (Boss Season 2)"},
    {"id": "superf2", "sprite": "Lobby/SuperF2_bt", "label": "5. Super Fighter 2"},
    {"id": "zzolman", "sprite": "Lobby/Zzolman_bt", "label": "6. Đất Sét"},
    {"id": "snowball", "sprite": "Lobby/SnowBallFight_bt", "label": "7. Ném Tuyết"},
]

dialogs["create_room"] = {
    "x": centered(743, 430)[0], "y": centered(743, 430)[1], "w": 743, "h": 430, "modal": True,
    "elements": [
        el("image", 0, 0, "Lobby/Dlg_Creat_MS2_Extension"),
        el("mode_strip", 24, 62, id="mode_strip", w=695, h=198, modes=create_modes),
        el("label", 44, 276, text="Tên Phòng", font_size=11, font_color="#e0ffff"),
        el("label", 44, 303, text="Chế Độ Chơi", font_size=11, font_color="#e0ffff"),
        el("label", 44, 330, text="Mật Khẩu", font_size=11, font_color="#e0ffff"),
        el("edit", 232, 275, id="room_name", w=468, h=19, text="Càng Xấu Càng Tốt"),
        el("label", 236, 303, id="mode_label", text="1. Đại Chiến (Mặc định)", font_size=11, font_color="#ffff77"),
        el("edit", 232, 329, id="room_pw", w=224, h=19, text="", secret=True, font_color="#ffffff"),
        el("checkbox", 476, 328, id="room_lock", checked=False),
        el("label", 502, 330, text="Tạo khóa mật khẩu", font_size=11, font_color="#ffffff"),
        el("button", 263, 377, "Etc/BtOk", action="dialog:submit_create_room"),
        el("button", 379, 377, "Etc/BtCancel", action="dialog:close", sfx_click="Bt_c_Cancle"),
    ],
}

# 6. THÔNG TIN PHÒNG Ở LOBBY (Lobby/Dlg_LB-RoomInfo8 303x385)
dialogs["lobby_room_info"] = {
    "x": centered(303, 385)[0], "y": centered(303, 385)[1], "w": 303, "h": 385, "modal": True,
    "elements": [
        el("image", 0, 0, "Lobby/Dlg_LB-RoomInfo8"),
        el("label", 32, 74, text="Người chơi", font_size=11, font_color="#ffff77"),
        el("label", 212, 74, text="Cấp", font_size=11, font_color="#ffff77"),
        el("label", 32, 102, id="ri_p1", text="BazziPro (Chủ phòng)", font_size=11, font_color="#ffffff"),
        el("label", 216, 102, text="449", font_size=11, font_color="#aaffff"),
        el("label", 32, 130, id="ri_p2", text="[Chỗ trống]", font_size=11, font_color="#99ccee"),
        el("button", 101, 339, "Etc/BtClose", action="dialog:close", sfx_click="Bt_c_Cancle"),
    ],
}

# 7. CHỌN BẢN ĐỒ (Prepare/Dlg_PRE-SelMap_Renew 539x492)
dialogs["select_map"] = {
    "x": centered(539, 492)[0], "y": centered(539, 492)[1], "w": 539, "h": 492, "modal": True,
    "elements": [
        el("image", 0, 0, "Prepare/Dlg_PRE-SelMap_Renew"),
        el("label", 28, 67, id="map_title", text="Camp08", font_size=12, font_color="#ffff77"),
        # 148x128 minimap preview centered in black box (24..175, 90..221) -> (26, 92)
        el("image", 26, 92, "Etc/Camp08_mm", id="map_preview"),
        el("label", 30, 227, text="Kích thước", font_size=10, font_color="#e0ffff"),
        el("label", 92, 227, id="map_dim", text="15 x 13", font_size=10, font_color="#ffffff"),
        el("label", 30, 246, text="Người chơi", font_size=10, font_color="#e0ffff"),
        el("label", 92, 246, id="map_spawns", text="8", font_size=10, font_color="#ffffff"),
        el("label", 30, 265, text="Độ khó", font_size=10, font_color="#e0ffff"),
        el("label", 30, 284, text="Chế độ", font_size=10, font_color="#e0ffff"),
        el("label", 92, 284, text="Thường", font_size=10, font_color="#ffffff"),
        el("label", 30, 310, id="map_desc", text="Cuộn chuột hoặc kéo thanh cuộn bên phải để chọn bản đồ.", w=142, h=100, font_size=10, font_color="#d8f4ff", wrap=True),
        el("label", 204, 99, text="Bản đồ (1019) - Cuộn chuột / Kéo thanh cuộn", font_size=11, font_color="#aaffff"),
        el("item_list", 194, 120, id="map_list", w=324, h=304),
        el("button", 160, 446, "Etc/BtOk", action="dialog:submit_select_map"),
        el("button", 277, 446, "Etc/BtCancel", action="dialog:close", sfx_click="Bt_c_Cancle"),
    ],
}

# 8. THAY ĐỔI THÔNG TIN PHÒNG (Prepare/Dlg_PRE-RoominfoRenew 450x436)
dialogs["room_info"] = {
    "x": centered(450, 436)[0], "y": centered(450, 436)[1], "w": 450, "h": 436, "modal": True,
    "elements": [
        el("image", 0, 0, "Prepare/Dlg_PRE-RoominfoRenew"),
        el("label", 44, 78, text="Chế độ chơi: Thường (Bom nước cổ điển)", font_size=12, font_color="#ffffff"),
        el("label", 44, 106, text="Số người tối đa: 8 người (LAN Offline)", font_size=11, font_color="#e0ffff"),
        el("label", 44, 283, text="Tên phòng", font_size=11, font_color="#e0ffff"),
        el("label", 44, 311, text="Chế độ", font_size=11, font_color="#e0ffff"),
        el("label", 44, 338, text="Mật khẩu", font_size=11, font_color="#e0ffff"),
        el("edit", 136, 282, id="ri_title", w=271, h=19, text="Cang Xau Cang Tot"),
        el("label", 138, 311, text="Đấu đội / Tự do", font_size=11, font_color="#ffffff"),
        el("edit", 136, 338, id="ri_pw", w=130, h=19, text="", secret=True, font_color="#ffffff"),
        el("button", 116, 383, "Etc/BtOk", action="dialog:submit_room_info"),
        el("button", 232, 383, "Etc/BtCancel", action="dialog:close", sfx_click="Bt_c_Cancle"),
    ],
}

# 9. LỰA CHỌN / CÀI ĐẶT (Etc/Dlg_Option 406x489)
dialogs["option"] = {
    "x": centered(406, 489)[0], "y": centered(406, 489)[1], "w": 406, "h": 489, "modal": True,
    "elements": [
        el("image", 0, 0, "Etc/Dlg_Option"),
        el("label", 38, 80, text="Nhạc nền (BGM)", font_size=11, font_color="#ffffff"),
        el("label", 38, 107, text="Âm thanh (SFX)", font_size=11, font_color="#ffffff"),
        el("slider", 195, 79, id="opt_bgm", w=166, h=18, value=1.0),
        el("slider", 195, 106, id="opt_sfx", w=166, h=18, value=1.0),
        el("label", 46, 185, text="Hiển thị tên nhân vật", font_size=11, font_color="#e0ffff"),
        el("label", 46, 212, text="Hiển thị bóng nước", font_size=11, font_color="#e0ffff"),
        el("label", 46, 239, text="Bật khung chat", font_size=11, font_color="#e0ffff"),
        el("label", 46, 266, text="Hiệu ứng đặc biệt", font_size=11, font_color="#e0ffff"),
        el("label", 46, 293, text="Phím tắt F1: Hướng dẫn", font_size=11, font_color="#aaffff"),
        el("label", 46, 320, text="Phím tắt F10: Lựa chọn", font_size=11, font_color="#aaffff"),
        el("checkbox", 180, 184, id="opt_names", checked=True),
        el("checkbox", 180, 211, id="opt_shadow", checked=True),
        el("checkbox", 180, 238, id="opt_chat", checked=True),
        el("checkbox", 180, 265, id="opt_fx", checked=True),
        el("button", 94, 443, "Etc/BtOk", action="dialog:close"),
        el("button", 210, 443, "Etc/BtCancel", action="dialog:close", sfx_click="Bt_c_Cancle"),
    ],
}

# 10. HƯỚNG DẪN / LUYỆN TẬP (Tutorial/Tutorialback 596x476 + Tutorial/01..20 + left-01..08)
tut_els = [
    el("image", 0, 0, "Tutorial/Tutorialback"),
    el("image", 119, 41, "Tutorial/01", id="tut_page"),
    el("label", 128, 439, id="tut_counter", text="Trang 1 / 20", font_size=12, font_color="#003875"),
    # Note: in VN assets front-button is '◀' (prev) and back-button is '▶' (next)
    el("button", 319, 435, "Tutorial/front-button", action="dialog:tut_prev"),
    el("button", 367, 435, "Tutorial/back-button", action="dialog:tut_next"),
    el("button", 415, 435, "Tutorial/end-button", action="dialog:close", sfx_click="Bt_c_Cancle"),
]
# 8 left chapter buttons (Tutorial/left-01..08, 74x19) starting below 'Luyện Tập' box (32, 42, 72x24)
for idx in range(8):
    tut_els.append(el("button", 31, 76 + idx * 24, f"Tutorial/left-0{idx + 1}", action=f"dialog:tut_chapter:{idx}"))

dialogs["tutorial"] = {
    "x": centered(596, 476)[0], "y": centered(596, 476)[1], "w": 596, "h": 476, "modal": True,
    "elements": tut_els,
}

# 11. POPUP MENU TÙY CHỌN (GlobalUI/MenuDlg_Back 117x246, anchored above GlobalUI/BtMenu at x=18, y=575)
dialogs["menu"] = {
    "x": 18, "y": 572 - 246, "w": 117, "h": 246, "modal": False,
    "elements": [
        el("image", 0, 0, "GlobalUI/MenuDlg_Back"),
        el("label", 14, 10, text="TÙY CHỌN", font_size=11, font_color="#ffff77"),
        el("text_button", 6, 42, w=105, h=28, text="Lựa chọn (F10)", action="dialog:open:option"),
        el("text_button", 6, 76, w=105, h=28, text="Hướng dẫn (F1)", action="dialog:open:tutorial"),
        el("text_button", 6, 118, w=105, h=28, text="Xem bản đồ (M)", action="goto:map_view"),
        el("text_button", 6, 152, w=105, h=28, text="Thông báo", action="dialog:notice:Boom Online LAN Offline (Godot 4). Chưa kết nối server."),
        el("text_button", 6, 202, w=105, h=28, text="Thoát game", font_color="#ffaaaa", action="quit"),
    ],
}

OUT.write_text(json.dumps(dialogs, ensure_ascii=False, indent=1), encoding="utf-8")
print(f"Generated {len(dialogs)} dialogs -> {OUT}")
