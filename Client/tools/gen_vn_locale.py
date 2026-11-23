#!/usr/bin/env python3
"""Generates Client/data/vn_locale.json containing Vietnamese names and descriptions
for characters, map themes, maps, and items in Boom Online (VNG)."""
import json
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Client" / "data" / "vn_locale.json"

# 1. Characters (verified from Client/Assets/fx/Etc/ChaInfo_Char* and GameStage/Room.png)
characters = {
    "Character/C00": {
        "id": 0, "code": "C00", "key": "Dao",
        "name_vn": "Nhanh Nhẩu",
        "banner_sprite": "Etc/ChaInfo_Char00",
        "select_sprite": "Shop/S_SelChara00",
        "desc_vn": "Cậu bé chính nghĩa, cân bằng mọi chỉ số tốc độ, bóng nước và độ dài tia nước."
    },
    "Character/C01": {
        "id": 1, "code": "C01", "key": "Dizini",
        "name_vn": "Mật Ngọt",
        "banner_sprite": "Etc/ChaInfo_Char01",
        "select_sprite": "Shop/S_SelChara01",
        "desc_vn": "Cô bé dễ thương với độ dài tia nước tối đa rất cao (9 ô)."
    },
    "Character/C02": {
        "id": 6, "code": "C02", "key": "Uni",
        "name_vn": "Bé Bỏng",
        "banner_sprite": "Etc/ChaInfo_Char06",
        "select_sprite": "Shop/S_SelChara02",
        "desc_vn": "Em út nhỏ tuổi nhất làng Boom, khởi đầu sẵn với tia nước dài 2 ô."
    },
    "Character/C03": {
        "id": 2, "code": "C03", "key": "Mos",
        "name_vn": "Đầu Đinh",
        "banner_sprite": "Etc/ChaInfo_Char02",
        "select_sprite": "Shop/S_SelChara03",
        "desc_vn": "Chàng trai mạnh mẽ, tốc độ khởi đầu nhanh (5/8)."
    },
    "Character/C04": {
        "id": 4, "code": "C04", "key": "Marid",
        "name_vn": "Mắt Xanh",
        "banner_sprite": "Etc/ChaInfo_Char04",
        "select_sprite": "Shop/S_SelChara04",
        "desc_vn": "Cô nàng đỏng đảnh thích tiền vàng, khởi đầu với 2 quả bóng nước."
    },
    "Character/C05": {
        "id": 3, "code": "C05", "key": "Ethi",
        "name_vn": "Mọt Sách",
        "banner_sprite": "Etc/ChaInfo_Char03",
        "select_sprite": "Shop/S_SelChara05",
        "desc_vn": "Cậu bé thông thái có thể đặt tối đa tới 10 quả bóng nước."
    },
    "Character/C06": {
        "id": 5, "code": "C06", "key": "Bazzi",
        "name_vn": "Khò Khò",
        "banner_sprite": "Etc/ChaInfo_Char05",
        "select_sprite": "Shop/S_SelChara06",
        "desc_vn": "Chàng lười ham ngủ nhưng có tốc độ chạy nhanh nhất làng Boom (tối đa 9)."
    },
    "Character/C07": {
        "id": 7, "code": "C07", "key": "Kephi",
        "name_vn": "Thịt Mỡ",
        "banner_sprite": "Etc/ChaInfo_Char07",
        "select_sprite": "Shop/S_SelChara07",
        "desc_vn": "Ham ăn nhưng sở hữu cả lượng bóng nước (9) lẫn tia nước (2 -> 8) cực mạnh."
    },
    "Character/C08": {
        "id": 8, "code": "C08", "key": "Su",
        "name_vn": "Thiên Sứ",
        "banner_sprite": "Etc/ChaInfo_Char08",
        "select_sprite": "Shop/S_SelChara14",
        "desc_vn": "Thiên sứ ánh sáng với chỉ số khởi đầu vượt trội (Tốc độ 6, Bóng 3, Nước 3)."
    },
    "Character/C09": {
        "id": 9, "code": "C09", "key": "Hoo",
        "name_vn": "Tí Điệu",
        "banner_sprite": "Etc/ChaInfo_Char09",
        "select_sprite": "Shop/S_SelChara15",
        "desc_vn": "Thông minh và quyến rũ! Khởi đầu với Tốc độ 5, Bóng 2, Nước 2."
    },
    "Character/C10": {
        "id": 10, "code": "C10", "key": "LuxuryMarid",
        "name_vn": "Mắt Biếc",
        "banner_sprite": "Etc/ChaInfo_Char10",
        "select_sprite": "Shop/S_SelChara10",
        "desc_vn": "Phiên bản quý tộc của Mắt Xanh với tốc độ 5/9 và 2 bóng nước khởi đầu."
    },
    "Character/C11": {
        "id": 11, "code": "C11", "key": "LuxuryMos",
        "name_vn": "Tí Bảnh",
        "banner_sprite": "Etc/ChaInfo_Char11",
        "select_sprite": "Shop/S_SelChara11",
        "desc_vn": "Nhân vật siêu cấp lịch lãm với tốc độ tối đa lên tới 10."
    },
    "Character/C13": {
        "id": 13, "code": "C13", "key": "SuperDao",
        "name_vn": "Tia Chớp",
        "banner_sprite": "Etc/ChaInfo_Char13",
        "select_sprite": "Shop/S_SelChara13",
        "desc_vn": "Siêu nhân Tia Chớp khởi đầu với 3 bóng nước và tốc độ tối đa 10."
    },
    "Character/C14": {
        "id": 14, "code": "C14", "key": "Lodumani",
        "name_vn": "Hải Tặc",
        "banner_sprite": "Etc/ChaInfo_Random",
        "select_sprite": "Prepare/S_Selrandom",
        "desc_vn": "Thuyền trưởng Hải Tặc huyền thoại (chỉ xuất hiện với tỉ lệ hiếm khi chọn Ngẫu Nhiên)."
    },
    "Character/C15": {
        "id": 15, "code": "C15", "key": "Santa",
        "name_vn": "Ông Già Noel",
        "banner_sprite": "Etc/ChaInfo_Random",
        "select_sprite": "Prepare/S_Selrandom",
        "desc_vn": "Nhân vật đặc biệt mùa Giáng Sinh (chỉ xuất hiện với tỉ lệ hiếm khi chọn Ngẫu Nhiên)."
    },
    "Character/Random": {
        "id": 99, "code": "Random", "key": "Random",
        "name_vn": "Ngẫu Nhiên",
        "banner_sprite": "Etc/ChaInfo_Random",
        "select_sprite": "Prepare/S_Selrandom",
        "desc_vn": "Chọn ngẫu nhiên nhân vật (có tỉ lệ ra Hải Tặc hoặc Ông Già Noel thấp hơn mặc định)."
    },
}

# 11-slot PrepareStage grid mapping (matches GameStage/Room.png 4x3 character panel)
prepare_char_slots = [
    {"slot": 0, "char": "Character/C00", "button_sprite": "Shop/S_SelChara00", "banner_sprite": "Etc/ChaInfo_Char00", "name_vn": "Nhanh Nhẩu"},
    {"slot": 1, "char": "Character/C01", "button_sprite": "Shop/S_SelChara01", "banner_sprite": "Etc/ChaInfo_Char01", "name_vn": "Mật Ngọt"},
    {"slot": 2, "char": "Character/C03", "button_sprite": "Shop/S_SelChara03", "banner_sprite": "Etc/ChaInfo_Char02", "name_vn": "Đầu Đinh"},
    {"slot": 3, "char": "Character/C05", "button_sprite": "Shop/S_SelChara05", "banner_sprite": "Etc/ChaInfo_Char03", "name_vn": "Mọt Sách"},
    {"slot": 4, "char": "Character/C04", "button_sprite": "Shop/S_SelChara04", "banner_sprite": "Etc/ChaInfo_Char04", "name_vn": "Mắt Xanh"},
    {"slot": 5, "char": "Character/C06", "button_sprite": "Shop/S_SelChara06", "banner_sprite": "Etc/ChaInfo_Char05", "name_vn": "Khò Khò"},
    {"slot": 6, "char": "Character/C02", "button_sprite": "Shop/S_SelChara02", "banner_sprite": "Etc/ChaInfo_Char06", "name_vn": "Bé Bỏng"},
    {"slot": 7, "char": "Character/C07", "button_sprite": "Shop/S_SelChara07", "banner_sprite": "Etc/ChaInfo_Char07", "name_vn": "Thịt Mỡ"},
    {"slot": 8, "char": "Character/C08", "button_sprite": "Shop/S_SelChara14", "banner_sprite": "Etc/ChaInfo_Char08", "name_vn": "Thiên Sứ"},
    {"slot": 9, "char": "Character/C09", "button_sprite": "Shop/S_SelChara15", "banner_sprite": "Etc/ChaInfo_Char09", "name_vn": "Tí Điệu"},
    {"slot": 10, "char": "Character/Random", "button_sprite": "Prepare/S_Selrandom", "banner_sprite": "Etc/ChaInfo_Random", "name_vn": "Ngẫu Nhiên"},
]

# 2. Map Themes (Vietnamese name + description translated from csysstr.ssd & VNG Boom Online)
map_themes = {
    "Camp": {"name_vn": "Doanh trại", "desc_vn": "Tại Doanh trại dã chiến, hãy cẩn thận khi đặt bóng nước vì nếu chạm phải chông nhọn bóng sẽ nổ ngay lập tức!"},
    "Village": {"name_vn": "Ngôi làng", "desc_vn": "Ngôi làng nhỏ xinh xắn với nhiều cửa hàng và mái nhà san sát. Hãy tận hưởng trận đấu vui vẻ tại đây!"},
    "Factory": {"name_vn": "Nhà máy", "desc_vn": "Nhà máy chế tạo các loại bóng nước! Hãy coi chừng vòi phun nước bất ngờ từ dưới rãnh nhé!"},
    "Forest": {"name_vn": "Rừng rậm", "desc_vn": "Khu rừng rậm rạp phía tây làng Boom với nhiều hoa đẹp, cây xanh và bụi cỏ ẩn nấp."},
    "Ice": {"name_vn": "Băng tuyết", "desc_vn": "Vùng đất băng giá lạnh lẽo phía bắc làng Boom, mặt băng trơn trượt rất ít người dám bén mảng!"},
    "Desert": {"name_vn": "Sa mạc", "desc_vn": "Vùng sa mạc nắng nóng gần thị trấn với ốc đảo mát mẻ và những kim tự tháp bí ẩn."},
    "Mine": {"name_vn": "Hầm mỏ", "desc_vn": "Khu hầm mỏ phía đông làng Boom với đường ray xe goòng và rất nhiều đá quý."},
    "Ocean": {"name_vn": "Đại dương", "desc_vn": "Vùng biển nhiệt đới phía nam làng Boom, nơi giải nhiệt tuyệt vời với dòng nước chảy."},
    "Patrit": {"name_vn": "Cướp biển", "desc_vn": "Con tàu của Thuyền trưởng Hải Tặc chứa đầy kho báu và những khẩu đại bác."},
    "Tomb": {"name_vn": "Nghĩa địa", "desc_vn": "Khu nghĩa địa âm u lạnh gáy, bóng ma có thể bất ngờ xuất hiện bất cứ lúc nào!"},
    "Cemetery": {"name_vn": "Hầm mộ", "desc_vn": "Hầm mộ cổ tối tăm đầy cạm bẫy và những bức tượng bí ẩn."},
    "Xmas": {"name_vn": "Giáng sinh", "desc_vn": "Ngôi làng tuyết đêm Giáng Sinh lung linh ánh đèn và những hộp quà bất ngờ."},
    "xmas": {"name_vn": "Giáng sinh", "desc_vn": "Ngôi làng tuyết đêm Giáng Sinh lung linh ánh đèn và những hộp quà bất ngờ."},
    "KFG": {"name_vn": "Võ đài Kungfu", "desc_vn": "Sân đấu võ đài truyền thống đòi hỏi kỹ năng di chuyển và đặt bóng chuẩn xác."},
    "Kfg": {"name_vn": "Võ đài Kungfu", "desc_vn": "Sân đấu võ đài truyền thống đòi hỏi kỹ năng di chuyển và đặt bóng chuẩn xác."},
    "kfg": {"name_vn": "Võ đài Kungfu", "desc_vn": "Sân đấu võ đài truyền thống đòi hỏi kỹ năng di chuyển và đặt bóng chuẩn xác."},
    "Kart": {"name_vn": "Đường đua", "desc_vn": "Đường đua tốc độ cao dành cho những tay lái xe Kart cừ khôi."},
    "PangLand": {"name_vn": "Pháo đài", "desc_vn": "Pháo đài giải trí của Hải Tặc, hãy coi chừng robot bắn bóng nước bất ngờ!"},
    "Pangland": {"name_vn": "Pháo đài", "desc_vn": "Pháo đài giải trí của Hải Tặc, hãy coi chừng robot bắn bóng nước bất ngờ!"},
    "Cookie": {"name_vn": "Bánh ngọt", "desc_vn": "Xứ sở bánh kẹo ngọt ngào với những khối bánh quy giòn tan."},
    "Aqua": {"name_vn": "Thủy cung", "desc_vn": "Thủy cung sâu dưới đáy biển với bong bóng nước và sinh vật biển."},
    "Bula": {"name_vn": "Bộ lạc", "desc_vn": "Khu rừng bộ lạc nguyên thủy đầy bí ẩn."},
    "Rabbit": {"name_vn": "Thỏ ngọc", "desc_vn": "Vùng đất Thỏ Ngọc trên cung trăng với những bức tượng thỏ cảm ứng."},
    "BlackRabbit": {"name_vn": "Thỏ đen", "desc_vn": "Hang ổ của binh đoàn Thỏ Đen tinh nghịch."},
    "SnowBallFight": {"name_vn": "Ném tuyết", "desc_vn": "Sân đấu ném cầu tuyết đóng băng đối thủ."},
    "SnowyFields": {"name_vn": "Cánh đồng tuyết", "desc_vn": "Cánh đồng tuyết trắng xóa trải dài."},
    "seafields": {"name_vn": "Bãi biển", "desc_vn": "Bãi biển nắng vàng rực rỡ."},
    "Zombie": {"name_vn": "Xác sống", "desc_vn": "Khu vực nhiễm độc nơi người chơi có thể biến thành Zombie."},
    "Zzolman": {"name_vn": "Đất sét", "desc_vn": "Đấu trường của binh đoàn người đất sét."},
    "SuperFighter": {"name_vn": "Siêu đấu sĩ", "desc_vn": "Đấu trường sinh tử của các Siêu Đấu Sĩ."},
    "Super": {"name_vn": "Siêu cấp", "desc_vn": "Bản đồ đấu trường siêu cấp."},
    "Ladder": {"name_vn": "Đấu hạng", "desc_vn": "Bản đồ thi đấu xếp hạng tiêu chuẩn."},
    "Tournament": {"name_vn": "Giải đấu", "desc_vn": "Đấu trường giải đấu chuyên nghiệp."},
    "Bonus": {"name_vn": "Kho báu", "desc_vn": "Bản đồ thưởng ngập tràn tiền vàng Lucci và túi quà!"},
    "Monster": {"name_vn": "Đấu quái", "desc_vn": "Bản đồ phối hợp tiêu diệt quái vật và săn Boss."},
    "MonPen": {"name_vn": "Chim cánh cụt", "desc_vn": "Săn Boss Chim Cánh Cụt trên đảo băng."},
    "MonSeal": {"name_vn": "Hải cẩu", "desc_vn": "Săn Boss Hải Cẩu Chúa."},
    "MonGolem": {"name_vn": "Người đá Golem", "desc_vn": "Săn Boss Người Đá Golem khổng lồ."},
    "MonRobot": {"name_vn": "Người máy", "desc_vn": "Đột kích nhà máy tiêu diệt Boss Robot."},
    "MonTurtle": {"name_vn": "Rùa thần", "desc_vn": "Thử thách Rùa Thần đại dương."},
    "MonSnowBear": {"name_vn": "Gấu tuyết", "desc_vn": "Hang ổ của Gấu Tuyết khổng lồ."},
    "RPG": {"name_vn": "Phiêu lưu RPG", "desc_vn": "Bản đồ đi cảnh phiêu lưu luyện cấp và làm nhiệm vụ."},
    "IamBoss": {"name_vn": "Ta là Trùm", "desc_vn": "Chế độ 1 hóa Trùm khổng lồ đối đầu các người chơi còn lại."},
    "Hidden": {"name_vn": "Truy tìm", "desc_vn": "Bản đồ ẩn mật truy tìm điểm khác biệt."},
    "LobbySquare": {"name_vn": "Quảng trường", "desc_vn": "Quảng trường giao lưu của cư dân làng Boom."},
}

prefix_order = sorted(map_themes.keys(), key=len, reverse=True)


def translate_map_name(mname: str) -> tuple[str, str]:
    clean = mname
    prefix_tag = ""
    if clean.startswith("Ex") and len(clean) > 2 and clean[2].isupper():
        prefix_tag = "[VIP] "
        clean = clean[2:]
    elif clean.startswith("Event") and len(clean) > 5 and clean[5].isupper():
        prefix_tag = "[Sự kiện] "
        clean = clean[5:]
    elif clean.startswith("NXCL_"):
        prefix_tag = "[Giải đấu] "
        clean = clean[5:]
    elif clean.startswith("WS_"):
        prefix_tag = "[Liên thắng] "
        clean = clean[3:]

    for p in prefix_order:
        if clean.lower().startswith(p.lower()):
            rest = clean[len(p):].lstrip("_")
            vn_base = map_themes[p]["name_vn"]
            desc = map_themes[p]["desc_vn"]
            title = f"{prefix_tag}{vn_base} {rest}".strip() if rest else f"{prefix_tag}{vn_base}".strip()
            return title, desc
    return mname, "Bản đồ thi đấu Boom Online."


maps_dir = ROOT / "Client" / "Assets" / "fx" / "Map"
maps_locale = {}
if maps_dir.exists():
    for m in sorted(os.listdir(maps_dir)):
        if (maps_dir / m).is_dir():
            t, d = translate_map_name(m)
            maps_locale[m] = {"name_vn": t, "desc_vn": d}

# 3. Items & Ships (Vietnamese names & descriptions matching VNG Boom Online & csysstr.ssd)
items = {
    "Item/ItemBomb": {"name_vn": "Bóng nước", "desc_vn": "Tăng thêm 1 quả bóng nước có thể đặt cùng lúc."},
    "Item/ItemFire": {"name_vn": "Thuốc nước", "desc_vn": "Tăng độ dài tia nước của bóng thêm 1 ô."},
    "Item/ItemRoller": {"name_vn": "Giày trượt", "desc_vn": "Tăng tốc độ di chuyển của nhân vật thêm 1 bậc."},
    "Item/ItemMaxPower": {"name_vn": "Thuốc tím siêu cấp", "desc_vn": "Tăng độ dài tia nước lên mức tối đa ngay lập tức."},
    "Item/ItemRedDevil": {"name_vn": "Quỷ đỏ", "desc_vn": "Tăng tốc độ chạy lên mức tối đa ngay lập tức."},
    "Item/ItemShoe": {"name_vn": "Giày đá", "desc_vn": "Cho phép đá quả bóng nước trước mặt trượt thẳng đi."},
    "Item/ItemPunch": {"name_vn": "Găng tay đấm", "desc_vn": "Đấm văng quả bóng nước trước mặt bay qua các vật cản."},
    "Item/ItemNeedle": {"name_vn": "Kim chích", "desc_vn": "Dùng kim tự chích vỡ bóng nước để giải cứu bản thân."},
    "Item/ItemShield": {"name_vn": "Khiên bảo vệ", "desc_vn": "Tạo vòng hào quang bất tử bảo vệ khỏi tia nước trong thời gian ngắn."},
    "Item/ItemDart": {"name_vn": "Phi tiêu", "desc_vn": "Phóng phi tiêu kích nổ bóng nước từ xa."},
    "Item/ItemOxygen": {"name_vn": "Bình dưỡng khí", "desc_vn": "Kéo dài thời gian sống sót khi bị nhốt trong bóng nước để chờ đồng đội cứu."},
    "Item/ItemGlass": {"name_vn": "Kính xuyên thấu", "desc_vn": "Nhìn xuyên qua các hộp mềm để biết vật phẩm ẩn bên trong."},
    "Item/ItemTonic": {"name_vn": "Thuốc giải", "desc_vn": "Hóa giải hiệu ứng lời nguyền của Quỷ tím / Đầu lâu."},
    "Item/ItemSpring": {"name_vn": "Giày lò xo", "desc_vn": "Nhảy qua 1 ô vật cản hoặc bóng nước trước mặt."},
    "Item/ItemDrill": {"name_vn": "Máy khoan", "desc_vn": "Phá hủy ngay lập tức ô hộp mềm trước mặt."},
    "Item/ItemRadio": {"name_vn": "Bom hẹn giờ", "desc_vn": "Đặt bóng nước điều khiển kích nổ theo ý muốn."},
    "Item/ItemRadar": {"name_vn": "Ra-đa bóng nước", "desc_vn": "Hiển thị phạm vi độ dài tia nước sẽ nổ."},
    "Item/ItemHollow": {"name_vn": "Bóng tàng hình", "desc_vn": "Làm quả bóng nước đặt ra trở nên trong suốt khó nhìn thấy."},
    "Item/ItemDevil": {"name_vn": "Quỷ tím", "desc_vn": "Gây đảo ngược phím di chuyển hoặc tự động đặt bóng nước (chạm vào người khác để lây)."},
    "Item/ItemSkeleton0": {"name_vn": "Đầu lâu", "desc_vn": "Gây hiệu ứng bất lợi ngẫu nhiên trong thời gian ngắn."},
    "Item/ItemGlue": {"name_vn": "Keo dính", "desc_vn": "Đặt bẫy keo trên mặt đất làm chậm tốc độ đối phương đạp phải."},
    "Item/ItemBanana": {"name_vn": "Vỏ chuối", "desc_vn": "Đặt vỏ chuối làm đối phương đạp phải bị trượt dài về phía trước."},
    "Item/ItemPin": {"name_vn": "Đinh ghim", "desc_vn": "Đặt đinh ghim trên sàn, bóng nước đặt lên ô có đinh sẽ phát nổ ngay lập tức!"},
    "Item/ItemTrap": {"name_vn": "Bẫy sập", "desc_vn": "Đặt bẫy tàng hình dưới đất, đối phương dẫm phải sẽ bị nhốt vào bóng nước ngay."},
    "Item/ItemSpanner": {"name_vn": "Cờ lê sửa chữa", "desc_vn": "Sửa đĩa bay hư hỏng trở thành đĩa bay tốc độ cao."},
    "Item/ItemCan": {"name_vn": "Hộp thức ăn", "desc_vn": "Cho rùa chậm ăn để biến thành rùa siêu tốc."},
    "Item/Lucci": {"name_vn": "Tiền vàng Lucci", "desc_vn": "Tiền vàng nhặt được dùng để mua trang phục trong Siêu Thị."},
    "Ship/Owl": {"name_vn": "Cú mèo", "desc_vn": "Thú cưỡi Cú mèo di chuyển tốc độ trung bình và đỡ được 1 lần trúng nước."},
    "Ship/Turtle0": {"name_vn": "Rùa con", "desc_vn": "Rùa bò rất chậm nhưng có thể tiến hóa thành Rùa siêu tốc."},
    "Ship/Turtle1": {"name_vn": "Rùa siêu tốc", "desc_vn": "Thú cưỡi Rùa chạy cực nhanh trên bản đồ."},
    "Ship/Airship": {"name_vn": "Đĩa bay UFO", "desc_vn": "Đĩa bay lơ lửng có thể bay xuyên qua mọi hộp mềm trên bản đồ!"},
    "Ship/AirshipBroken": {"name_vn": "Đĩa bay hỏng", "desc_vn": "Đĩa bay bị hỏng bay rất chậm nhưng vẫn đi xuyên qua hộp mềm."},
    "Ship/Octopus0": {"name_vn": "Bạch tuộc chậm", "desc_vn": "Thú cưỡi Bạch tuộc đại dương."},
    "Ship/Octopus1": {"name_vn": "Bạch tuộc nhanh", "desc_vn": "Thú cưỡi Bạch tuộc lướt nhanh như gió."},
    "Ship/Kart": {"name_vn": "Xe đua Kart", "desc_vn": "Xe đua tốc độ cao trên đường nhựa."},
    "Ship/Tank": {"name_vn": "Xe tăng", "desc_vn": "Chiến xa bọc thép có khả năng bắn đạn nước."},
    "Ship/Shark": {"name_vn": "Cá mập", "desc_vn": "Thú cưỡi Cá mập có thể nuốt bóng nước cản đường."},
}

payload = {
    "characters": characters,
    "prepare_char_slots": prepare_char_slots,
    "map_themes": map_themes,
    "maps": maps_locale,
    "items": items,
}

OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=1), encoding="utf-8")
print(f"Generated vn_locale.json: {len(characters)} chars, {len(maps_locale)} maps, {len(items)} items -> {OUT}")
