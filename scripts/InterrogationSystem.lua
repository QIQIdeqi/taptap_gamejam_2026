-- ============================================================================
-- InterrogationSystem.lua - 询问与对证系统（第四阶段：调查推理）
-- ============================================================================
-- 两套玩法：
--   1) 询问（侦察阶段）：首次剧情对话 → 询问选项列表 → 选中播回答 → 循环
--   2) 对证（搜证阶段）：提问+回答 → 弹出证据选项 A/B/C → 选中正确项才推进
-- 台词全部存放于 assets/data/dialogues.csv，本文件只维护"结构"。
-- ============================================================================

local UI = require("urhox-libs.UI")

local M = {}

M.active = false
M._overlay = nil
M._panel = nil

-- 引擎会周期性重复派发 onClick，必须做时间防抖（不可用 os.clock()，它是 CPU 时间）
local _lastClickTime = -99
local function _now()
    local ok, SM = pcall(require, "scripts.SceneManager")
    if ok and SM then return SM._gameTime or 0 end
    return 0
end
local function _debounce()
    local now = _now()
    if now - _lastClickTime < 0.6 then return false end
    _lastClickTime = now
    return true
end

-- ============================================================================
-- 询问配置（侦察阶段 NPC）
-- requireTopic: 需要先问过某个 topic 才解锁
-- clue:         回答播完后收录的线索
-- ============================================================================
M.Interrogations = {
    -- ===== 2501 房间 =====
    police_a = {
        name = "警察A",
        first = "c4i_police_first",
        topics = {
            { id = "q1", text = "有查看外面走廊的监控么？", answer = "c4i_police_q1", clue = "c4_tes_monitor" },
            { id = "q2", text = "你一直在这站岗，期间还有其他人来过么？", answer = "c4i_police_q2", clue = "c4_tes_zhouwen_file" },
            { id = "q3", text = "文件里有什么可疑内容么？", answer = "c4i_police_q3", requireTopic = "q2" },
        },
        ending = "c4i_police_end",
        repeatText = "抱歉，我得继续守在这里，没什么能再补充的了。",
    },
    forensic = {
        name = "法医宋医生",
        first = "c4i_forensic_first",
        topics = {
            { id = "q1", text = "现场留有什么其他痕迹么？", answer = "c4i_forensic_q1" },
            { id = "q2", text = "死者身上有什么其他伤痕么？", answer = "c4i_forensic_q2", clue = "c4_tes_forensic" },
            { id = "q3", text = "死者身上有什么吗？", answer = "c4i_forensic_q3" },
        },
        ending = "c4i_forensic_end",
        repeatText = "能说的我都说了，去问问门外那个服务员吧，他是第一目击人。",
    },
    waiter_a = {
        name = "服务员A",
        first = "c4i_waiter_first",
        topics = {
            { id = "q1", text = "你是怎么发现尸体的？", answer = "c4i_waiter_q1", clue = "c4_tes_waiter" },
            { id = "q2", text = "你在这个过程中有发现其他人么？", answer = "c4i_waiter_q2" },
        },
        ending = nil,
        repeatText = "我……我真的什么都不知道了。",
    },
    -- ===== 1L 大堂 =====
    zhouwen = {
        name = "周文",
        first = "c4i_zhouwen_first",
        topics = {
            { id = "q1", text = "你们公司的赵总和严总平时关系如何？", answer = "c4i_zhouwen_q1" },
            { id = "q2", text = "严城峰上楼的这个时间你去哪了？", answer = "c4i_zhouwen_q2" },
            { id = "q3", text = "在庭院期间有见到什么可疑的人么？", answer = "c4i_zhouwen_q3" },
            { id = "q4", text = "14点左右你帮严总定的药，订单显示16点送达，可外卖柜记录却是18点，你能解释一下么？",
              answer = "c4i_zhouwen_q4", requireClue = "c4_delivery", clue = "c4_tes_order" },
        },
        ending = "c4i_zhouwen_end",
        repeatText = "李顾问……我还有事，先走了。",
    },
    frontdesk = {
        name = "前台接待",
        first = "c4i_frontdesk_first",
        topics = {
            { id = "q1", text = "峰会举办期间，是否有人可以随意进入酒店？", answer = "c4i_frontdesk_q1" },
            { id = "q2", text = "有注意到当时送外卖的无人机有什么异常么？", answer = "c4i_frontdesk_q2" },
            { id = "q3", text = "16点30到18点，除了严城峰外，还有谁使用过电梯么？", answer = "c4i_frontdesk_q3" },
        },
        ending = "c4i_frontdesk_end",
        repeatText = "不好意思先生，工作期间我们不能聊私事。",
    },
    guard = {
        name = "庭院入口保安",
        first = "c4i_guard_first",
        topics = {
            { id = "q1", text = "你在这工作时，有看到什么神色可疑或奇怪的人么？", answer = "c4i_guard_q1", clue = "c4_tes_guard" },
            { id = "q2", text = "那你知道那人是谁么？", answer = "c4i_guard_q2", requireTopic = "q1" },
            { id = "q3", text = "如果再见到那个人，你还能认出来么？", answer = "c4i_guard_q3", requireTopic = "q2" },
        },
        ending = "c4i_guard_end",
        repeatText = "有需要帮助的可以随时联系我，我会一直在这。",
    },
    -- ===== 1L 大厅 / 庭院 =====
    xuqinglan = {
        name = "许晴岚",
        first = "c4i_xuqinglan_first",
        topics = {
            { id = "q1", text = "关于周文，你知道些什么？", answer = "c4i_xuqinglan_q1", clue = "c4_tes_zhouwen_past" },
            { id = "q2", text = "交流会时有注意到什么可疑人员么？", answer = "c4i_xuqinglan_q2" },
        },
        ending = "c4i_xuqinglan_end",
        repeatText = "我这边还有一堆人要安抚，回头再说吧。",
    },
    zhaoheng = {
        name = "赵恒",
        first = "c4i_zhaoheng_first",
        topics = {
            { id = "q1", text = "你让服务员去给严总送药是怎么回事？", answer = "c4i_zhaoheng_q1", clue = "c4_tes_zhao_med" },
            { id = "q2", text = "当时有注意到什么可疑的人么？", answer = "c4i_zhaoheng_q2" },
            { id = "q3", text = "赵总平时都抽尼龙牌的香烟吧？这个牌子一般人可搞不到。",
              answer = "c4i_zhaoheng_q3", requireClueList = { "c4_seat_table", "c4_trash" }, clue = "c4_tes_zhao_smoke" },
        },
        ending = nil,
        repeatText = "劳驾……我现在真的不想说话。",
    },
}

-- ============================================================================
-- 对证配置（搜证阶段，2501 房间集会）
-- 顺序执行：赵恒 → 周文 → 许晴岚
-- ============================================================================
M.Confrontations = {
    {
        id = "zhaoheng", name = "赵恒",
        questions = {
            { ask = "c4c_zhao_q1",
              options = {
                { text = "A：1L垃圾桶旁有尼龙牌香烟", correct = true },
                { text = "B：你撒谎！" },
                { text = "C：是么……好吧" },
              },
              correctDlg = "c4c_zhao_q1_ok" },
            { ask = "c4c_zhao_q2",
              options = {
                { text = "A：保安的证词", correct = true },
                { text = "B：好像确实没必要特意从25楼下来" },
                { text = "C：我想想" },
              },
              correctDlg = "c4c_zhao_q2_ok" },
            { ask = "c4c_zhao_q3",
              options = {
                { text = "A：他说的有道理……" },
                { text = "B：安全通道把手上的汗渍", correct = true },
                { text = "C：真没办法啊……" },
              },
              correctDlg = "c4c_zhao_q3_ok", clue = "c4_sweat" },
        },
        tail = "c4c_zhao_tail",
    },
    {
        id = "zhouwen", name = "周文",
        questions = {
            -- multi：两个选项都是有效追问，需全部问完才进入下一题
            { ask = "c4c_zhou_q1", multi = true,
              options = {
                { text = "A：那你当时在25楼时有看到什么可疑人物么？", dlg = "c4c_zhou_q1a" },
                { text = "B：你有严城峰房间的备用房卡？", dlg = "c4c_zhou_q1b" },
              } },
            { ask = "c4c_zhou_q2",
              options = {
                { text = "A：你怎么确定文件一定在严城峰床头柜里？", correct = true },
              },
              correctDlg = "c4c_zhou_q2_ok", unlock = "c4_camera_spotted" },
            { ask = "c4c_zhou_q3", multi = true,
              options = {
                { text = "A：那你对你们公司的技术应该也很了解吧？", dlg = "c4c_zhou_q3a" },
                { text = "B：这套外卖系统也是你们公司做的，可记录显示18点才送达。", dlg = "c4c_zhou_q3b" },
              } },
            { ask = "c4c_zhou_q4",
              options = {
                { text = "A：你是否能帮忙排查一下系统故障原因？", correct = true },
              },
              correctDlg = "c4c_zhou_q4_ok" },
        },
        tail = nil,
    },
    {
        id = "xuqinglan", name = "许晴岚",
        questions = {
            { ask = "c4c_xu_q1",
              options = { { text = "A：赵恒和严城峰两人私下有没有什么过节？", correct = true } },
              correctDlg = "c4c_xu_q1_ok", clue = "c4_tes_zhao_corrupt" },
            { ask = "c4c_xu_q2",
              options = { { text = "B：周文为什么会贬成普通职员？", correct = true } },
              correctDlg = "c4c_xu_q2_ok" },
        },
        tail = nil,
    },
}

-- ============================================================================
-- 通用：选项面板
-- options: { text, enabled(默认true), onPick }
-- ============================================================================
local function _destroyUI()
    if M._panel and M._panel.Destroy then pcall(function() M._panel:Destroy() end) end
    if M._overlay and M._overlay.Destroy then pcall(function() M._overlay:Destroy() end) end
    M._panel, M._overlay = nil, nil
end

function M._ShowChoices(title, subtitle, options, onClose)
    _destroyUI()
    local root = UI.GetRoot()
    if not root then if onClose then onClose() end return end
    local sw, sh = graphics:GetWidth(), graphics:GetHeight()

    -- 全屏遮罩，拦截场景点击
    M._overlay = UI.Button(root, {
        left = 0, top = 0, width = sw, height = sh,
        backgroundColor = { 0, 0, 0, 150 }, zIndex = 50000, borderWidth = 0,
    })
    M._overlay.props.onClick = function() end

    local n = #options
    local panelH = 130 + n * 62
    local panelW = 620
    M._panel = UI.Panel(root, {
        left = sw / 2 - panelW / 2, top = sh / 2 - panelH / 2, width = panelW, height = panelH,
        backgroundColor = { 20, 22, 38, 245 }, borderRadius = 14,
        borderWidth = 2, borderColor = { 180, 160, 120, 200 }, zIndex = 50001,
    })

    UI.Label(M._panel, {
        left = 0, top = 18, width = panelW, height = 32,
        text = title or "", fontSize = 22, fontColor = { 255, 240, 200, 255 }, textAlign = "center",
    })
    if subtitle and subtitle ~= "" then
        UI.Label(M._panel, {
            left = 30, top = 56, width = panelW - 60, height = 26,
            text = subtitle, fontSize = 15, fontColor = { 255, 220, 120, 255 }, textAlign = "center",
        })
    end

    for i, opt in ipairs(options) do
        local enabled = (opt.enabled ~= false)
        local b = UI.Button(M._panel, {
            left = 40, top = 92 + (i - 1) * 62, width = panelW - 80, height = 52,
            text = opt.text, fontSize = 16,
            fontColor = enabled and { 255, 255, 255, 240 } or { 130, 130, 140, 220 },
            backgroundColor = enabled and { 60, 82, 132, 220 } or { 45, 48, 60, 200 },
            borderRadius = 8, borderWidth = 1, borderColor = { 255, 255, 255, 40 },
        })
        b.props.onClick = function()
            if not enabled then return end
            if not _debounce() then return end
            _destroyUI()
            if opt.onPick then opt.onPick() end
        end
    end

    if onClose then M._onClose = onClose end
end

-- ============================================================================
-- 询问流程
-- ============================================================================
local function _flag(npcId, topicId) return "ask_" .. npcId .. "_" .. topicId end

function M._TopicAvailable(cfg, topic, GameData)
    if GameData.GetFlag(_flag(M._curNpc, topic.id)) then return false end
    if topic.requireTopic and not GameData.GetFlag(_flag(M._curNpc, topic.requireTopic)) then
        return false
    end
    if topic.requireClue and not GameData.GetFlag("clue_" .. topic.requireClue) then
        return false
    end
    if topic.requireClueList then
        for _, cid in ipairs(topic.requireClueList) do
            if not GameData.GetFlag("clue_" .. cid) then return false end
        end
    end
    return true
end

function M._ShowTopics(cfg)
    local GameData = require("scripts.GameData")
    local DialogueSystem = require("scripts.DialogueSystem")

    local avail = {}
    for _, t in ipairs(cfg.topics) do
        if M._TopicAvailable(cfg, t, GameData) then avail[#avail + 1] = t end
    end

    if #avail == 0 then
        -- 全部问完：播结束语（只播一次，之后循环提示）
        local endFlag = "ask_" .. M._curNpc .. "_ending"
        if cfg.ending and not GameData.GetFlag(endFlag) then
            GameData.SetFlag(endFlag, true)
            DialogueSystem.Start(cfg.ending, function() M.Finish() end)
        else
            local SM = require("scripts.SceneManager")
            if SM.ShowClueBanner then
                SM:ShowClueBanner(cfg.name, cfg.repeatText or "……")
            end
            M.Finish()
        end
        return
    end

    local opts = {}
    for _, t in ipairs(avail) do
        opts[#opts + 1] = {
            text = t.text,
            onPick = function()
                GameData.SetFlag(_flag(M._curNpc, t.id), true)
                DialogueSystem.Start(t.answer, function()
                    if t.clue then
                        GameData.CollectClue(t.clue)
                        GameData.SetFlag("clue_" .. t.clue, true)
                    end
                    M._ShowTopics(cfg)
                end)
            end,
        }
    end
    opts[#opts + 1] = {
        text = "（结束询问）",
        onPick = function() M.Finish() end,
    }
    M._ShowChoices("询问 · " .. cfg.name, "选择要追问的内容", opts, M.Finish)
end

function M.StartInterrogation(npcId, onFinish)
    local GameData = require("scripts.GameData")
    local DialogueSystem = require("scripts.DialogueSystem")
    local cfg = M.Interrogations[npcId]
    print(string.format("[INT DEBUG] StartInterrogation: npc=%s cfg=%s",
        tostring(npcId), tostring(cfg ~= nil)))
    if not cfg then
        print("[INT DEBUG] 无此询问配置，交互被忽略")
        if onFinish then onFinish() end
        return
    end

    M.active = true
    M._curNpc = npcId
    M._onFinish = onFinish

    local firstFlag = "ask_" .. npcId .. "_first"
    local dlg = (cfg.first and not GameData.GetFlag(firstFlag)) and cfg.first or nil
    print(string.format("[INT DEBUG] firstDlg=%s topics=%d",
        tostring(dlg), #cfg.topics))
    if dlg then
        GameData.SetFlag(firstFlag, true)
        DialogueSystem.Start(dlg, function() M._ShowTopics(cfg) end)
    else
        M._ShowTopics(cfg)
    end
end

function M.Finish()
    _destroyUI()
    M.active = false
    local cb = M._onFinish
    M._onFinish = nil
    if cb then cb() end
end

-- ============================================================================
-- 对证流程（搜证阶段）
-- ============================================================================
-- 每个 question：播 ask 对话 → 弹证据选项 → 正确则播 correctDlg 并进入下一问
-- 全部完成后回调 onFinish
-- 对证进度 flag：person 第 qi 题第 oi 个选项（或 "ask"）
local function _cflag(personId, qi, oi)
    return string.format("c4c_%s_%d_%s", personId, qi, tostring(oi))
end

-- 多选模式：所有选项都是有效追问，需全部问完才推进下一题
function M._RunMulti(person, qi, onPersonDone)
    local GameData = require("scripts.GameData")
    local DialogueSystem = require("scripts.DialogueSystem")
    local q = person.questions[qi]
    if not q then M._RunQuestion(person, qi, onPersonDone) return end

    local avail = {}
    for oi, o in ipairs(q.options) do
        if not GameData.GetFlag(_cflag(person.id, qi, oi)) then
            avail[#avail + 1] = { o = o, oi = oi }
        end
    end
    if #avail == 0 then
        M._RunQuestion(person, qi + 1, onPersonDone)
        return
    end

    local function showOpts()
        local opts = {}
        for _, a in ipairs(avail) do
            opts[#opts + 1] = {
                text = a.o.text,
                onPick = function()
                    GameData.SetFlag(_cflag(person.id, qi, a.oi), true)
                    local dlg = a.o.dlg or q.correctDlg
                    if a.o.clue then
                        GameData.CollectClue(a.o.clue)
                        GameData.SetFlag("clue_" .. a.o.clue, true)
                    end
                    if a.o.unlock then GameData.SetFlag(a.o.unlock, true) end
                    DialogueSystem.Start(dlg, function()
                        M._RunMulti(person, qi, onPersonDone)
                    end)
                end,
            }
        end
        M._ShowChoices("对证 · " .. person.name, "继续追问", opts, nil)
    end

    if not GameData.GetFlag(_cflag(person.id, qi, "ask")) then
        GameData.SetFlag(_cflag(person.id, qi, "ask"), true)
        DialogueSystem.Start(q.ask, showOpts)
    else
        showOpts()
    end
end

function M._RunQuestion(person, qi, onPersonDone)
    local GameData = require("scripts.GameData")
    local DialogueSystem = require("scripts.DialogueSystem")
    local q = person.questions[qi]
    if not q then
        if person.tail then
            DialogueSystem.Start(person.tail, function() onPersonDone() end)
        else
            onPersonDone()
        end
        return
    end

    if q.multi then
        M._RunMulti(person, qi, onPersonDone)
        return
    end

    DialogueSystem.Start(q.ask, function()
        local opts = {}
        for _, o in ipairs(q.options) do
            opts[#opts + 1] = {
                text = o.text,
                onPick = function()
                    if o.correct then
                        if q.clue then
                            GameData.CollectClue(q.clue)
                            GameData.SetFlag("clue_" .. q.clue, true)
                        end
                        if q.unlock then GameData.SetFlag(q.unlock, true) end
                        DialogueSystem.Start(q.correctDlg, function()
                            M._RunQuestion(person, qi + 1, onPersonDone)
                        end)
                    else
                        local SM = require("scripts.SceneManager")
                        if SM.ShowClueBanner then
                            SM:ShowClueBanner("证据不足", "这条证据说服不了他，再想想别的。")
                        end
                        -- 选错可重试
                        M._RunQuestionRetry(person, qi, onPersonDone)
                    end
                end,
            }
        end
        M._ShowChoices("对证 · " .. person.name, "用证据指出他话里的破绽", opts, nil)
    end)
end

-- 选错后重新弹出同一题的选项
function M._RunQuestionRetry(person, qi, onPersonDone)
    local GameData = require("scripts.GameData")
    local DialogueSystem = require("scripts.DialogueSystem")
    local q = person.questions[qi]
    if not q then onPersonDone() return end
    local opts = {}
    for _, o in ipairs(q.options) do
        opts[#opts + 1] = {
            text = o.text,
            onPick = function()
                if o.correct then
                    if q.clue then
                        GameData.CollectClue(q.clue)
                        GameData.SetFlag("clue_" .. q.clue, true)
                    end
                    if q.unlock then GameData.SetFlag(q.unlock, true) end
                    DialogueSystem.Start(q.correctDlg, function()
                        M._RunQuestion(person, qi + 1, onPersonDone)
                    end)
                else
                    local SM = require("scripts.SceneManager")
                    if SM.ShowClueBanner then
                        SM:ShowClueBanner("证据不足", "这条证据说服不了他，再想想别的。")
                    end
                    M._RunQuestionRetry(person, qi, onPersonDone)
                end
            end,
        }
    end
    M._ShowChoices("对证 · " .. person.name, "用证据指出他话里的破绽", opts, nil)
end

function M.StartConfrontation(onFinish)
    local DialogueSystem = require("scripts.DialogueSystem")
    M.active = true
    local idx = 1
    local function nextPerson()
        local person = M.Confrontations[idx]
        if not person then
            M.active = false
            _destroyUI()
            if onFinish then onFinish() end
            return
        end
        idx = idx + 1
        if person.dialogue then
            DialogueSystem.Start(person.dialogue, function() M._RunQuestion(person, 1, nextPerson) end)
        else
            M._RunQuestion(person, 1, nextPerson)
        end
    end
    nextPerson()
end

function M.IsActive()
    return M.active
end

function M.Close()
    _destroyUI()
    M.active = false
    M._onFinish = nil
end

return M
