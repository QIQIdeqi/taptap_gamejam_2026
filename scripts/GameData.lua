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
    },
    inhaler = {
        id = "inhaler",
        name = "哮喘吸入器",
        category = "evidence",
        chapter = "chapter1",
        description = "死者身边的哮喘吸入器不见了，这可能是关键。",
        detail = "严成峰有重度哮喘，吸入器本应不离身，此刻却不在手边。",
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
        background = "assets/image/bg_office.png",
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
        background = "assets/image/bg_office.png",
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
        background = "assets/image/bg_office.png",
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
        background = "assets/image/bg_office.png",
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
        background = "assets/image/bg_office.png",
        lines = {
            { speaker = "", text = "切换到事务所卧室，李志正对着衣柜翻找着什么。" },
            { speaker = "LiZhi", text = "雯雯，有看到我的袜子吗？" },
        },
    },
    opening_prologue_5_after = {
        id = "opening_prologue_5_after",
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
        background = "assets/image/bg_hotel_room.png",
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
-- 场景物件数据
-- x/y/w/h 为相对比例坐标（0~1）
-- ============================================================================
M.SceneObjects = {
    -- ===== 第一段：事务所（新手引导）· 侧视横版 =====
    -- 坐标说明：x/w 为「世界像素」（横向滚动用绝对像素），y/h 为「屏幕高比例」（自适应）
    office = {
        title = "黄昏事务所",
        mode = "screens",
        minimap = {
            nodes = {
                { id = "s1", label = "书柜", nx = 0.20, ny = 0.55 },
                { id = "s2", label = "办公桌", nx = 0.50, ny = 0.40 },
                { id = "s3", label = "衣柜", nx = 0.80, ny = 0.55 },
            },
            edges = { { "s1", "s2" }, { "s2", "s3" } },
            start = "s2",
        },
        screens = {
            {
                id = "s1", title = "书柜区",
                image = "assets/image/office_screen1.png",
                bgColor = { 150, 120, 70, 255 },
                charPos = { x = 0.30, y = 0.78, scale = 0.60 },
                left = nil, right = "s2",
                items = {
                    { id = "bookshelf", name = "书柜", x = 0.10, y = 0.18, w = 0.30, h = 0.60,
                      clueId = "bookshelf", interactText = "书柜里摆满了侦探小说，大多都是一名叫'秋白'的作者写的。" },
                },
            },
            {
                id = "s2", title = "办公桌区",
                image = "assets/image/office_screen2.png",
                bgColor = { 145, 115, 68, 255 },
                charPos = { x = 0.45, y = 0.78, scale = 0.60 },
                left = "s1", right = "s3",
                items = {
                    { id = "desk", name = "办公桌", x = 0.40, y = 0.50, w = 0.30, h = 0.30,
                      clueId = "desk", interactText = "桌上散落着未结案的委托档案和空泡面杯。" },
                    { id = "lamp", name = "台灯", x = 0.74, y = 0.44, w = 0.10, h = 0.24,
                      interactText = "暖黄灯光是这间事务所唯一的温度。" },
                },
            },
            {
                id = "s3", title = "衣柜与地铺区",
                image = "assets/image/office_screen3.png",
                bgColor = { 130, 105, 62, 255 },
                charPos = { x = 0.50, y = 0.78, scale = 0.60 },
                left = "s2", right = nil,
                items = {
                    { id = "wardrobe", name = "衣柜", x = 0.58, y = 0.20, w = 0.30, h = 0.58,
                      clueId = "wardrobe", interactText = "衣柜里堆满了深色的衣服，衣服堆下面似乎埋着李志的袜子。", onInteract = "wardrobe" },
                    { id = "bed", name = "床铺", x = 0.10, y = 0.62, w = 0.30, h = 0.28,
                      clueId = "bed", interactText = "这段时间都由陈雯音睡在这张床上。" },
                },
            },
        },
    },

    -- ===== 第二段：1F 酒店大堂与前台区 · 整图切换（环形4屏）=====
    hotel_lobby = {
        title = "酒店大堂与前台区",
        mode = "screens",
        minimap = {
            nodes = {
                { id = "s1", label = "旋转门", nx = 0.18, ny = 0.55 },
                { id = "s2", label = "外卖柜", nx = 0.42, ny = 0.35 },
                { id = "s3", label = "前台",   nx = 0.66, ny = 0.55 },
                { id = "s4", label = "闸机",   nx = 0.86, ny = 0.72 },
            },
            edges = { { "s1", "s2" }, { "s2", "s3" }, { "s3", "s4" }, { "s4", "s1" } },
            start = "s1",
        },
        screens = {
            {
                id = "s1", title = "旋转门入口",
                image = "assets/image/lobby_screen1.png",
                bgColor = { 150, 120, 70, 255 },
                charPos = { x = 0.62, y = 0.78, scale = 0.60 },
                left = nil, right = "s2",
                items = {
                    { id = "umbrella", name = "雨伞架", x = 0.10, y = 0.45, w = 0.10, h = 0.40,
                      interactText = "门前雨伞架里插着几把长伞。" },
                },
                exits = {
                    { id = "to_courtyard", label = "露天庭院", targetScene = "hotel_courtyard", x = 0.04, y = 0.30, w = 0.14, h = 0.45 },
                },
            },
            {
                id = "s2", title = "外卖柜与假山",
                image = "assets/image/lobby_screen2.png",
                bgColor = { 140, 115, 65, 255 },
                charPos = { x = 0.50, y = 0.78, scale = 0.58 },
                left = "s1", right = "s3",
                items = {
                    { id = "delivery", name = "外卖暂存柜", x = 0.06, y = 0.32, w = 0.18, h = 0.46,
                      clueId = "lobby_delivery", interactText = "蜂巢式恒温配送柜，扫码屏残留取件记录。" },
                    { id = "fountain", name = "室内流水假山", x = 0.44, y = 0.28, w = 0.30, h = 0.50,
                      clueId = "lobby_fountain", interactText = "太湖石循环水景，水声足以掩盖低声交谈。" },
                },
            },
            {
                id = "s3", title = "展架与前台",
                image = "assets/image/lobby_screen3.png",
                bgColor = { 160, 130, 75, 255 },
                charPos = { x = 0.60, y = 0.78, scale = 0.58 },
                left = "s2", right = "s4",
                items = {
                    { id = "stand", name = "峰会展架", x = 0.06, y = 0.30, w = 0.20, h = 0.48,
                      clueId = "lobby_stand", interactText = "磐安智能峰会特制展架。" },
                    { id = "signbook", name = "VIP签到簿", x = 0.56, y = 0.46, w = 0.30, h = 0.32,
                      clueId = "lobby_signbook", interactText = "前台礼貌表示无法查看。" },
                },
            },
            {
                id = "s4", title = "安检闸机",
                image = "assets/image/lobby_screen4.png",
                bgColor = { 120, 100, 60, 255 },
                charPos = { x = 0.50, y = 0.78, scale = 0.58 },
                left = "s3", right = "s1",
                items = {},
                exits = {
                    { id = "to_corridor", label = "电梯→25F", targetScene = "hotel_corridor", x = 0.10, y = 0.30, w = 0.16, h = 0.45 },
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
                image = "assets/image/courtyard_screen1.png",
                bgColor = { 90, 130, 110, 255 },
                charPos = { x = 0.50, y = 0.78, scale = 0.58 },
                left = nil, right = "s2",
                items = {
                    { id = "plant", name = "罗马柱与盆栽", x = 0.08, y = 0.20, w = 0.22, h = 0.58,
                      clueId = "court_plant", interactText = "茂密盆栽形成视线死角，有人曾压低声音打电话。" },
                },
                exits = {
                    { id = "to_lobby", label = "回到大堂", targetScene = "hotel_lobby", x = 0.04, y = 0.30, w = 0.14, h = 0.45 },
                },
            },
            {
                id = "s2", title = "茶歇长桌与盲区",
                image = "assets/image/courtyard_screen2.png",
                bgColor = { 100, 140, 115, 255 },
                charPos = { x = 0.30, y = 0.78, scale = 0.58 },
                left = "s1", right = "s3",
                items = {
                    { id = "table", name = "茶歇长桌", x = 0.10, y = 0.56, w = 0.30, h = 0.22,
                      clueId = "court_table", interactText = "甜点几乎没动，黑咖啡壶已空一半。" },
                    { id = "wifi", name = "Wi-Fi 8 路由", x = 0.46, y = 0.08, w = 0.16, h = 0.14,
                      clueId = "court_wifi", interactText = "路由器指示灯规律闪烁，记录设备接入日志。" },
                    { id = "power", name = "公共电源桩", x = 0.70, y = 0.58, w = 0.16, h = 0.20,
                      clueId = "court_power", interactText = "电源桩插座处有轻微焦痕。" },
                },
            },
            {
                id = "s3", title = "喷泉与海景护栏",
                image = "assets/image/courtyard_screen3.png",
                bgColor = { 80, 120, 125, 255 },
                charPos = { x = 0.50, y = 0.78, scale = 0.58 },
                left = "s2", right = nil,
                items = {
                    { id = "fountain_ctrl", name = "音乐喷泉中控箱", x = 0.10, y = 0.24, w = 0.18, h = 0.18,
                      clueId = "court_fountain", interactText = "电子时钟走得很准，整点准时报时。" },
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
                    { id = "to_lobby", label = "电梯→大堂", targetScene = "hotel_lobby", x = 0.06, y = 0.30, w = 0.16, h = 0.45 },
                },
            },
            {
                id = "s2", title = "2501 严成峰套房",
                image = "assets/image/corridor_screen2.png",
                bgColor = { 55, 75, 115, 255 },
                charPos = { x = 0.50, y = 0.78, scale = 0.58 },
                left = "s1", right = "s3",
                items = {
                    { id = "room2501", name = "2501房门", x = 0.20, y = 0.24, w = 0.30, h = 0.54,
                      clueId = "room_2501", interactText = "2501房是严成峰的套房，门缝飘出淡淡药水味。", onInteract = "enter_crime" },
                },
            },
            {
                id = "s3", title = "2502-2503 房门",
                image = "assets/image/corridor_screen3.png",
                bgColor = { 65, 85, 125, 255 },
                charPos = { x = 0.50, y = 0.78, scale = 0.58 },
                left = "s2", right = "s4",
                items = {
                    { id = "room2502", name = "2502房门", x = 0.18, y = 0.24, w = 0.28, h = 0.54,
                      clueId = "room_2502", interactText = "2502房房门紧闭，门牌显示这是赵恒的房间。" },
                },
            },
            {
                id = "s4", title = "2504-2505 与观景沙发",
                image = "assets/image/corridor_screen4.png",
                bgColor = { 70, 90, 130, 255 },
                charPos = { x = 0.50, y = 0.78, scale = 0.58 },
                left = "s3", right = nil,
                items = {
                    { id = "room2504", name = "2504房门", x = 0.12, y = 0.24, w = 0.26, h = 0.54,
                      clueId = "room_2504", interactText = "2504房是李志和陈雯音的房间。" },
                    { id = "room2505", name = "2505房门", x = 0.45, y = 0.24, w = 0.26, h = 0.54,
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
                image = "assets/image/crime_scene_screen1.png",
                bgColor = { 45, 60, 95, 255 },
                charPos = { x = 0.55, y = 0.78, scale = 0.58 },
                left = nil, right = "s2",
                items = {
                    { id = "thermostat", name = "智能温控面板", x = 0.10, y = 0.24, w = 0.16, h = 0.16,
                      clueId = "smart_device", interactText = "温控系统显示凌晨3点温度被骤降至16度。" },
                },
                exits = {
                    { id = "to_corridor", label = "离开房间", targetScene = "hotel_corridor", x = 0.05, y = 0.30, w = 0.14, h = 0.45 },
                },
            },
            {
                id = "s2", title = "床头与衣柜",
                image = "assets/image/crime_scene_screen2.png",
                bgColor = { 50, 65, 100, 255 },
                charPos = { x = 0.50, y = 0.78, scale = 0.58 },
                left = "s1", right = "s3",
                items = {
                    { id = "nightstand", name = "床头柜", x = 0.12, y = 0.56, w = 0.18, h = 0.22,
                      clueId = "inhaler", interactText = "床头柜上空空如也。严成峰有重度哮喘，吸入器本应不离身。" },
                },
            },
            {
                id = "s3", title = "大床与坠落点",
                image = "assets/image/crime_scene_screen3.png",
                bgColor = { 40, 55, 90, 255 },
                charPos = { x = 0.30, y = 0.78, scale = 0.58 },
                left = "s2", right = nil,
                items = {
                    { id = "body", name = "尸体位置", x = 0.40, y = 0.58, w = 0.24, h = 0.20,
                      clueId = "body_position", interactText = "严成峰面部朝下倒在地板，身体无明显外伤。" },
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

return M
