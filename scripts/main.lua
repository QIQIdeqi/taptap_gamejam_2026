-- ============================================================================
-- main.lua - 游戏主入口
-- 异视（黄昏事务所）- 2D横板推理游戏
-- ============================================================================

-- 引擎模块
local UI = require("urhox-libs.UI")

-- 游戏模块
local GameData = require("scripts.GameData")
local SaveSystem = require("scripts.SaveSystem")
local MenuSystem = require("scripts.MenuSystem")
local SceneManager = require("scripts.SceneManager")
local DialogueSystem = require("scripts.DialogueSystem")
local NoteSystem = require("scripts.NoteSystem")
local OpeningSystem = require("scripts.OpeningSystem")

-- ============================================================================
-- 游戏模式
-- ============================================================================
local GameMode = {
    Boot = "boot",
    MainMenu = "main_menu",
    Playing = "playing",
    Paused = "paused",
}

local currentMode = GameMode.Boot
local playTimer = 0
local autoSaveTimer = 0
local AUTO_SAVE_INTERVAL = 60

-- ============================================================================
-- 初始化
-- ============================================================================

function Start()
    -- UI 库初始化（自动订阅输入/更新/渲染事件，默认 MiSans 字体）
    UI.Init({ scale = UI.Scale.DEFAULT })

    -- 总渲染根节点：全屏黑色背景，各系统 Panel 挂载其下
    local uiRoot = UI.Panel({
        width = "100%",
        height = "100%",
        backgroundColor = { 0, 0, 0, 255 },
        pointerEvents = "box-none",
    })
    UI.SetRoot(uiRoot)

    SaveSystem.Init()
    NoteSystem.Init({})

    MenuSystem.Init({
        onNewGame = function() StartNewGame() end,
        onLoadGame = function(slotId) LoadGame(slotId) end,
        onSaveGame = function(slotId) SaveGame(slotId) end,
        onExitToMain = function() ReturnToMainMenu() end,
        onExitGame = function() engine:Exit() end,
        onResume = function() ResumeGame() end,
    })

    -- 场景回调
    SceneManager.onSceneChanged = function(sceneId)
        GameData.GameState.currentScene = sceneId
    end
    SceneManager.onClueCollected = function(clueId)
        -- 线索横幅已由 SceneManager 显示，此处可留空
    end
    SceneManager.onSpecialInteract = function(obj, onComplete)
        HandleSpecialInteract(obj, onComplete)
    end

    -- 事件驱动主循环：引擎每帧调用 HandleUpdate
    SubscribeToEvent("Update", "HandleUpdate")

    EnterMainMenu()
end

-- ============================================================================
-- 主菜单
-- ============================================================================

function EnterMainMenu()
    currentMode = GameMode.MainMenu
    SceneManager.ExitScene()
    NoteSystem.Close()
    MenuSystem.ShowMenu(MenuSystem.MenuType.Main)
end

-- ============================================================================
-- 开始新游戏
-- ============================================================================

function StartNewGame()
    GameData.ResetGameState()
    playTimer = 0
    autoSaveTimer = 0
    MenuSystem.Close()
    currentMode = GameMode.Playing

    GameData.GameState.currentChapter = "prologue"
    GameData.GameState.currentScene = "office"

    -- 序章开场动画（黑屏时间地点 + 5个分镜对话）
    OpeningSystem.Start("prologue", function()
        EnterPrologueScene()
    end)
end

-- 进入序章场景（新手引导：书柜/衣柜/床铺）
function EnterPrologueScene()
    -- 初始人物名录
    GameData.CollectClue("char_lizhi")
    GameData.CollectClue("char_wenyin")
    GameData.MarkClueRead("char_lizhi")
    GameData.MarkClueRead("char_wenyin")

    SceneManager.EnterScene("office", nil)
end

-- 特殊交互处理（衣柜触发剧情推进）
-- 统计玩家在场景中主动探索收录的线索数量（基于 flags["clue_<id>"]，排除开场赠予线索）
local GRANTED_CLUES = {
    char_lizhi = true, char_wenyin = true,
    char_xuqinglan = true, char_yanchengfeng = true, char_zhaoheng = true, char_zhouwen = true,
    xu_intro_panan = true, sister_call = true, frontdesk_statement = true,
}
local function countClues()
    local gs = GameData.GameState or {}
    local flags = gs.flags or {}
    local n = 0
    for k, v in pairs(flags) do
        if type(k) == "string" and k:sub(1, 5) == "clue_" and v then
            local id = k:sub(6)
            if not GRANTED_CLUES[id] then n = n + 1 end
        end
    end
    return n
end

-- 结案推理：播放推理独白后弹出嫌疑人选择
local function ShowSuspectChoice()
    local root = UI.GetRoot()
    local sw, sh = graphics:GetWidth(), graphics:GetHeight()
    -- 半透明覆盖层（拦截点击，防止误触场景）
    local overlay = UI.Button(root, {
        left = 0, top = 0, width = sw, height = sh,
        backgroundColor = "rgba(0,0,0,150)", zorder = 200, borderWidth = 0,
    })
    -- 选择面板
    local panel = UI.Panel(root, {
        left = sw / 2 - 230, top = sh / 2 - 170, width = 460, height = 340,
        backgroundColor = "rgba(20,22,38,240)", borderRadius = 14,
        borderWidth = 2, borderColor = "rgba(255,255,255,60)", zorder = 201,
    })
    UI.Label(panel, {
        left = 0, top = 20, width = 460, height = 36,
        text = "指认真凶", fontSize = 24, color = "rgba(255,255,255,245)", textAlign = "center",
    })
    local hint = UI.Label(panel, {
        left = 30, top = 64, width = 400, height = 28,
        text = "根据线索，谁是凶手？", fontSize = 16, color = "rgba(255,220,120,255)", textAlign = "center",
    })
    local suspects = {
        { key = "ZhaoHeng",  label = "赵恒（副总）" },
        { key = "ZhouWen",   label = "周文（技术骨干）" },
        { key = "XuQinglan", label = "许晴岚（高管）" },
        { key = "external",  label = "外部人员" },
    }
    for i, s in ipairs(suspects) do
        local b = UI.Button(panel, {
            left = 50, top = 104 + (i - 1) * 52, width = 360, height = 44,
            text = s.label, fontSize = 18, color = "rgba(255,255,255,235)",
            backgroundColor = "rgba(60,82,132,210)", borderRadius = 8,
            borderWidth = 1, borderColor = "rgba(255,255,255,40)",
        })
        b.props.onClick = function()
            if s.key == "ZhouWen" then
                panel:Destroy(); overlay:Destroy()
                GameData.SetFlag("case_solved", true)
                DialogueSystem.Start("crime_ending_true", nil)
            else
                hint:SetText("证据不足，再想想……")
            end
        end
    end
end

local function StartDeduction()
    DialogueSystem.Start("crime_deduction", function()
        ShowSuspectChoice()
    end)
end

function HandleSpecialInteract(obj, onComplete)
    -- 序章引导：点衣柜推进
    if obj.onInteract == "wardrobe" then
        DialogueSystem.Start("opening_prologue_5_after", function()
            GameData.SetFlag("prologue_done", true)
            EnterChapter1()
        end)
    -- 命案发现：收录足够探索线索后，点 2501 房门触发
    elseif obj.onInteract == "enter_crime" then
        if GameData.GetFlag("crime_discovered") then
            SceneManager.EnterScene("crime_scene")
        else
            local n = countClues()
            if n < 5 then
                SceneManager:ShowClueBanner("2501 房门", "房门紧锁，似乎还进不去。先多点几处线索调查吧。")
            else
                GameData.SetFlag("crime_discovered", true)
                DialogueSystem.Start("crime_found", function()
                    SceneManager.EnterScene("crime_scene")
                end)
            end
        end
    elseif obj.onInteract == "deduce" then
        if GameData.GetFlag("case_solved") then
            DialogueSystem.Start("crime_ending_true", nil)
        elseif not (GameData.GetFlag("clue_smart_device") and GameData.GetFlag("clue_inhaler") and GameData.GetFlag("clue_body_position")) then
            SceneManager:ShowClueBanner("整理线索", "先调查完现场的三处线索，再下结论。")
        else
            StartDeduction()
        end
    else
        if onComplete then onComplete() end
    end
end

-- 进入第一章（第二章段）
function EnterChapter1()
    GameData.GameState.currentChapter = "chapter1"

    -- 退出当前场景，避免过场期间旧场景背景透出
    SceneManager.ExitScene()

    -- 收集第二章人物与证词线索
    local clueIds = {
        "char_xuqinglan", "char_yanchengfeng", "char_zhaoheng", "char_zhouwen",
        "xu_intro_panan", "sister_call", "frontdesk_statement",
    }
    for _, id in ipairs(clueIds) do
        GameData.CollectClue(id)
    end

    -- 第二章开场动画（黑屏时间地点 + 5个分镜对话）
    OpeningSystem.Start("chapter1", function()
        GameData.GameState.currentScene = "hotel_lobby"
        SceneManager.EnterScene("hotel_lobby", nil)
        DialogueSystem.Start("chapter1_free_explore", nil)
    end)
end

-- ============================================================================
-- 存档/读档
-- ============================================================================

function SaveGame(slotId)
    GameData.GameState.playTime = playTimer
    SaveSystem.SaveGame(slotId, GameData.GameState)
end

function LoadGame(slotId)
    local success = SaveSystem.LoadGame(slotId, GameData.GameState)
    if success then
        playTimer = GameData.GameState.playTime or 0
        MenuSystem.Close()
        currentMode = GameMode.Playing

        local sceneId = GameData.GameState.currentScene or "office"
        local chapter = GameData.GameState.currentChapter or "prologue"

        -- 若存档在序章但衣柜已点过，则恢复到酒店场景
        if chapter == "prologue" and GameData.GetFlag("prologue_done") then
            sceneId = "hotel_lobby"
        end

        SceneManager.EnterScene(sceneId, nil)
        ResumeGame()
    end
end

function ReturnToMainMenu()
    currentMode = GameMode.MainMenu
    SceneManager.ExitScene()
    NoteSystem.Close()
    MenuSystem.ShowMenu(MenuSystem.MenuType.Main)
end

function PauseGame()
    if currentMode ~= GameMode.Playing then return end
    currentMode = GameMode.Paused
    MenuSystem.ShowMenu(MenuSystem.MenuType.Pause)
end

function ResumeGame()
    currentMode = GameMode.Playing
    MenuSystem.Close()
end

-- ============================================================================
-- 输入处理
-- ============================================================================

function HandleInput()
    -- ESC：笔记打开时关闭笔记，过场动画中忽略，否则暂停/恢复
    if input:GetKeyPress(KEY_ESCAPE) then
        if NoteSystem.IsOpen() then
            NoteSystem.Close()
        elseif OpeningSystem.IsActive() then
            -- 过场动画中禁用暂停
        elseif currentMode == GameMode.Playing then
            PauseGame()
        elseif currentMode == GameMode.Paused then
            if not MenuSystem.IsOpen() or MenuSystem.currentMenu == MenuSystem.MenuType.Pause then
                ResumeGame()
            end
        end
    end

    -- Tab：呼出/关闭侦探笔记（过场动画中禁用）
    if input:GetKeyPress(KEY_TAB) then
        if currentMode == GameMode.Playing then
            if NoteSystem.IsOpen() then
                NoteSystem.Close()
            elseif not DialogueSystem.IsActive() and not OpeningSystem.IsActive() then
                NoteSystem.Open()
            end
        end
    end

    -- 鼠标点击推进对话
    if input:GetMouseButtonPress(MOUSEB_LEFT) then
        if DialogueSystem.IsActive() then
            DialogueSystem.OnClick()
        end
    end
end

-- ============================================================================
-- 更新循环
-- ============================================================================

function HandleUpdate(eventType, eventData)
    local deltaTime = eventData["TimeStep"]:GetFloat()
    HandleInput()

    if currentMode == GameMode.Playing then
        playTimer = playTimer + deltaTime
        GameData.GameState.playTime = playTimer

        OpeningSystem.Update(deltaTime)
        DialogueSystem.Update(deltaTime)
        SceneManager.Update(deltaTime)
        NoteSystem.Update(deltaTime)

        -- 自动存档（仅场景已进入时）
        if SceneManager.currentScene then
            autoSaveTimer = autoSaveTimer + deltaTime
            if autoSaveTimer >= AUTO_SAVE_INTERVAL then
                autoSaveTimer = 0
                SaveSystem.AutoSave(GameData.GameState)
            end
        end
    elseif currentMode == GameMode.Paused then
        DialogueSystem.Update(deltaTime)
    end
end

-- 注意：UrhoX 为事件驱动架构，无需手写 while 主循环。
-- 引擎启动时自动调用全局 Start()，之后每帧通过 Update 事件调用 HandleUpdate()。
