-- ============================================================================
-- GameData.lua - 游戏核心数据定义
-- 游戏名：异视（黄昏事务所）
-- 包含：角色、章节、线索（四大分类）、对话、开场动画、场景物件
-- ============================================================================

local M = {}

-- ============================================================================
-- 游戏全局状态
-- ============================================================================
M.GameState = {
    currentChapter = "prologue",   -- 当前章节
    currentScene = "office",       -- 当前场景
    playTime = 0,                  -- 游玩时长（秒）
    collectedClues = {},           -- 已收集线索ID列表（解锁/发现）
    readClues = {},                -- 笔记中已读的线索ID（map: id=true）
    starredClues = {},             -- 笔记中标记⭐的线索ID（map: id=true）
    flags = {},                    -- 游戏标志位
}

-- ============================================================================
-- 线索四大分类（文档 5.2 侦探笔记）
-- ============================================================================
M.ClueCategories = {
    { id = "evidence",  name = "物证档案", color = { 224, 172, 105, 255 } },
    { id = "testimony", name = "证言纪要", color = { 130, 200, 255, 255 } },
    { id = "personnel", name = "人物名录", color = { 150, 210, 150, 255 } },
    { id = "trace",     name = "现场痕迹", color = { 200, 160, 230, 255 } },
}

-- ============================================================================
-- 角色数据
-- ============================================================================
M.Characters = {
    LiZhi = {
        id = "LiZhi",
        name = "李志",
        age = 30,
        role = "黄昏事务所所长",
        color = { 100, 149, 237, 255 },  -- CornflowerBlue
        description = "落魄侦探，市井与理想并存。父亲是侦探小说家李明远（笔名秋白），25岁逆流创业开办'黄昏事务所'。",
    },
    ChenWenyin = {
        id = "ChenWenyin",
        name = "陈雯音",
        age = 12,
        role = "李志外甥女",
        color = { 255, 182, 193, 255 },  -- LightPink
        description = "天生能看到屏幕外的现实世界。3岁高烧后性格由活泼转为内敛沉静，不开口说话，仅通过行动传达线索。",
    },
    XuQinglan = {
        id = "XuQinglan",
        name = "许晴岚",
        age = 29,
        role = "澜星科技商务代表",
        color = { 218, 165, 32, 255 },  -- GoldenRod
        description = "李志大学同学。精明干练的'高智商辣妹'，八面玲珑但毒舌仗义。本次以澜星科技商务代表身份出席峰会。",
    },
    YanChengfeng = {
        id = "YanChengfeng",
        name = "严成峰",
        age = 51,
        role = "磐安智能执行总裁（死者）",
        color = { 128, 128, 128, 255 },
        description = "磐安智能联合创始人兼执行总裁。对外完美门面，对内暴虐毒瘤。重度哮喘导致极端控制欲，克扣员工、霸占成果。",
    },
    ZhaoHeng = {
        id = "ZhaoHeng",
        name = "赵恒",
        age = 45,
        role = "磐安智能商务副总",
        color = { 169, 169, 169, 255 },
        description = "八面玲珑的社交伪装，专门在严成峰把人得罪光后出来打圆场、拉投资。实际缺乏城府、遇事易慌乱崩溃。",
    },
    ZhouWen = {
        id = "ZhouWen",
        name = "周文",
        age = 30,
        role = "磐安智能技术骨干",
        color = { 72, 61, 139, 255 },  -- DarkSlateBlue
        description = "顶尖技术大牛，被严成峰清洗部门后降级贬为底层，精心策划复仇。",
    },
    ZhangChengyu = {
        id = "ZhangChengyu",
        name = "张承宇",
        age = 30,
        role = "重案组队长",
        color = { 70, 130, 180, 255 },  -- SteelBlue
        description = "李志大学同窗，口嫌体正直，表面冷嘲热讽实际高度认可李志能力。",
    },
    LiZhiSister = {
        id = "LiZhiSister",
        name = "李志姐姐",
        age = nil,
        role = "峰会创办人之一",
        color = { 220, 140, 190, 255 },
        description = "李志的姐姐，峰会创办人之一。把女儿陈雯音托付给李志，并安排万丽海湾大酒店3日住宿。",
    },
    FrontDesk = {
        id = "FrontDesk",
        name = "前台接待",
        age = nil,
        role = "酒店前台",
        color = { 150, 180, 210, 255 },
        description = "万丽海湾大酒店前台接待。",
    },
    PanganEmployee = {
        id = "PanganEmployee",
        name = "磐安员工",
        age = nil,
        role = "磐安智能员工",
        color = { 120, 120, 130, 255 },
        description = "严成峰随行人员。",
    },
    NewsAnchor = {
        id = "NewsAnchor",
        name = "平板新闻",
        age = nil,
        role = "AI新闻播报",
        color = { 180, 180, 180, 255 },
        description = "播报磐安智能AI故障的新闻。",
    },
    WaiterA = {
        id = "WaiterA",
        name = "服务员",
        age = nil,
        role = "酒店服务员",
        color = { 150, 180, 210, 255 },
        description = "万丽海湾大酒店服务员。",
    },
    WaiterB = {
        id = "WaiterB",
        name = "服务员",
        age = nil,
        role = "酒店服务员",
        color = { 150, 180, 210, 255 },
        description = "万丽海湾大酒店服务员。",
    },
    PoliceA = {
        id = "PoliceA",
        name = "执勤警察",
        age = nil,
        role = "现场执勤警察",
        color = { 120, 120, 130, 255 },
        description = "命案现场执勤的市局警察。",
    },
    Forensic = {
        id = "Forensic",
        name = "宋医生",
        age = nil,
        role = "市局法医",
        color = { 170, 200, 190, 255 },
        description = "市局法医，脾气直爽，看不惯年轻警察过度依赖AI。",
    },
    Guard = {
        id = "Guard",
        name = "保安",
        age = nil,
        role = "庭院入口保安",
        color = { 140, 150, 160, 255 },
        description = "酒店庭院入口执勤保安，记性不错。",
    },
}

-- ============================================================================
-- 章节数据
-- ============================================================================
M.Chapters = {
    prologue = {
        id = "prologue",
        title = "序章",
        subtitle = "黄昏事务所",
        description = "2036年8月。李志的外甥女陈雯音被寄养在事务所...",
        scenes = { "office" },
    },
    chapter1 = {
        id = "chapter1",
        title = "第一章",
        subtitle = "万丽海湾大酒店",
        description = "命案发生在万丽海湾大酒店25楼...",
        scenes = { "hotel_lobby", "hotel_courtyard", "hotel_corridor", "crime_scene" },
    },
}

-- ============================================================================
-- 线索数据（含四大分类）
-- category: evidence=物证档案 / testimony=证言纪要 / personnel=人物名录 / trace=现场痕迹
-- ============================================================================
M.Clues = {
    -- ===== 序章（第一段）线索 =====
    bookshelf = {
        id = "bookshelf",
        name = "书柜",
        category = "trace",
        chapter = "prologue",
        description = "里面摆满了侦探小说，大多都是一名叫'秋白'的作者写的。",
        detail = "书架几乎被一位名叫'秋白'的作者填满。那些侦探小说的封皮已经起了毛边，显然被反复翻阅过。",
    },
    wardrobe = {
        id = "wardrobe",
        name = "衣柜",
        category = "trace",
        chapter = "prologue",
        description = "里面堆满了深色的衣服，衣服堆下面似乎埋着李志的袜子。",
        detail = "衣柜深处堆满了深色衣服，在衣服堆的最下面，露出一只皱巴巴的袜子。",
    },
    bed = {
        id = "bed",
        name = "床铺",
        category = "trace",
        chapter = "prologue",
        description = "这段时间都由陈雯音睡在这张床上。",
        detail = "这张床收拾得整整齐齐，被褥叠得方方正正。这段时间都由陈雯音睡在这里。",
    },

    -- ===== 第一章（第二段）：1F 酒店大堂与前台区 =====
    lobby_fountain = {
        id = "lobby_fountain",
        name = "室内流水假山",
        category = "trace",
        chapter = "chapter1",
        description = "大堂正中一座由整块太湖石与循环水景雕琢的华丽假山，流水潺潺。",
        detail = "假山的水流声很大，足以掩盖近距离的低声交谈。有人在假山后低声说着什么，听得并不真切。",
    },
    lobby_stand = {
        id = "lobby_stand",
        name = "峰会展架",
        category = "trace",
        chapter = "chapter1",
        description = "'2036亚太前沿人工智能与智能安全闭门研讨会'特制展架，主赞助商为磐安智能。",
        detail = "展架上有磐安智能的Logo和严成峰的商务肖像。这位执行总裁在照片里笑得和蔼可亲，与传闻判若两人。",
    },
    lobby_delivery = {
        id = "lobby_delivery",
        name = "外卖暂存柜",
        category = "trace",
        chapter = "chapter1",
        description = "前台左侧的蜂巢式恒温配送柜，配有无人机接驳口与液晶扫码屏。",
        detail = "扫码屏上残留着几条取件记录，其中一条的柜号被擦得有些模糊。",
    },
    lobby_signbook = {
        id = "lobby_signbook",
        name = "VIP签到簿",
        category = "evidence",
        chapter = "chapter1",
        description = "VIP贵宾签到簿与房卡盒。前台表示非授权人员无法查看。",
        detail = "签到簿上密密麻麻记录着参会高管的入住信息，前台礼貌地拒绝了查看请求。",
        image = "assets/image/clue_signbook.png",
    },

    -- ===== 第一章（第二段）：1F 露天庭院连廊与茶歇区 =====
    court_plant = {
        id = "court_plant",
        name = "罗马柱与盆栽",
        category = "trace",
        chapter = "chapter1",
        description = "连廊两侧的罗马柱与茂密盆栽，形成了视线死角。",
        detail = "盆栽后是一处视线死角。之前似乎有人在这里压低声音打电话。",
    },
    court_table = {
        id = "court_table",
        name = "茶歇长桌",
        category = "trace",
        chapter = "chapter1",
        description = "摆满法式甜点、水果塔和黑咖啡壶的茶歇长桌。",
        detail = "甜点几乎没有被动过，倒是黑咖啡壶已经空了一半。",
    },
    court_power = {
        id = "court_power",
        name = "公共电源桩",
        category = "trace",
        chapter = "chapter1",
        description = "木质长椅旁的金属防雨电源插座桩。",
        detail = "电源桩的插座处有轻微的焦痕，像是被什么东西长时间占用过。",
    },
    court_fountain = {
        id = "court_fountain",
        name = "音乐喷泉中控箱",
        category = "trace",
        chapter = "chapter1",
        description = "带电子时钟的音乐喷泉中控柱，整点会准时报时。",
        detail = "中控柱上的电子时钟走得很准，整点准时响起音乐报时——这是可靠的时间标尺。",
        image = "assets/image/clue_fountain.png",
    },
    court_wifi = {
        id = "court_wifi",
        name = "Wi-Fi 8 路由",
        category = "trace",
        chapter = "chapter1",
        description = "记录设备内网连接日志的Wi-Fi 8路由。",
        detail = "路由器指示灯规律闪烁，后台记录着每一台设备的接入与断开时间。",
    },

    -- ===== 第一章（第二段）：25F VIP 客房走廊与电梯 =====
    room_2501 = {
        id = "room_2501",
        name = "2501房",
        category = "trace",
        chapter = "chapter1",
        description = "严成峰的套房，门缝里飘出一股淡淡的药水味。",
        detail = "2501房是严成峰的套房，门缝下透出一丝若有若无的药水味。",
    },
    room_2502 = {
        id = "room_2502",
        name = "2502房",
        category = "trace",
        chapter = "chapter1",
        description = "赵恒的房间。",
        detail = "2502房房门紧闭，门牌显示这是赵恒的房间。",
    },
    room_2504 = {
        id = "room_2504",
        name = "2504房",
        category = "trace",
        chapter = "chapter1",
        description = "李志和陈雯音的房间。",
        detail = "2504房是李志和陈雯音的房间。",
    },
    room_2505 = {
        id = "room_2505",
        name = "2505房",
        category = "trace",
        chapter = "chapter1",
        description = "许晴岚的房间，就在李志隔壁。",
        detail = "2505房是许晴岚的房间，就在李志房间的隔壁。",
    },

    -- ===== 第一章（第二段）：案发现场（2501房） =====
    body_position = {
        id = "body_position",
        name = "尸体位置",
        category = "evidence",
        chapter = "chapter1",
        description = "严成峰的尸体倒在客房内，面部朝下，没有明显外伤。",
        detail = "严成峰面部朝下倒在客房地板上，身体没有明显外伤，死状蹊跷。",
        image = "assets/image/clue_body.png",
    },
    inhaler = {
        id = "inhaler",
        name = "哮喘吸入器",
        category = "evidence",
        chapter = "chapter1",
        description = "死者身边的哮喘吸入器不见了，这可能是关键。",
        detail = "严成峰有重度哮喘，吸入器本应不离身，此刻却不在手边。",
        image = "assets/image/clue_inhaler.png",
    },
    smart_device = {
        id = "smart_device",
        name = "智能温控异常",
        category = "evidence",
        chapter = "chapter1",
        description = "房间内的智能温控系统显示凌晨3点有过一次异常操作。",
        detail = "温控系统记录显示，凌晨3点温度曾被骤降至16度。",
    },

    -- ===== 证言纪要 =====
    frontdesk_statement = {
        id = "frontdesk_statement",
        name = "前台证词",
        category = "testimony",
        chapter = "chapter1",
        description = "酒店已被峰会主办方联合包场，非参会核准人员无法办理入住。",
        detail = "前台称：'本酒店已被峰会主办方联合包场，按安保要求，非参会核准人员无法办理入住。'",
    },
    xu_intro_panan = {
        id = "xu_intro_panan",
        name = "许晴岚谈磐安",
        category = "testimony",
        chapter = "chapter1",
        description = "许晴岚介绍：严成峰专横跋扈，员工敢反驳一句当天就卷铺盖滚蛋。",
        detail = "许晴岚：'磐安智能的那帮高管。领头那个嘴碎的老头就是联合创始人兼执行总裁严成峰，业内出了名的专横跋扈、高压独裁。'",
    },
    sister_call = {
        id = "sister_call",
        name = "姐姐的电话",
        category = "testimony",
        chapter = "chapter1",
        description = "李志姐姐是峰会创办人之一，让李志顶顾问头衔白住套房度假。",
        detail = "李志姐姐：'我又是峰会一开始的创办人之一，公司每年必须要派代表过去，你就将就一下吧，反正也不用你做什么。'",
    },

    -- ===== 人物名录（随剧情解锁） =====
    char_lizhi = {
        id = "char_lizhi",
        name = "李志",
        category = "personnel",
        chapter = "prologue",
        description = "落魄侦探，黄昏事务所所长。",
        detail = "落魄侦探，市井与理想并存。父亲是侦探小说家李明远（笔名秋白）。",
    },
    char_wenyin = {
        id = "char_wenyin",
        name = "陈雯音",
        category = "personnel",
        chapter = "prologue",
        description = "李志的外甥女，能看到屏幕外的人。",
        detail = "天生能看到屏幕外的现实世界。3岁高烧后不再开口说话，仅通过行动传达线索。",
    },
    char_xuqinglan = {
        id = "char_xuqinglan",
        name = "许晴岚",
        category = "personnel",
        chapter = "chapter1",
        description = "澜星科技商务代表，李志大学同学。",
        detail = "精明干练的'高智商辣妹'，八面玲珑但毒舌仗义。本次以澜星科技商务代表身份出席峰会。",
    },
    char_yanchengfeng = {
        id = "char_yanchengfeng",
        name = "严成峰",
        category = "personnel",
        chapter = "chapter1",
        description = "磐安智能执行总裁（死者）。",
        detail = "磐安智能联合创始人兼执行总裁。重度哮喘导致极端控制欲，克扣员工、霸占成果。",
    },
    char_zhaoheng = {
        id = "char_zhaoheng",
        name = "赵恒",
        category = "personnel",
        chapter = "chapter1",
        description = "磐安智能商务副总。",
        detail = "标准的老好人面孔，专门负责在严成峰把人得罪光后出来擦屁股、拉投资。",
    },
    char_zhouwen = {
        id = "char_zhouwen",
        name = "周文",
        category = "personnel",
        chapter = "chapter1",
        description = "磐安智能技术骨干。",
        detail = "顶尖技术大牛，被严成峰清洗部门后降级贬为底层。",
    },
    char_zhangchengyu = {
        id = "char_zhangchengyu",
        name = "张承宇",
        category = "personnel",
        chapter = "chapter1",
        description = "重案组队长，李志大学同窗。",
        detail = "口嫌体正直，表面冷嘲热讽实际高度认可李志能力。",
    },
}

-- ============================================================================
-- 对话数据
-- ============================================================================
M.Dialogues = {
    -- ===== 第一段开场动画（5个序列） =====
    opening_prologue_1 = {
        id = "opening_prologue_1",
        background = "assets/image/bg_prologue_living_desk_20260831144801.png",
        lines = {
            { speaker = "", text = "男女主在事务所内，李志正睡在地铺上。已是下午13点，陈雯音坐在李志身上打了他一个耳光，李志被吓醒坐起，陈雯音已坐到了一旁的凳子上。" },
            { speaker = "LiZhi", text = "几点了？" },
            { speaker = "", text = "李志看了眼墙上的时钟，显得有些慌张。" },
            { speaker = "LiZhi", text = "1点了么？你是不是饿了雯雯？" },
            { speaker = "", text = "陈雯音点了点头。" },
        },
    },
    opening_prologue_2 = {
        id = "opening_prologue_2",
        background = "assets/image/bg_prologue_living_kitchen_20260831144830.png",
        lines = {
            { speaker = "", text = "镜头切换，李志站在厨台前煮着泡面，陈雯音在一旁看着。" },
            { speaker = "LiZhi", text = "你说热水器就在这里，你为什么就不能自己用来泡面呢？" },
            { speaker = "ChenWenyin", text = "…" },
            { speaker = "", text = "李志扭头看了陈雯音一眼。" },
            { speaker = "LiZhi", text = "唉…我记得你以前还会叫我舅舅的，现在怎么都不会说话了呢？" },
        },
    },
    opening_prologue_3 = {
        id = "opening_prologue_3",
        background = "assets/image/bg_prologue_bedroom_wide_20260831144913.png",
        lines = {
            { speaker = "", text = "（画面切入回忆，黑屏显示：2036年8月8日 14:20）" },
            { speaker = "", text = "李志在房间门内，李志姐姐和陈雯音在房间门外。" },
            { speaker = "LiZhi", text = "不是吧老姐，你真放心把你女儿让我来带啊？" },
            { speaker = "LiZhiSister", text = "爸妈都出去旅游了，我不找你还能找谁？" },
            { speaker = "LiZhi", text = "可是我从来没带过小孩啊？！" },
            { speaker = "LiZhiSister", text = "雯雯很聪明，比你靠谱多了，不需要你瞎操心，你只要记得叫她吃饭，帮她铺好床垫就行了，其他的她自己会搞定的。" },
            { speaker = "ChenWenyin", text = "…" },
            { speaker = "LiZhi", text = "可是…" },
            { speaker = "LiZhiSister", text = "十万。" },
            { speaker = "LiZhi", text = "什么？！" },
            { speaker = "LiZhiSister", text = "十万块，算你这两个月的养育费，外加万丽海湾大酒店的3日住宿。" },
            { speaker = "LiZhi", text = "遵命，我亲爱的姐姐，就把雯雯放心交给我吧。" },
            { speaker = "LiZhi", text = "雯雯，从今天开始多多指教啦。" },
        },
    },
    opening_prologue_4 = {
        id = "opening_prologue_4",
        background = "assets/image/bg_prologue_living_sofa_20260831145041.png",
        lines = {
            { speaker = "", text = "切回原场景。两人坐在桌前吃泡面，桌子中间放着一台播放AI新闻的平板。" },
            { speaker = "NewsAnchor", text = "据悉，这是近10年来第一次出现AI错误，目前磐安智能正在全力排查故障原因。" },
            { speaker = "LiZhi", text = "好像你就是因为这次AI事故导致签证没能签下来是吧？" },
            { speaker = "", text = "陈雯音点了点头，继续吃着面条。" },
            { speaker = "LiZhi", text = "所以我就说吧，人类现在还是太依赖AI了，这么基本的问题换成是人早就当即解决了，真是有意思。" },
            { speaker = "", text = "李志埋头嗦了一口面条。" },
            { speaker = "LiZhi", text = "话说雯雯你行李收拾好了么？我们明天一早就出发咯。" },
            { speaker = "", text = "陈雯音点头示意。" },
        },
    },
    opening_prologue_5 = {
        id = "opening_prologue_5",
        background = "assets/image/bg_prologue_bedroom_wardrobe_20260831145010.png",
        lines = {
            { speaker = "", text = "切换到事务所卧室，李志正对着衣柜翻找着什么。" },
            { speaker = "LiZhi", text = "雯雯，有看到我的袜子吗？" },
        },
    },
    opening_prologue_5_after = {
        id = "opening_prologue_5_after",
        background = "assets/image/bg_prologue_bedroom_wardrobe_20260831145010.png",
        lines = {
            { speaker = "", text = "陈雯音嫌弃地指了指柜子底层。" },
            { speaker = "LiZhi", text = "看到了看到了，还得是雯雯，住几天比我还了解这个家，嘿嘿。" },
        },
    },

    -- ===== 第二段开场动画（5个序列） =====
    opening_chapter1_1 = {
        id = "opening_chapter1_1",
        lines = {
            { speaker = "", text = "李志一手插兜，把两张身份证递给酒店前台。陈雯音站在他右边，默默注视着身后一座会喷水的小型山景。" },
            { speaker = "FrontDesk", text = "李先生您好，您预订的'海景行政套房'确认无误。请问……您是来参加本次'亚太智能终端交互峰会'的参会代表，对吧？" },
            { speaker = "LiZhi", text = "峰会？——呃，不是，我只是带小孩来海边度个假的……我姐应该已经帮我们预定好了才对。" },
            { speaker = "FrontDesk", text = "十分抱歉，李先生。本酒店已被峰会主办方联合包场，按安保要求，非参会核准人员无法办理入住。您这边的房间是由'澜星科技'走公账锁定的参会高管配额，需要出示参会代表凭证哦……" },
            { speaker = "LiZhi", text = "该死……我就知道顶层海景房绝对没这么好白嫖。" },
        },
    },
    opening_chapter1_2 = {
        id = "opening_chapter1_2",
        background = "assets/image/bg_hotel_lobby.png",
        lines = {
            { speaker = "", text = "镜头向右移动，许晴岚登场，递上一张卡片示意李志佩戴上。" },
            { speaker = "XuQinglan", text = "辛苦了。这是澜星科技特聘高级安全顾问'李志'先生的参会凭证，身份备案已经同步到峰会主控系统了，麻烦直接激活房卡吧。" },
            { speaker = "FrontDesk", text = "好的许助理！马上为您办理。" },
            { speaker = "LiZhi", text = "许晴岚？你怎么在这？" },
            { speaker = "XuQinglan", text = "那当然是应你姐的要求来带你见见世面啦，李顾问。" },
            { speaker = "LiZhi", text = "可我啥都不懂啊？！还有这头衔是什么鬼？" },
            { speaker = "XuQinglan", text = "放宽心，李大顾问。李总特意交代了，会场里各家大厂的商务对接、技术交流全由我一个人搞定，您只需要挂着这块牌子在大堂和自助餐厅随便晃晃就行。当然——李总的原话是：'既然顶了顾问的头衔白住八千八的套房，就老老实实呆在酒店安心度假'。" },
            { speaker = "LiZhi", text = "所以感情这种大型峰会，你们公司就派了你一个是吧？" },
            { speaker = "XuQinglan", text = "这不是还有你吗？不过你姐也说了，'这种一大堆老年人闲聊的交流会也没什么好参加的'，大概是这样。" },
            { speaker = "LiZhi", text = "好吧，不用我干活就行……" },
        },
    },
    opening_chapter1_3 = {
        id = "opening_chapter1_3",
        background = "assets/image/bg_hotel_lobby.png",
        lines = {
            { speaker = "", text = "镜头朝左移动至酒店入口。左侧进来5人，严成峰和赵恒并列走在最前面，磐安员工甲、乙跟在身后，周文最后提着大小包，唯唯诺诺不敢看众人。" },
            { speaker = "PanganEmployee", text = "周文，你能不能走快点？严总和赵总在前面，你缩在后面像个贼一样！等会儿进了套房，立刻把演示系统连上专线，要是峰会交流环节有投资人问起底层逻辑你答不上来，回公司有你好看的！" },
            { speaker = "ZhouWen", text = "是……组长，我知道了，数据已经在本地备好了……" },
            { speaker = "", text = "严成峰一行人在许晴岚面前停下。" },
            { speaker = "YanChengfeng", text = "哟，这不是澜星科技的许助理吗？怎么，你们李总和陈总自己不露面，就派你带了这么两位'重量级'专家过来参会？" },
            { speaker = "YanChengfeng", text = "现在的科技交流会门槛真是一年不如一年。一个穿得像来收旧电器的，还顺带拖家带口领个小毛孩。不知道的，还以为澜星科技连员工差旅费都发不出来，全家老小跑来五星级酒店蹭假期的。" },
            { speaker = "XuQinglan", text = "严总您真会说笑。我们李总向来注重效率，交流会这种场合，把实干的人派到位就够了，用不着摆出一副前呼后拥的威风排场。毕竟……真正的硬实力靠的是底层架构，而不是靠在走廊上大呼小叫训斥手下员工来找存在感，您说是吧？" },
            { speaker = "XuQinglan", text = "另外，大堂冷气足，严总可得注意身体。我看您这脚步虚浮、气喘不匀的，等会儿要是交流会还没开始就先倒下了，外界还以为是磐安智能的资金链压力太大，把严总累垮了呢。" },
            { speaker = "YanChengfeng", text = "你…呵…一个小小的助理，嘴皮子倒挺刻薄的。" },
            { speaker = "ZhaoHeng", text = "哎呀两位，消消气消消气！大家都是同行老朋友，许助理年轻气盛开个玩笑而已。坐了一路车大家都累了，先去办理入住，别耽误了正事！" },
            { speaker = "YanChengfeng", text = "哼。赵恒，带他们办手续。别在这里跟闲杂人等浪费唇舌。" },
        },
    },
    opening_chapter1_4 = {
        id = "opening_chapter1_4",
        background = "assets/image/bg_hotel_lobby.png",
        lines = {
            { speaker = "", text = "画面切换，刚才5人已离开大厅。陈雯音目视电梯的方向。" },
            { speaker = "LiZhi", text = "啧啧，许大助理，战力不减当年呐。" },
            { speaker = "XuQinglan", text = "呼……小意思。对待这种仗着资历作威作福的老古董，不刺他两句我简直浑身难受。" },
            { speaker = "LiZhi", text = "刚才那帮人什么来头？" },
            { speaker = "XuQinglan", text = "还能是谁？'磐安智能'的那帮高管。领头那个嘴碎的老头就是他们的联合创始人兼执行总裁——严成峰。业内出了名的专横跋扈、高压独裁，听说在他们公司内部，员工只要敢反驳他一句，当天就能卷铺盖滚蛋。" },
            { speaker = "LiZhi", text = "那旁边那个戴金丝眼镜、负责赔笑打圆场的呢？" },
            { speaker = "XuQinglan", text = "赵恒，磐安的另一位董事兼商务副总。标准的老好人面孔，专门负责在严成峰把人得罪光之后出来擦屁股、拉投资。至于严成峰身边那两个跟班，穿西装的是法务部的马屁精，另一个横眉竖眼的是他们技术部的中层组长。" },
            { speaker = "LiZhi", text = "好像他们最后还有一个人吧？" },
            { speaker = "XuQinglan", text = "最后那个我好像没什么印象了，不过很眼熟就是了。对了，房卡给你，如果雯雯有需要帮助的就来找我，我就在你们隔壁，知道了么？" },
            { speaker = "", text = "许晴岚递上房卡，此时电梯刚好到了。" },
            { speaker = "LiZhi", text = "好吧，不过在此之前，看来我得先跟我那个好姐姐'核对'一下。" },
        },
    },
    opening_chapter1_5 = {
        id = "opening_chapter1_5",
        background = "assets/image/bg_crime_scene.png",
        lines = {
            { speaker = "", text = "（画面切换，黑屏显示：2036年8月13日 10:17，万丽海湾大酒店 2510房）" },
            { speaker = "", text = "李志在房间里拿着手机与姐姐通话。" },
            { speaker = "LiZhi", text = "喂？老姐，不是说纯度假吗？！" },
            { speaker = "LiZhiSister", text = "哎呀，这每年峰会又要组织，每年又讨论不出什么，纯浪费时间，我又是一开始的创办人之一，所以公司每年又必须要派代表过去，你就将就一下吧，反正也不用你做什么，你就在五星级套房里吹空调喝咖啡，顺便带雯雯吃大餐，房费姐全包了。行了，我在敷面膜，别吵我，拜~" },
            { speaker = "LiZhi", text = "挂的真快啊……" },
        },
    },

    -- ===== 第二章开场后：自由探索引导 =====
    chapter1_free_explore = {
        id = "chapter1_free_explore",
        lines = {
            { speaker = "LiZhi", text = "好了，先四处转转，熟悉一下这家大酒店。" },
            { speaker = "", text = "（点击场景中的可交互物件进行调查，收集到的线索会记录在侦探笔记里，按 Tab 键可以随时查看。）" },
        },
    },

    -- ===== 命案发现 =====
    crime_found = {
        id = "crime_found",
        lines = {
            { speaker = "ZhangChengyu", text = "李志？你怎么在这儿？" },
            { speaker = "LiZhi", text = "我现在是'澜星特聘高级安全顾问'。许晴岚给我弄的身份。" },
            { speaker = "ZhangChengyu", text = "……行。既然你来了，别乱碰现场的东西。" },
            { speaker = "ZhangChengyu", text = "死者严成峰，51岁，磐安智能原始股东董事。被发现倒在客房内。" },
            { speaker = "LiZhi", text = "有意思。让我看看……" },
        },
    },

    -- ===== 结案推理：推理独白 =====
    crime_deduction = {
        id = "crime_deduction",
        lines = {
            { speaker = "LiZhi", text = "把线索串起来。" },
            { speaker = "LiZhi", text = "温控面板记录：凌晨3点，房间温度被远程骤降到16度。" },
            { speaker = "LiZhi", text = "一个重度哮喘病人，在16度的房间里，急救吸入器却不见踪影。" },
            { speaker = "LiZhi", text = "床头柜空空如也——本该不离身的吸入器，被人提前拿走了。" },
            { speaker = "LiZhi", text = "而他的测试服系统里，有一份凌晨推送的数据包，签名是内部技术账号。" },
            { speaker = "LiZhi", text = "能远程改温控、能往测试服塞指令、又能神不知鬼不觉拿走吸入器的人……" },
            { speaker = "LiZhi", text = "不是外人。是这栋楼里、有权限、也最有动机的那个。" },
            { speaker = "LiZhi", text = "凶手，就是你。" },
        },
    },

    -- ===== 结案：真结局（指认周文）=====
    crime_ending_true = {
        id = "crime_ending_true",
        lines = {
            { speaker = "LiZhi", text = "周文。" },
            { speaker = "ZhouWen", text = "……你凭什么这么说？" },
            { speaker = "LiZhi", text = "凌晨3点，你用技术账号把房间温控降到16度，又往严成峰的测试服推了条指令。" },
            { speaker = "LiZhi", text = "他哮喘发作，摸向床头柜——吸入器早被你拿走。他跌跌撞撞想去开窗，却从25楼坠了下去。" },
            { speaker = "ZhangChengyu", text = "……严成峰昨天放话，'明天让你卷铺盖滚蛋'。" },
            { speaker = "ZhangChengyu", text = "你赌他一倒，你那些事就没人追究了？" },
            { speaker = "ZhouWen", text = "我只是……不想连累家里人……" },
            { speaker = "ZhangChengyu", text = "带走。剩下的交给法院。" },
            { speaker = "LiZhi", text = "（黄昏事务所的灯，今晚可以早点熄了。）" },
            },

    },
    -- 序章办公室物件对话（CSV 化前的兜底副本；运行时若 assets/data/dialogues.csv 存在则被其覆盖）
    of_bookshelf = {
        id = "of_bookshelf",
        lines = {
            { speaker = "LiZhi", text = "书柜里几乎被一位名叫'秋白'的作者填满。封皮起了毛边，显然被反复翻阅过。" },
            { speaker = "LiZhi", text = "'秋白'……这名字有点耳熟。陈姐生前啃这些推理小说，对密室和不在场证明的套路，怕是比我还熟。" },
        },
    },
    of_desk = {
        id = "of_desk",
        lines = {
            { speaker = "LiZhi", text = "桌上散落着未结案的委托档案，还有几个空泡面杯——陈姐最近接的活儿不少。" },
            { speaker = "LiZhi", text = "这些案子大多不了了之。她总说，有些真相，当事人并不想知道。" },
        },
    },
    of_bed = {
        id = "of_bed",
        lines = {
            { speaker = "LiZhi", text = "这张地铺很小，这段时间都由雯音睡在这里。" },
            { speaker = "LiZhi", text = "我这个当舅舅的，连张像样的床都给不了她……等这案子了了，带她离开这个破地方。" },
        },
    },
    -- 误导物件：台灯（非线索，触发"错误方向"对话，引导玩家去正确线索——衣柜）
    of_lamp_mislead = {
        id = "of_lamp_mislead",
        lines = {
            { speaker = "LiZhi", text = "暖黄的灯光，是这间事务所唯一的温度。" },
            { speaker = "LiZhi", text = "（戳了戳灯罩）可惜这玩意儿和案子八竿子打不着。" },
            { speaker = "LiZhi", text = "线索不会藏在'舒服'的地方。我得去翻翻别处——比如那个衣柜。" },
        },
    },
}

-- ============================================================================
-- 开场动画数据（OpeningSystem 使用）
-- ============================================================================
M.Openings = {
    prologue = {
        time = "2036年8月12日 12:59",
        location = "黄昏事务所",
        dialogues = {
            "opening_prologue_1",
            "opening_prologue_2",
            "opening_prologue_3",
            "opening_prologue_4",
            "opening_prologue_5",
        },
    },
    chapter1 = {
        time = "2036年8月13日 09:32",
        location = "万丽海湾大酒店",
        dialogues = {
            "opening_chapter1_1",
            "opening_chapter1_2",
            "opening_chapter1_3",
            "opening_chapter1_4",
            "opening_chapter1_5",
        },
    },
}

-- ============================================================================
-- 开场分镜表（镜头 / 角色站位）
-- key = 分镜对话 id；背景图取自 dialogues.csv 的 background 列
-- actor: x/y = 角色「底部中心」的归一化屏幕坐标，h = 占屏高比例，ratio = 立绘宽高比
-- 立绘实际比例均为 805x1200 = 0.671
-- ============================================================================
M.OpeningShots = {
    -- 镜1：事务所地铺，李志被叫醒
    opening_prologue_1 = {
        caption = "事务所 · 地铺",
        actors = {
            { sprite = "assets/image/char_lizhi.png",   x = 0.30, y = 0.90, h = 0.52, ratio = 0.671 },
            { sprite = "assets/image/char_wenyin.png",  x = 0.68, y = 0.86, h = 0.40, ratio = 0.671 },
        },
    },
    -- 镜2：镜头切到厨台，李志煮泡面，陈雯音一旁看着
    opening_prologue_2 = {
        caption = "事务所 · 厨台",
        actors = {
            { sprite = "assets/image/char_lizhi.png",   x = 0.34, y = 0.94, h = 0.56, ratio = 0.671 },
            { sprite = "assets/image/char_wenyin.png",  x = 0.72, y = 0.92, h = 0.42, ratio = 0.671 },
        },
    },
    -- 镜3：切入回忆，房间门口（李志门内 / 姐姐与雯音门外）
    opening_prologue_3 = {
        caption = "回忆 · 房间门",
        transitionDur = 1.1,   -- 切入回忆，切换放慢
        actors = {
            { sprite = "assets/image/char_lizhi.png",   x = 0.22, y = 0.92, h = 0.52, ratio = 0.671 },
            { sprite = "assets/image/char_sister.png",  x = 0.54, y = 0.94, h = 0.54, ratio = 0.671 },
            { sprite = "assets/image/char_wenyin.png",  x = 0.80, y = 0.90, h = 0.38, ratio = 0.671 },
        },
    },
    -- 镜4：切回事务所，桌前吃泡面 + 平板播AI新闻
    -- ⚠️ 原配置误写为「回忆·房间门 / 姐姐+雯音」，与 wolai 3.1 序列4（切回原场景、登场=李志+陈雯音）
    --    及台词（ NewsAnchor 1 句 + 李志 3 句）不符：会导致李志说了 3 句话却不在画面上。
    opening_prologue_4 = {
        caption = "事务所 · 桌前",
        actors = {
            { sprite = "assets/image/char_lizhi.png",   x = 0.36, y = 0.94, h = 0.54, ratio = 0.671 },
            { sprite = "assets/image/char_wenyin.png",  x = 0.68, y = 0.92, h = 0.40, ratio = 0.671 },
        },
    },
    opening_prologue_5 = {
        caption = "黄昏事务所",
        actors = {
            { sprite = "assets/image/char_lizhi.png",   x = 0.34, y = 0.92, h = 0.54, ratio = 0.671 },
            { sprite = "assets/image/char_wenyin.png",  x = 0.70, y = 0.90, h = 0.40, ratio = 0.671 },
        },
    },
    -- 序章镜5的行内切镜：换背景时保留李志和陈雯音的站位。
    opening_prologue_5_after = {
        caption = "黄昏事务所",
        actors = {
            { sprite = "assets/image/char_lizhi.png",   x = 0.34, y = 0.92, h = 0.54, ratio = 0.671 },
            { sprite = "assets/image/char_wenyin.png",  x = 0.70, y = 0.90, h = 0.40, ratio = 0.671 },
        },
    },
    -- 第一阶段：酒店前台，人物站位依据 dialogues.csv 的登场顺序。
    opening_chapter1_1 = {
        caption = "万丽海湾大酒店 · 前台",
        actors = {
            { sprite = "assets/image/char_lizhi.png",          x = 0.30, y = 0.94, h = 0.54, ratio = 0.671 },
            { sprite = "assets/image/char_wenyin.png",         x = 0.42, y = 0.94, h = 0.42, ratio = 0.671 },
            { sprite = "assets/image/char_receptionist.png",   x = 0.57, y = 0.72, h = 0.30, ratio = 0.671 },
        },
    },
    opening_chapter1_2 = {
        caption = "万丽海湾大酒店 · 前台右侧",
        actors = {
            { sprite = "assets/image/char_lizhi.png",          x = 0.27, y = 0.94, h = 0.52, ratio = 0.671 },
            { sprite = "assets/image/char_wenyin.png",         x = 0.39, y = 0.94, h = 0.40, ratio = 0.671 },
            { sprite = "assets/image/char_xuqinglan.png",      x = 0.60, y = 0.94, h = 0.54, ratio = 0.671 },
            { sprite = "assets/image/char_receptionist.png",   x = 0.78, y = 0.72, h = 0.30, ratio = 0.671 },
        },
    },
    opening_chapter1_3 = {
        caption = "万丽海湾大酒店 · 入口",
        actors = {
            { sprite = "assets/image/char_yanchengfeng.png",  x = 0.30, y = 0.94, h = 0.58, ratio = 0.671 },
            { sprite = "assets/image/char_zhaoheng.png",      x = 0.42, y = 0.94, h = 0.54, ratio = 0.671 },
            { sprite = "assets/image/char_pangan_employee_a.png", x = 0.54, y = 0.94, h = 0.46, ratio = 0.671 },
            { sprite = "assets/image/char_pangan_employee_b.png", x = 0.64, y = 0.94, h = 0.46, ratio = 0.671 },
            { sprite = "assets/image/char_zhouwen.png",       x = 0.76, y = 0.94, h = 0.48, ratio = 0.671 },
        },
    },
    opening_chapter1_4 = {
        caption = "万丽海湾大酒店 · 大厅",
        actors = {
            { sprite = "assets/image/char_lizhi.png",          x = 0.30, y = 0.94, h = 0.52, ratio = 0.671 },
            { sprite = "assets/image/char_wenyin.png",         x = 0.42, y = 0.94, h = 0.40, ratio = 0.671 },
            { sprite = "assets/image/char_xuqinglan.png",      x = 0.63, y = 0.94, h = 0.54, ratio = 0.671 },
        },
    },
    opening_chapter1_5 = {
        caption = "万丽海湾大酒店 · 2510房",
        actors = {
            { sprite = "assets/image/char_lizhi.png",          x = 0.38, y = 0.94, h = 0.54, ratio = 0.671 },
            { sprite = "assets/image/char_wenyin.png",         x = 0.53, y = 0.94, h = 0.40, ratio = 0.671 },
            { sprite = "assets/image/char_sister.png",         x = 0.74, y = 0.94, h = 0.52, ratio = 0.671 },
        },
    },
}

-- ============================================================================
-- 场景物件数据
-- x/y/w/h 为相对比例坐标（0~1）
-- ============================================================================
M.SceneObjects = {
    -- ===== 第一段：事务所（新手引导）· 一层横版卷轴 =====
    -- 采用两张确认过的连续背景：客厅 / 卧室；两者均为同一层。
    office = {
        title = "黄昏事务所",
        mode = "screens",
        minimap = {
            nodes = {
                { id = "s1", label = "客厅", nx = 0.28, ny = 0.55 },
                { id = "s2", label = "卧室", nx = 0.72, ny = 0.55 },
            },
            edges = { { "s1", "s2" } },
            start = "s1",
        },
        screens = {
            {
                id = "s1", title = "客厅与办公区",
                image = "assets/image/prologue_livingroom_clean.png",
                -- Figma 2031-6：背景矩形为 1928×819，子图层坐标以背景左上角为原点。
                -- 背景与物件共用同一套映射，横屏拉伸时背景和交互热区不会互相漂移。
                designW = 1928, designH = 819,
                backgroundFit = "fill", backgroundPosition = "center center",
                bgColor = { 150, 120, 70, 255 },
                charPos = { x = 0.22, y = 0.78, scale = 0.60 },
                left = nil, right = "s2",
                items = {
                    -- Figma 独立层：办公桌、餐桌、沙发；其余旧线索保留为无贴图交互热区，避免重复绘制背景内容。
                    { id = "lamp", name = "台灯", x = 0.383817, y = 0.341880, w = 0.057054, h = 0.225885,
                      dialogueId = "of_lamp_mislead", misleading = true },
                    { id = "stove", name = "灶台", x = 0.736515, y = 0.402930, w = 0.165975, h = 0.305250,
                      interactText = "靠墙的灶台和操作台很简陋，但足够煮一锅泡面。" },
                    { id = "sofa_left", name = "沙发", x = 0.569502, y = 0.599512, w = 0.267116, h = 0.288156, hoverScale = 1.08,
                      sprite = "assets/image/prologue_obj_sofa.png", interactiveSprite = true, spriteTrim = false, spriteRect = { x = 0.569502, y = 0.599512, w = 0.267116, h = 0.288156 },
                      interactText = "沙发靠垫有些塌，看来这里经常有人坐着。" },
                    { id = "sofa_right", name = "沙发边位", x = 0.517635, y = 0.521368, w = 0.129668, h = 0.288156,
                      interactText = "沙发旁边留出了通往餐桌的过道。" },
                    { id = "dining_table", name = "餐桌", x = 0.324170, y = 0.521368, w = 0.206950, h = 0.338217, hoverScale = 1.07,
                      sprite = "assets/image/prologue_obj_dining_table.png", interactiveSprite = true, spriteTrim = false, spriteRect = { x = 0.324170, y = 0.521368, w = 0.206950, h = 0.338217 },
                      interactText = "餐桌周围摆着椅子，桌面上还留着吃泡面的痕迹。" },
                    { id = "desk", name = "办公桌", x = 0.053942, y = 0.521368, w = 0.233402, h = 0.445665, hoverScale = 1.08,
                      sprite = "assets/image/prologue_obj_desk.png", interactiveSprite = true, spriteTrim = false, spriteRect = { x = 0.053942, y = 0.521368, w = 0.233402, h = 0.445665 },
                      clueId = "desk", dialogueId = "of_desk", interactText = "桌上散落着未结案的委托档案和空泡面杯。" },
                },
            },
            {
                id = "s2", title = "卧室",
                image = "assets/image/prologue_bedroom_clean.png",
                -- Figma 2031-11：背景矩形为 1928×819，子图层坐标以背景左上角为原点。
                -- 与客厅保持一致，背景和交互热区共用同一套映射，避免横屏比例变化时错位。
                designW = 1928, designH = 819,
                backgroundFit = "fill", backgroundPosition = "center center",
                bgColor = { 130, 105, 62, 255 },
                charPos = { x = 0.44, y = 0.78, scale = 0.60 },
                left = "s1", right = nil,
                items = {
                    { id = "bedroom_desk", name = "卧室桌子", x = 0.040975, y = 0.579976, w = 0.185166, h = 0.333333, hoverScale = 1.08,
                      sprite = "assets/image/prologue_obj_bedroom_desk.png", interactiveSprite = true, spriteTrim = false, spriteRect = { x = 0.040975, y = 0.579976, w = 0.185166, h = 0.333333 },
                      interactText = "卧室里的小桌子靠近入口，椅子紧挨在桌子右侧。" },
                    { id = "bedroom_chair", name = "卧室椅子", x = 0.357884, y = 0.592186, w = 0.057054, h = 0.219780,
                      interactText = "椅子正好放在桌子右边，旁边留着进出的空隙。" },
                    { id = "bed", name = "床铺", x = 0.167012, y = 0.584860, w = 0.274896, h = 0.225885, hoverScale = 1.07,
                      sprite = "assets/image/prologue_obj_bed.png", interactiveSprite = true, spriteTrim = false, spriteRect = { x = 0.167012, y = 0.584860, w = 0.274896, h = 0.225885 },
                      clueId = "bed", dialogueId = "of_bed", interactText = "这段时间都由陈雯音睡在这张床上。" },
                    { id = "wardrobe", name = "衣柜", x = 0.586618, y = 0.333333, w = 0.248444, h = 0.463980, hoverScale = 1.06,
                      sprite = "assets/image/prologue_obj_wardrobe.png", interactiveSprite = true, spriteTrim = false, spriteRect = { x = 0.586618, y = 0.333333, w = 0.248444, h = 0.463980 },
                      clueId = "wardrobe", interactText = "右侧墙边并排放着两个衣柜，柜子底层似乎露出了一只袜子。", onInteract = "wardrobe" },
                },
            },
        },
    },

    -- ===== 第二段：1F 酒店大堂与前台区 · 五页横版翻页 =====
    hotel_lobby = {
        title = "酒店大堂与前台区",
        mode = "screens",
        minimap = {
            nodes = {
                { id = "s1", label = "正门", nx = 0.10, ny = 0.56 },
                { id = "s2", label = "前台", nx = 0.30, ny = 0.40 },
                { id = "s3", label = "假山", nx = 0.50, ny = 0.56 },
                { id = "s4", label = "电梯", nx = 0.70, ny = 0.40 },
                { id = "s5", label = "安全通道", nx = 0.90, ny = 0.56 },
            },
            edges = { { "s1", "s2" }, { "s2", "s3" }, { "s3", "s4" }, { "s4", "s5" } },
            start = "s1",
        },
        screens = {
            {
                id = "s1", title = "正门与展架",
                image = "assets/image/lobby_scroll_01_clean.png",
                bgColor = { 150, 120, 70, 255 },
                left = nil, right = "s2",
                items = {
                    { id = "umbrella", name = "雨伞架", x = 0.08, y = 0.52, w = 0.18, h = 0.30,
                      sprite = "assets/image/lobby_obj_umbrella_rack.png", interactiveSprite = true,
                      interactText = "门厅雨伞架里插着几把长伞，伞尖还在滴水。" },
                    { id = "stand", name = "峰会展架", x = 0.42, y = 0.30, w = 0.28, h = 0.46,
                      sprite = "assets/image/lobby_obj_conference_stand.png", interactiveSprite = true,
                      clueId = "lobby_stand", interactText = "展架上挂着磐安智能的标志和严成峰的商务肖像。" },
                },
            },
            {
                id = "s2", title = "前台与露天庭院入口",
                image = "assets/image/lobby_scroll_02_clean.png",
                bgColor = { 160, 130, 75, 255 },
                left = "s1", right = "s3",
                items = {
                    { id = "signbook", name = "VIP签到簿与房卡盒", x = 0.34, y = 0.50, w = 0.28, h = 0.24,
                      sprite = "assets/image/lobby_obj_vip_signbook.png", interactiveSprite = true,
                      clueId = "lobby_signbook", interactText = "前台桌面摆着VIP签到簿与房卡盒，非授权人员无法查看。" },
                    { id = "delivery", name = "外卖暂存柜", x = 0.76, y = 0.30, w = 0.18, h = 0.44,
                      sprite = "assets/image/lobby_obj_delivery_locker.png", interactiveSprite = true,
                      clueId = "lobby_delivery", interactText = "蜂巢式恒温配送柜的扫码屏残留着几条取件记录。" },
                },
                exits = {
                    { id = "to_courtyard", label = "露天庭院", targetScene = "hotel_courtyard", x = 0.66, y = 0.08, w = 0.22, h = 0.26 },
                },
            },
            {
                id = "s3", title = "中央流水假山",
                image = "assets/image/lobby_scroll_03_clean.png",
                bgColor = { 140, 115, 65, 255 },
                left = "s2", right = "s4",
                items = {
                    { id = "fountain", name = "室内流水假山", x = 0.34, y = 0.34, w = 0.34, h = 0.44,
                      sprite = "assets/image/lobby_obj_fountain.png", interactiveSprite = true,
                      clueId = "lobby_fountain", interactText = "太湖石循环水景的水声很大，足以掩盖近距离的低声交谈。" },
                },
            },
            {
                id = "s4", title = "电梯厅与垃圾桶",
                image = "assets/image/lobby_scroll_04_clean.png",
                bgColor = { 135, 115, 75, 255 },
                left = "s3", right = "s5",
                items = {
                    { id = "lobby_elevator_upper", name = "左侧电梯", x = 0.16, y = 0.20, w = 0.18, h = 0.60,
                      sprite = "assets/image/lobby_obj_elevator_door.png", interactiveSprite = true,
                      interactText = "电梯门紧闭，顶部楼层指示灯保持待机。" },
                    { id = "lobby_trash_upper", name = "垃圾桶", x = 0.37, y = 0.52, w = 0.12, h = 0.24,
                      sprite = "assets/image/lobby_obj_trash_bin.png", interactiveSprite = true,
                      interactText = "酒店大堂的分类垃圾桶，桶内只有几张揉皱的纸巾。" },
                    { id = "lobby_elevator_middle", name = "中间电梯", x = 0.48, y = 0.20, w = 0.18, h = 0.60,
                      sprite = "assets/image/lobby_obj_elevator_door.png", interactiveSprite = true,
                      interactText = "中间电梯的门缝里映着大堂灯光，暂时没有停靠提示。" },
                    { id = "lobby_trash_lower", name = "垃圾桶", x = 0.69, y = 0.52, w = 0.12, h = 0.24,
                      sprite = "assets/image/lobby_obj_trash_bin.png", interactiveSprite = true,
                      interactText = "另一只垃圾桶靠在电梯厅墙边，外壳上有清洁记录贴纸。" },
                    { id = "lobby_elevator_lower", name = "右侧电梯", x = 0.80, y = 0.20, w = 0.18, h = 0.60,
                      sprite = "assets/image/lobby_obj_elevator_door.png", interactiveSprite = true,
                      interactText = "右侧电梯直通酒店各楼层，门旁的呼叫按钮亮着。" },
                },
                exits = {
                    { id = "to_corridor", label = "电梯→25F", targetScene = "hotel_corridor", x = 0.18, y = 0.80, w = 0.16, h = 0.12 },
                },
            },
            {
                id = "s5", title = "安全通道",
                image = "assets/image/lobby_scroll_05_clean.png",
                bgColor = { 120, 105, 70, 255 },
                left = "s4", right = nil,
                items = {
                    { id = "lobby_safety_door", name = "安全通道", x = 0.60, y = 0.24, w = 0.26, h = 0.56,
                      sprite = "assets/image/lobby_obj_safety_door.png", interactiveSprite = true,
                      interactText = "安全通道门通向楼梯间，门上方的绿色出口灯持续亮着。" },
                },
                exits = {
                    { id = "to_corridor_stairs", label = "安全通道→25F", targetScene = "hotel_corridor", x = 0.62, y = 0.80, w = 0.20, h = 0.12 },
                },
            },
        },
    },

    -- ===== 第二段：1F 露天庭院连廊与茶歇区 · 整图切换（线性3屏）=====
    hotel_courtyard = {
        title = "露天庭院连廊与茶歇区",
        mode = "screens",
        minimap = {
            nodes = {
                { id = "s1", label = "入口", nx = 0.15, ny = 0.50 },
                { id = "s2", label = "茶歇", nx = 0.50, ny = 0.35 },
                { id = "s3", label = "喷泉", nx = 0.85, ny = 0.55 },
            },
            edges = { { "s1", "s2" }, { "s2", "s3" } },
            start = "s1",
        },
        screens = {
            {
                id = "s1", title = "推拉门入口",
                image = "assets/image/chapter1_courtyard_screen1_clean.png",
                bgColor = { 90, 130, 110, 255 },
                charPos = { x = 0.50, y = 0.78, scale = 0.58 },
                left = nil, right = "s2",
                items = {
                    { id = "plant", name = "罗马柱与盆栽", x = 0.08, y = 0.12, w = 0.22, h = 0.46,
                      sprite = "assets/image/chapter1_obj_courtyard_plant.png", interactiveSprite = true,
                      clueId = "court_plant", interactText = "茂密盆栽形成视线死角，有人曾压低声音打电话。" },
                    { id = "npc_zhaoheng", name = "赵恒", x = 0.44, y = 0.38, w = 0.19, h = 0.42,
                      sprite = "assets/image/char_zhaoheng.png",
                      onInteract = "ask_ch1_zhaoheng", interactText = "赵恒站在连廊下，西装后背洇出一片汗渍。" },
                },
                exits = {
                    { id = "to_lobby", label = "回到大堂", targetScene = "hotel_lobby", x = 0.08, y = 0.62, w = 0.14, h = 0.22 },
                },
            },
            {
                id = "s2", title = "茶歇长桌与盲区",
                image = "assets/image/chapter1_courtyard_screen2_clean.png",
                bgColor = { 100, 140, 115, 255 },
                charPos = { x = 0.30, y = 0.78, scale = 0.58 },
                left = "s1", right = "s3",
                items = {
                    { id = "table", name = "茶歇长桌", x = 0.10, y = 0.56, w = 0.30, h = 0.22,
                      sprite = "assets/image/chapter1_obj_tea_table.png", interactiveSprite = true,
                      clueId = "court_table", interactText = "甜点几乎没动，黑咖啡壶已空一半。" },
                    { id = "wifi", name = "Wi-Fi 8 路由", x = 0.46, y = 0.08, w = 0.16, h = 0.14,
                      sprite = "assets/image/chapter1_obj_wifi_router.png", interactiveSprite = true,
                      clueId = "court_wifi", interactText = "路由器指示灯规律闪烁，记录设备接入日志。" },
                    { id = "power", name = "公共电源桩", x = 0.70, y = 0.58, w = 0.16, h = 0.20,
                      sprite = "assets/image/chapter1_obj_power_pedestal.png", interactiveSprite = true,
                      clueId = "court_power", interactText = "电源桩插座处有轻微焦痕。" },
                    { id = "npc_xuqinglan", name = "许晴岚", x = 0.28, y = 0.16, w = 0.19, h = 0.40,
                      sprite = "assets/image/char_xuqinglan.png",
                      onInteract = "ask_ch1_xuqinglan", interactText = "许晴岚端着咖啡斜倚在茶歇桌旁。" },
                    { id = "npc_zhouwen", name = "周文", x = 0.65, y = 0.18, w = 0.18, h = 0.40,
                      sprite = "assets/image/char_zhouwen.png",
                      onInteract = "ask_ch1_zhouwen", interactText = "周文蹲在电源桩旁调试设备，满头是汗。" },
                },
            },
            {
                id = "s3", title = "喷泉与海景护栏",
                image = "assets/image/chapter1_courtyard_screen3_clean.png",
                bgColor = { 80, 120, 125, 255 },
                charPos = { x = 0.50, y = 0.78, scale = 0.58 },
                left = "s2", right = nil,
                items = {
                    { id = "fountain_ctrl", name = "音乐喷泉中控箱", x = 0.10, y = 0.24, w = 0.18, h = 0.18,
                      sprite = "assets/image/chapter1_obj_fountain_control.png", interactiveSprite = true,
                      clueId = "court_fountain", interactText = "电子时钟走得很准，整点准时报时。" },
                    { id = "npc_yanchengfeng", name = "严成峰", x = 0.38, y = 0.34, w = 0.19, h = 0.44,
                      sprite = "assets/image/char_yanchengfeng.png",
                      onInteract = "ask_ch1_yanchengfeng", interactText = "严成峰负手立于喷泉边，西装扣得一丝不苟。" },
                    { id = "npc_yanchengfeng_leave", name = "走向电梯的严成峰", x = 0.72, y = 0.34, w = 0.19, h = 0.44,
                      sprite = "assets/image/char_yanchengfeng.png",
                      dialogueId = "ch3_yanchengfeng_leave", interactText = "严成峰朝电梯厅方向走去，像是要回房歇息。" },
                },
            },
        },
    },

    -- ===== 第二段：25F VIP 客房走廊与电梯 · 整图切换（线性4屏）=====
    hotel_corridor = {
        title = "25F VIP客房走廊",
        mode = "screens",
        minimap = {
            nodes = {
                { id = "s1", label = "电梯厅", nx = 0.15, ny = 0.50 },
                { id = "s2", label = "2501",  nx = 0.42, ny = 0.40 },
                { id = "s3", label = "2502",  nx = 0.64, ny = 0.55 },
                { id = "s4", label = "2504",  nx = 0.86, ny = 0.45 },
            },
            edges = { { "s1", "s2" }, { "s2", "s3" }, { "s3", "s4" } },
            start = "s1",
        },
        screens = {
            {
                id = "s1", title = "VIP电梯厅",
                image = "assets/image/corridor_screen1.png",
                bgColor = { 60, 80, 120, 255 },
                charPos = { x = 0.50, y = 0.78, scale = 0.58 },
                left = nil, right = "s2",
                exits = {
                    { id = "to_lobby", label = "电梯→大堂", targetScene = "hotel_lobby", x = 0.06, y = 0.12, w = 0.16, h = 0.30 },
                },
            },
            {
                id = "s2", title = "2501 严成峰套房",
                image = "assets/image/chapter1_corridor_screen2_clean.png",
                bgColor = { 55, 75, 115, 255 },
                charPos = { x = 0.50, y = 0.78, scale = 0.58 },
                left = "s1", right = "s3",
                items = {
                    { id = "room2501", name = "2501房门", x = 0.20, y = 0.24, w = 0.30, h = 0.54,
                      sprite = "assets/image/chapter1_obj_room_door.png", interactiveSprite = true,
                      clueId = "room_2501", interactText = "2501房是严成峰的套房，门缝飘出淡淡药水味。", onInteract = "enter_crime" },
                    { id = "room2501_vent", name = "门缝下的声响", x = 0.04, y = 0.30, w = 0.14, h = 0.22,
                      dialogueId = "ch2_2501_eavesdrop", interactText = "门缝里传来严成峰吩咐周文去买哮喘吸入剂的低语。" },
                },
            },
            {
                id = "s3", title = "2502-2503 房门",
                image = "assets/image/chapter1_corridor_screen3_clean.png",
                bgColor = { 65, 85, 125, 255 },
                charPos = { x = 0.50, y = 0.78, scale = 0.58 },
                left = "s2", right = "s4",
                items = {
                    { id = "room2502", name = "2502房门", x = 0.18, y = 0.24, w = 0.28, h = 0.54,
                      sprite = "assets/image/chapter1_obj_room_door.png", interactiveSprite = true,
                      clueId = "room_2502", interactText = "2502房房门紧闭，门牌显示这是赵恒的房间。" },
                },
            },
            {
                id = "s4", title = "2504-2505 与观景沙发",
                image = "assets/image/chapter1_corridor_screen4_clean.png",
                bgColor = { 70, 90, 130, 255 },
                charPos = { x = 0.50, y = 0.78, scale = 0.58 },
                left = "s3", right = nil,
                items = {
                    { id = "room2504", name = "2504房门", x = 0.12, y = 0.24, w = 0.26, h = 0.54,
                      sprite = "assets/image/chapter1_obj_room_door.png", interactiveSprite = true,
                      clueId = "room_2504", interactText = "2504房是李志和陈雯音的房间。" },
                    { id = "room2505", name = "2505房门", x = 0.45, y = 0.24, w = 0.26, h = 0.54,
                      sprite = "assets/image/chapter1_obj_room_door.png", interactiveSprite = true,
                      clueId = "room_2505", interactText = "2505房是许晴岚的房间，就在李志隔壁。" },
                },
            },
        },
    },

    -- ===== 第二段：案发现场（2501房） · 整图切换（线性3屏）=====
    crime_scene = {
        title = "2501房 · 案发现场",
        mode = "screens",
        minimap = {
            nodes = {
                { id = "s1", label = "门廊", nx = 0.18, ny = 0.50 },
                { id = "s2", label = "床头", nx = 0.50, ny = 0.40 },
                { id = "s3", label = "大床", nx = 0.82, ny = 0.55 },
            },
            edges = { { "s1", "s2" }, { "s2", "s3" } },
            start = "s1",
        },
        screens = {
            {
                id = "s1", title = "门廊入口",
                image = "assets/image/chapter1_crime_screen1_clean.png",
                bgColor = { 45, 60, 95, 255 },
                charPos = { x = 0.55, y = 0.78, scale = 0.58 },
                left = nil, right = "s2",
                items = {
                    { id = "thermostat", name = "智能温控面板", x = 0.10, y = 0.24, w = 0.16, h = 0.16,
                      sprite = "assets/image/chapter1_obj_thermostat.png", interactiveSprite = true,
                      clueId = "smart_device", interactText = "温控系统显示凌晨3点温度被骤降至16度。" },
                },
                exits = {
                    { id = "to_corridor", label = "离开房间", targetScene = "hotel_corridor", x = 0.05, y = 0.60, w = 0.14, h = 0.34 },
                },
            },
            {
                id = "s2", title = "床头与衣柜",
                image = "assets/image/chapter1_crime_screen2_clean.png",
                bgColor = { 50, 65, 100, 255 },
                charPos = { x = 0.50, y = 0.78, scale = 0.58 },
                left = "s1", right = "s3",
                items = {
                    { id = "nightstand", name = "床头柜", x = 0.12, y = 0.56, w = 0.18, h = 0.22,
                      sprite = "assets/image/chapter1_obj_nightstand.png", interactiveSprite = true,
                      clueId = "inhaler", interactText = "床头柜上空空如也。严成峰有重度哮喘，吸入器本应不离身。" },
                },
            },
            {
                id = "s3", title = "大床与坠落点",
                image = "assets/image/chapter1_crime_screen3_clean.png",
                bgColor = { 40, 55, 90, 255 },
                charPos = { x = 0.30, y = 0.78, scale = 0.58 },
                left = "s2", right = nil,
                items = {
                    { id = "body", name = "尸体位置", x = 0.40, y = 0.58, w = 0.24, h = 0.20,
                      sprite = "assets/image/chapter1_obj_body_position.png", interactiveSprite = true,
                      clueId = "body_position", interactText = "严成峰面部朝下倒在地板，身体无明显外伤。" },
                    { id = "deduce", name = "整理线索 · 进行推理", x = 0.70, y = 0.28, w = 0.24, h = 0.18,
                      onInteract = "deduce" },
                },
            },
        },
    },

    -- ======================================================================
    -- 第四阶段：调查推理（侦察 → 搜证 → 推理 → 结案）
    -- 说明：背景图复用既有资源；线索图为本阶段新生成（assets/image/clue_*.png）
    -- ======================================================================

    -- ===== 2501 房间（案发现场·侦察与搜证主场地）=====
    c4_2501 = {
        title = "2501房 · 案发现场",
        mode = "screens",
        minimap = {
            nodes = {
                { id = "s1", label = "门廊", nx = 0.16, ny = 0.50 },
                { id = "s2", label = "床头", nx = 0.50, ny = 0.38 },
                { id = "s3", label = "电视", nx = 0.84, ny = 0.56 },
            },
            edges = { { "s1", "s2" }, { "s2", "s3" } },
            start = "s1",
        },
        screens = {
            {
                id = "s1", title = "门廊与遗体",
                image = "assets/image/crime_scene_screen1.png",
                bgColor = { 45, 60, 95, 255 },
                charPos = { x = 0.50, y = 0.78, scale = 0.58 },
                left = nil, right = "s2",
                items = {
                    { id = "npc_police_a", name = "警察A", x = 0.04, y = 0.24, w = 0.18, h = 0.36,
                      sprite = "assets/image/char_police.png",
                      interactText = "门口执勤的警察，一直守在这里。", onInteract = "ask_police_a" },
                    { id = "c4_body", name = "严成峰遗体", x = 0.28, y = 0.54, w = 0.26, h = 0.24,
                      clueId = "c4_body", interactText = "衣物凌乱，脖子上有轻微抓痕，体表没有开放性伤口。" },
                    { id = "c4_room_mess", name = "凌乱的房间", x = 0.60, y = 0.28, w = 0.20, h = 0.32,
                      clueId = "c4_room_mess", interactText = "茶几桌椅全部翻倒，地毯掀起一角，床头柜有明显翻找痕迹。" },
                    { id = "npc_zhang", name = "张承宇", x = 0.81, y = 0.24, w = 0.18, h = 0.36,
                      sprite = "assets/image/char_zhangchengyu.png",
                      interactText = "张承宇正等着你的调查结果。", onInteract = "c4_report" },
                },
                exits = {
                    { id = "to_lobby", label = "电梯→1L大堂", targetScene = "c4_lobby", x = 0.02, y = 0.64, w = 0.14, h = 0.26 },
                    { id = "to_hall", label = "电梯→1L大厅", targetScene = "c4_hall", x = 0.85, y = 0.62, w = 0.14, h = 0.28 },
                },
            },
            {
                id = "s2", title = "床头与药瓶",
                image = "assets/image/crime_scene_screen2.png",
                bgColor = { 50, 65, 100, 255 },
                charPos = { x = 0.50, y = 0.78, scale = 0.58 },
                left = "s1", right = "s3",
                items = {
                    { id = "c4_empty_inhaler", name = "空掉的气体药瓶", x = 0.08, y = 0.58, w = 0.18, h = 0.22,
                      clueId = "c4_empty_inhaler", interactText = "一支用尽的哮喘气体吸入剂，底部有几道轻微划痕。" },
                    { id = "c4_capsule", name = "掉在地上的药瓶", x = 0.38, y = 0.62, w = 0.16, h = 0.18,
                      clueId = "c4_capsule", interactText = "一瓶进口辅酶复合胶囊，治疗哮喘的应急药物，瓶盖已经拧开。" },
                    { id = "npc_forensic", name = "法医宋医生", x = 0.65, y = 0.24, w = 0.19, h = 0.44,
                      sprite = "assets/image/char_doctor.png",
                      interactText = "宋医生正在收拾现场取样工具。", onInteract = "ask_forensic" },
                },
            },
            {
                id = "s3", title = "电视与音响",
                image = "assets/image/crime_scene_screen3.png",
                bgColor = { 40, 55, 90, 255 },
                charPos = { x = 0.30, y = 0.78, scale = 0.58 },
                left = "s2", right = nil,
                items = {
                    { id = "c4_phone", name = "严成峰的手机", x = 0.10, y = 0.58, w = 0.16, h = 0.20,
                      clueId = "c4_phone", interactText = "手机屏幕碎成蛛网状，机身有明显砸击凹痕，数据损坏严重。" },
                    { id = "c4_vent", name = "嵌入式空调出风口", x = 0.38, y = 0.08, w = 0.18, h = 0.18,
                      clueId = "c4_vent", interactText = "出风口格栅上积着一层薄薄的白色粉末，看着像是墙灰。" },
                    { id = "c4_speaker", name = "电视旁的音响", x = 0.64, y = 0.36, w = 0.16, h = 0.24,
                      interactText = "一台普通的客房音响，摆在电视柜旁边。", onInteract = "c4_speaker" },
                    { id = "npc_waiter_a", name = "服务员A", x = 0.06, y = 0.16, w = 0.18, h = 0.40,
                      sprite = "assets/image/char_waiter.png",
                      interactText = "第一目击者，还惊魂未定地站在角落。", onInteract = "ask_waiter_a" },
                    { id = "c4_deduce", name = "整理线索 · 进行推理", x = 0.56, y = 0.70, w = 0.28, h = 0.16,
                      interactText = "把目前掌握的线索全部串起来。", onInteract = "c4_deduce" },
                },
            },
        },
    },

    -- ===== 1L 大堂（外卖柜 / 垃圾桶 / 安全通道）=====
    c4_lobby = {
        title = "1L 大堂",
        mode = "screens",
        minimap = {
            nodes = {
                { id = "s1", label = "外卖柜", nx = 0.18, ny = 0.45 },
                { id = "s2", label = "垃圾桶", nx = 0.50, ny = 0.38 },
                { id = "s3", label = "人员", nx = 0.82, ny = 0.55 },
            },
            edges = { { "s1", "s2" }, { "s2", "s3" } },
            start = "s1",
        },
        screens = {
            {
                id = "s1", title = "外卖存放箱",
                image = "assets/image/lobby_screen2.png",
                bgColor = { 140, 115, 65, 255 },
                charPos = { x = 0.50, y = 0.78, scale = 0.58 },
                left = nil, right = "s2",
                items = {
                    { id = "c4_delivery", name = "外卖存放箱", x = 0.10, y = 0.30, w = 0.24, h = 0.48,
                      clueId = "c4_delivery", interactText = "一份印着磐安智能字样的同城送药订单，登记抵达时间是18:00。" },
                },
                exits = {
                    { id = "to_2501", label = "电梯→25F", targetScene = "c4_2501", x = 0.70, y = 0.20, w = 0.17, h = 0.34 },
                    { id = "to_hall", label = "前往大厅", targetScene = "c4_hall", x = 0.88, y = 0.58, w = 0.12, h = 0.28 },
                },
            },
            {
                id = "s2", title = "垃圾桶与安全通道",
                image = "assets/image/lobby_screen3.png",
                bgColor = { 150, 125, 72, 255 },
                charPos = { x = 0.50, y = 0.78, scale = 0.58 },
                left = "s1", right = "s3",
                items = {
                    { id = "c4_trash", name = "垃圾桶", x = 0.10, y = 0.50, w = 0.20, h = 0.32,
                      clueId = "c4_trash", interactText = "桶里塞满擦汗的高级湿纸巾，烟灰缸里堆着几截掐灭的尼龙牌香烟。" },
                    { id = "c4_stairwell", name = "安全通道", x = 0.44, y = 0.16, w = 0.26, h = 0.56,
                      clueId = "c4_stairwell", interactText = "可直达所有楼层，门把手上残留着不易察觉的汗渍手印。" },
                },
            },
            {
                id = "s3", title = "大堂人员",
                image = "assets/image/lobby_screen4.png",
                bgColor = { 120, 100, 60, 255 },
                charPos = { x = 0.30, y = 0.78, scale = 0.58 },
                left = "s2", right = nil,
                items = {
                    { id = "npc_zhouwen", name = "周文", x = 0.08, y = 0.24, w = 0.19, h = 0.44,
                      sprite = "assets/image/char_zhouwen.png",
                      interactText = "周文抱着文件夹，正准备回房。", onInteract = "ask_zhouwen" },
                    { id = "npc_frontdesk", name = "前台接待", x = 0.40, y = 0.24, w = 0.19, h = 0.44,
                      sprite = "assets/image/char_receptionist.png",
                      interactText = "前台小姐仍在值守。", onInteract = "ask_frontdesk" },
                    { id = "npc_guard", name = "庭院入口保安", x = 0.70, y = 0.24, w = 0.19, h = 0.44,
                      sprite = "assets/image/char_guard.png",
                      interactText = "保安笔直地站在庭院入口。", onInteract = "ask_guard" },
                },
            },
        },
    },

    -- ===== 1L 大厅 / 庭院（席位桌 / 议程看板 / 长桌）=====
    c4_hall = {
        title = "1L 大厅与庭院",
        mode = "screens",
        minimap = {
            nodes = {
                { id = "s1", label = "席位", nx = 0.18, ny = 0.45 },
                { id = "s2", label = "长桌", nx = 0.50, ny = 0.38 },
                { id = "s3", label = "庭院", nx = 0.82, ny = 0.55 },
            },
            edges = { { "s1", "s2" }, { "s2", "s3" } },
            start = "s1",
        },
        screens = {
            {
                id = "s1", title = "磐安席位与议程看板",
                image = "assets/image/courtyard_screen2.png",
                bgColor = { 100, 140, 115, 255 },
                charPos = { x = 0.50, y = 0.78, scale = 0.58 },
                left = nil, right = "s2",
                items = {
                    { id = "c4_seat_table", name = "磐安智能席位桌", x = 0.08, y = 0.52, w = 0.28, h = 0.26,
                      clueId = "c4_seat_table", interactText = "桌上摆着半盒尼龙牌香烟，桌牌显示这是赵恒与严城峰的专座。" },
                    { id = "c4_agenda", name = "峰会议程电子看板", x = 0.50, y = 0.14, w = 0.24, h = 0.46,
                      clueId = "c4_agenda", interactText = "15:00 峰会开幕主持人致辞，15:10 自由交流环节。" },
                },
                exits = {
                    { id = "to_2501", label = "电梯→25F", targetScene = "c4_2501", x = 0.84, y = 0.18, w = 0.15, h = 0.32 },
                    { id = "to_lobby", label = "返回大堂", targetScene = "c4_lobby", x = 0.02, y = 0.62, w = 0.13, h = 0.26 },
                },
            },
            {
                id = "s2", title = "庭院右侧长桌",
                image = "assets/image/courtyard_screen1.png",
                bgColor = { 90, 130, 110, 255 },
                charPos = { x = 0.30, y = 0.78, scale = 0.58 },
                left = "s1", right = "s3",
                items = {
                    { id = "c4_zhouwen_desk", name = "庭院右侧长桌", x = 0.12, y = 0.46, w = 0.36, h = 0.32,
                      clueId = "c4_zhouwen_desk", interactText = "长桌上摆着一台设了密码的电脑，用户名是周文；旁边是一年半前的磐安技术期刊。" },
                },
            },
            {
                id = "s3", title = "庭院人员",
                image = "assets/image/courtyard_screen3.png",
                bgColor = { 80, 120, 125, 255 },
                charPos = { x = 0.50, y = 0.78, scale = 0.58 },
                left = "s2", right = nil,
                items = {
                    { id = "npc_xuqinglan", name = "许晴岚", x = 0.14, y = 0.24, w = 0.19, h = 0.44,
                      sprite = "assets/image/char_xuqinglan.png",
                      interactText = "许晴岚正在安抚其他公司的人。", onInteract = "ask_xuqinglan" },
                    { id = "npc_zhaoheng", name = "赵恒", x = 0.58, y = 0.24, w = 0.19, h = 0.44,
                      sprite = "assets/image/char_zhaoheng.png",
                      interactText = "赵恒一个人靠在护栏边，神色慌张。", onInteract = "ask_zhaoheng" },
                },
            },
        },
    },
}

-- ============================================================================
-- 辅助函数
-- ============================================================================

function M.GetCharacter(id)
    return M.Characters[id]
end

function M.GetClue(id)
    return M.Clues[id]
end

function M.GetSceneData(sceneId)
    return M.SceneObjects[sceneId]
end

function M.GetDialogue(id)
    return M.Dialogues[id]
end

function M.GetOpening(id)
    return M.Openings[id]
end

-- 检查是否已收集线索
function M.HasClue(clueId)
    for _, id in ipairs(M.GameState.collectedClues) do
        if id == clueId then return true end
    end
    return false
end

-- 收集线索（解锁，标记为未读）
function M.CollectClue(clueId)
    if not M.Clues[clueId] then return false end
    if not M.HasClue(clueId) then
        table.insert(M.GameState.collectedClues, clueId)
        M.GameState.readClues[clueId] = false  -- 新收录，未读
        return true  -- 新收集
    end
    return false  -- 已有
end

-- 标记线索已读
function M.MarkClueRead(clueId)
    if M.HasClue(clueId) then
        M.GameState.readClues[clueId] = true
    end
end

-- 切换线索标记⭐
function M.ToggleClueStarred(clueId)
    if M.GameState.starredClues[clueId] then
        M.GameState.starredClues[clueId] = nil
        return false
    else
        M.GameState.starredClues[clueId] = true
        return true
    end
end

-- 设置游戏标志
function M.SetFlag(key, value)
    M.GameState.flags[key] = value
end

-- 获取游戏标志
function M.GetFlag(key)
    return M.GameState.flags[key]
end

-- 格式化游玩时间
function M.FormatPlayTime(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d:%02d", h, m, s)
end

-- 重置游戏状态
function M.ResetGameState()
    M.GameState = {
        currentChapter = "prologue",
        currentScene = "office",
        playTime = 0,
        collectedClues = {},
        readClues = {},
        starredClues = {},
        flags = {},
    }
end

-- ============================================================================
-- ============================================================================
-- CSV 文本覆盖（策划可编辑 assets/data/dialogues.csv / clues.csv）
-- 运行时优先加载由 CSV 自动生成的 Lua 模块（scripts/data_*.lua，必被 Maker 打包），
-- 其次尝试直接读取 CSV 文件（兼容未来 Maker 支持 assets/data/*.csv），
-- 最后保留上方内嵌兜底数据，游戏不会崩。
-- ⚠️ 编辑 CSV 后必须重新生成 Lua 模块：node tools/csv_to_lua.js
-- ============================================================================
local luaDlgOk, dlgMod = pcall(require, "scripts.data_dialogues")
local luaClueOk, clueMod = pcall(require, "scripts.data_clues")
if luaDlgOk and dlgMod then M.Dialogues = dlgMod end
if luaClueOk and clueMod then M.Clues = clueMod end
if (luaDlgOk and dlgMod) or (luaClueOk and clueMod) then
    local parts = {}
    if luaDlgOk and dlgMod then parts[#parts + 1] = "对话" end
    if luaClueOk and clueMod then parts[#parts + 1] = "线索" end
    print("[GameData] 文本已从 Lua 模块加载（" .. table.concat(parts, "/") .. "），源: assets/data/*.csv")
else
    local ok, CSVLoader = pcall(require, "scripts.CSVLoader")
    if ok and CSVLoader then
        local csv = CSVLoader.LoadAll()
        if csv.dialogues then M.Dialogues = csv.dialogues end
        if csv.clues then M.Clues = csv.clues end
        if csv.dlgPath then print("[GameData] 对话文本已从 CSV 加载: " .. csv.dlgPath) end
        if csv.cluePath then print("[GameData] 线索文本已从 CSV 加载: " .. csv.cluePath) end
        if not csv.dlgPath and not csv.cluePath then
            print("[GameData] 未找到 CSV（assets/data/*.csv），使用内嵌文本兜底。")
        end
    else
        print("[GameData] 未能加载 CSVLoader，使用内嵌文本兜底。")
    end
end

return M
