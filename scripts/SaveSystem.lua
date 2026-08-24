-- ============================================================================
-- SaveSystem.lua - 存档系统
-- 10个手动存档槽位 + 1个自动存档槽
-- 使用 UrhoX File API 和 cjson
-- ============================================================================

local M = {}

M.SLOT_COUNT = 10
M.AUTO_SLOT_ID = "auto"
M.SAVE_DIR = "saves"

-- 存档缓存
M.slots = {}

-- ============================================================================
-- 初始化
-- ============================================================================

function M.Init()
    M.slots = {}
    -- 确保存档目录存在
    fileSystem:CreateDir(M.SAVE_DIR)

    -- 加载自动存档
    local autoData = M.LoadSlot(M.AUTO_SLOT_ID)
    if autoData then M.slots.auto = autoData end

    -- 加载手动存档
    for i = 1, M.SLOT_COUNT do
        local data = M.LoadSlot(tostring(i))
        if data then M.slots[tostring(i)] = data end
    end
end

-- ============================================================================
-- 文件路径
-- ============================================================================

local function GetSaveFilePath(slotId)
    return M.SAVE_DIR .. "/slot_" .. slotId .. ".json"
end

-- ============================================================================
-- 从文件加载
-- ============================================================================

function M.LoadSlot(slotId)
    local path = GetSaveFilePath(slotId)
    if not fileSystem:FileExists(path) then
        return nil
    end
    local file = File(path, FILE_READ)
    if not file or not file:IsOpen() then
        return nil
    end
    local content = file:ReadString()
    file:Close()
    if not content or content == "" then
        return nil
    end
    local ok, data = pcall(cjson.decode, content)
    if not ok or not data then
        return nil
    end
    return data
end

-- ============================================================================
-- 保存到文件
-- ============================================================================

function M.SaveSlot(slotId, data)
    local path = GetSaveFilePath(slotId)
    data.saveTime = M.GetCurrentTime()
    local content = cjson.encode(data)
    if not content then
        return false, "序列化失败"
    end
    local file = File(path, FILE_WRITE)
    if not file or not file:IsOpen() then
        return false, "无法打开文件"
    end
    file:WriteString(content)
    file:Close()
    M.slots[slotId] = data
    return true
end

-- ============================================================================
-- 删除存档
-- ============================================================================

function M.DeleteSlot(slotId)
    local path = GetSaveFilePath(slotId)
    -- UrhoX 沙箱没有 os.remove，使用 fileSystem 方法
    fileSystem:Delete(path)
    M.slots[slotId] = nil
end

-- ============================================================================
-- 检查存档是否存在
-- ============================================================================

function M.SlotExists(slotId)
    if M.slots[slotId] then return true end
    local path = GetSaveFilePath(slotId)
    return fileSystem:FileExists(path)
end

-- ============================================================================
-- 从游戏状态创建存档数据
-- ============================================================================

function M.CreateSaveDataFromState(gameState)
    local GameData = require("scripts.GameData")
    local data = {
        chapter = gameState.currentChapter or "prologue",
        scene = gameState.currentScene or "office",
        playTime = gameState.playTime or 0,
        collectedClues = {},
        readClues = {},
        starredClues = {},
        flags = {},
        saveTime = "",
    }
    for _, clueId in ipairs(gameState.collectedClues or {}) do
        table.insert(data.collectedClues, clueId)
    end
    for k, v in pairs(gameState.readClues or {}) do
        data.readClues[k] = v
    end
    for k, v in pairs(gameState.starredClues or {}) do
        data.starredClues[k] = v
    end
    for k, v in pairs(gameState.flags or {}) do
        data.flags[k] = v
    end
    local chapter = GameData.Chapters[data.chapter]
    if chapter then
        data.chapterTitle = chapter.title
        data.sceneName = chapter.subtitle
    end
    data.saveTime = M.GetCurrentTime()
    return data
end

-- ============================================================================
-- 保存/读取游戏
-- ============================================================================

function M.SaveGame(slotId, gameState)
    local data = M.CreateSaveDataFromState(gameState)
    return M.SaveSlot(slotId, data)
end

function M.AutoSave(gameState)
    return M.SaveGame(M.AUTO_SLOT_ID, gameState)
end

function M.LoadGame(slotId, gameState)
    local data = M.LoadSlot(slotId)
    if not data then
        return false, "存档不存在或损坏"
    end
    gameState.currentChapter = data.chapter or "prologue"
    gameState.currentScene = data.scene or "office"
    gameState.playTime = data.playTime or 0
    gameState.collectedClues = {}
    if data.collectedClues then
        for _, clueId in ipairs(data.collectedClues) do
            table.insert(gameState.collectedClues, clueId)
        end
    end
    gameState.readClues = {}
    if data.readClues then
        for k, v in pairs(data.readClues) do
            gameState.readClues[k] = v
        end
    end
    gameState.starredClues = {}
    if data.starredClues then
        for k, v in pairs(data.starredClues) do
            gameState.starredClues[k] = v
        end
    end
    gameState.flags = {}
    if data.flags then
        for k, v in pairs(data.flags) do
            gameState.flags[k] = v
        end
    end
    return true
end

-- ============================================================================
-- 辅助函数
-- ============================================================================

function M.GetCurrentTime()
    return os.date("%Y-%m-%d %H:%M:%S")
end

function M.GetSlotInfo(slotId)
    local data = M.slots[slotId]
    if not data then return nil end
    return {
        slotId = slotId,
        chapter = data.chapter,
        chapterTitle = data.chapterTitle or "未知章节",
        sceneName = data.sceneName or "未知地点",
        playTime = data.playTime or 0,
        saveTime = data.saveTime or "",
        isEmpty = false,
    }
end

function M.GetAllSlotsInfo()
    local list = {}
    -- 自动存档置顶
    local autoInfo = M.GetSlotInfo(M.AUTO_SLOT_ID)
    if autoInfo then
        autoInfo.isAuto = true
        table.insert(list, autoInfo)
    end
    -- 手动存档
    for i = 1, M.SLOT_COUNT do
        local slotId = tostring(i)
        local info = M.GetSlotInfo(slotId)
        if info then
            info.isAuto = false
            info.slotNumber = i
            table.insert(list, info)
        else
            table.insert(list, {
                slotId = slotId,
                slotNumber = i,
                isEmpty = true,
                isAuto = false,
            })
        end
    end
    return list
end

function M.FormatPlayTime(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d:%02d", h, m, s)
end

return M
