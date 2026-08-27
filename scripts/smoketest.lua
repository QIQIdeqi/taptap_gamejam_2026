-- ============================================================================
-- smoketest.lua - 全流程自动化冒烟测试
-- 遍历：对话系统 / 场景物件交互 / 笔记 / 存档 / 菜单，捕获任何报错与阻塞。
-- 在 main.lua 启动时自动调用，结果见 runtime 日志 [SMOKE]。
-- 每个步骤用 pcall 包裹，单个失败不影响整体，最终汇总 PASS/FAIL。
-- ============================================================================

local SceneManager = require("scripts.SceneManager")
local DialogueSystem = require("scripts.DialogueSystem")
local NoteSystem = require("scripts.NoteSystem")
local SaveSystem = require("scripts.SaveSystem")
local MenuSystem = require("scripts.MenuSystem")
local GameData = require("scripts.GameData")

local M = {}

local results = { pass = 0, fail = 0, errors = {} }

local function check(name, fn)
    local ok, err = pcall(fn)
    if ok then
        results.pass = results.pass + 1
    else
        results.fail = results.fail + 1
        results.errors[#results.errors + 1] = name .. ": " .. tostring(err)
    end
end

local function safeStopDialogue()
    local ok, active = pcall(function() return DialogueSystem.IsActive() end)
    if ok and active then
        pcall(function() DialogueSystem.Stop() end)
    end
end

-- 模拟用户点击某个物件（临时屏蔽主流程跳转，避免冒烟中切场景）
local function interact(sceneId, where, item)
    local label = sceneId .. "/" .. where .. "/" .. (item.id or item.name or "?")
    check("Interact " .. label, function()
        local orig = SceneManager.onSpecialInteract
        SceneManager.onSpecialInteract = nil
        SceneManager._onItemInteract(item)
        safeStopDialogue()
        SceneManager.onSpecialInteract = orig
    end)
end

function M.Run()
    results = { pass = 0, fail = 0, errors = {} }
    print("[SMOKE] ===== 开始全流程冒烟测试 =====")

    -- 1. 对话系统：遍历所有对话
    local dcount = 0
    for id, _ in pairs(GameData.Dialogues) do
        dcount = dcount + 1
        check("Dialogue " .. tostring(id), function()
            DialogueSystem.Start(id, function() end, true)
            safeStopDialogue()
        end)
    end
    print("[SMOKE] 对话总数: " .. dcount)

    -- 2. 场景交互：遍历所有场景/屏/物件
    local scount = 0
    for sceneId, scene in pairs(GameData.SceneObjects) do
        scount = scount + 1
        check("EnterScene " .. sceneId, function() SceneManager.EnterScene(sceneId) end)

        if scene.screens then
            for sid, screen in pairs(scene.screens) do
                check("BuildScreen " .. sceneId .. "/" .. tostring(sid), function()
                    SceneManager._BuildScreenContent(sid)
                end)
                for _, item in ipairs(screen.items or {}) do
                    interact(sceneId, tostring(sid), item)
                end
            end
        end
        for _, item in ipairs(scene.items or {}) do
            interact(sceneId, "items", item)
        end
        for _, ex in ipairs(scene.exits or {}) do
            interact(sceneId, "exits", ex)
        end

        check("ExitScene " .. sceneId, function() SceneManager.ExitScene() end)
    end
    print("[SMOKE] 场景总数: " .. scount)

    -- 3. 笔记系统
    check("Note Open", function() NoteSystem.Open() end)
    check("Note Close", function() NoteSystem.Close() end)

    -- 4. 存档系统
    check("Save Slot", function()
        local ok, err = SaveSystem.SaveSlot("smoke", { test = 1, GameState = GameData.GameState })
        if not ok then error(err or "save failed") end
    end)
    check("Load Slot", function()
        local data = SaveSystem.LoadSlot("smoke")
        if not data then error("load returned nil") end
    end)

    -- 5. 菜单系统
    for _, mt in pairs(MenuSystem.MenuType) do
        check("Menu " .. tostring(mt), function() MenuSystem.ShowMenu(mt) end)
    end

    -- 清理：回主菜单
    pcall(function() MenuSystem.ShowMenu(MenuSystem.MenuType.Main) end)

    print(string.format("[SMOKE] ===== 测试完成 PASS=%d FAIL=%d =====", results.pass, results.fail))
    for i, e in ipairs(results.errors) do
        print("[SMOKE][ERR] " .. e)
    end
    return { pass = results.pass, fail = results.fail, errors = results.errors }
end

return M
