-- ============================================================================
-- NoteSystem.lua - 侦探笔记系统
-- 文档 5.2 侦探笔记功能完整实现
-- 布局：顶部标题栏 + 四大分类标签 + 左侧列表(35%) + 右侧详情(65%)
-- 交互：Tab 呼出/关闭、Q/E 切换标签、W/S 切换条目、F 标记、鼠标点击
-- 状态机：Locked(未发现) -> Unread(新收录) -> Read(已读)，Starred(标记)为附加状态
-- ============================================================================

local UI = require("urhox-libs.UI")

local M = {}

-- ============================================================================
-- 状态
-- ============================================================================
M.state = {
    isOpen = false,
    categoryIndex = 1,       -- 当前分类（1~4）
    selectedIndex = 1,       -- 当前可见列表中的选中索引
    filterStarredOnly = false,
    visibleClues = {},       -- 当前可见的线索列表
}

M.callbacks = {}

M.ui = {
    root = nil,
    tabButtons = {},
    listContainer = nil,
    listItems = {},
    detailName = nil,
    detailCategory = nil,
    detailText = nil,
    detailHint = nil,
    filterButton = nil,
    unreadHint = nil,
}

-- ============================================================================
-- 初始化
-- ============================================================================
function M.Init(callbacks)
    M.callbacks = callbacks or {}
end

-- ============================================================================
-- 打开/关闭
-- ============================================================================
function M.IsOpen()
    return M.state.isOpen
end

function M.Toggle()
    if M.state.isOpen then
        M.Close()
    else
        M.Open()
    end
end

function M.Open()
    if M.state.isOpen then return end
    M.state.isOpen = true
    M.state.filterStarredOnly = false
    M.state.selectedIndex = 1
    M.RefreshVisibleList()
    M.BuildUI()
end

function M.Close()
    if not M.state.isOpen then return end
    M.state.isOpen = false
    if M.ui.root then
        M.ui.root:Destroy()
        M.ui.root = nil
    end
    M.ui.tabButtons = {}
    M.ui.listItems = {}
end

-- ============================================================================
-- 构建可见线索列表（按当前分类 + 过滤）
-- ============================================================================
function M.RefreshVisibleList()
    local GameData = require("scripts.GameData")
    local category = GameData.ClueCategories[M.state.categoryIndex]
    M.state.visibleClues = {}

    for _, clue in pairs(GameData.Clues) do
        if clue.category == category.id and GameData.HasClue(clue.id) then
            if not M.state.filterStarredOnly or GameData.GameState.starredClues[clue.id] then
                table.insert(M.state.visibleClues, clue)
            end
        end
    end

    -- 排序：未读优先，然后按章节、再按 id
    local chapterOrder = { prologue = 0, chapter1 = 1 }
    table.sort(M.state.visibleClues, function(a, b)
        local aUnread = (GameData.GameState.readClues[a.id] ~= true)
        local bUnread = (GameData.GameState.readClues[b.id] ~= true)
        if aUnread ~= bUnread then return aUnread end
        local aChap = chapterOrder[a.chapter] or 99
        local bChap = chapterOrder[b.chapter] or 99
        if aChap ~= bChap then return aChap < bChap end
        return a.id < b.id
    end)

    -- 修正选中索引
    if #M.state.visibleClues == 0 then
        M.state.selectedIndex = 0
    elseif M.state.selectedIndex < 1 or M.state.selectedIndex > #M.state.visibleClues then
        M.state.selectedIndex = 1
    end
end

-- ============================================================================
-- 构建UI
-- ============================================================================
function M.BuildUI()
    local GameData = require("scripts.GameData")

    if M.ui.root then
        M.ui.root:Destroy()
        M.ui.root = nil
    end
    M.ui.tabButtons = {}
    M.ui.listItems = {}

    local caseName = "暂无案件"
    if GameData.GameState.currentChapter == "chapter1" then
        caseName = "落晖之宴·严成峰坠亡案"
    end

    M.ui.root = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 10, 8, 18, 235 },
        flexDirection = "column",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
    }

    -- ===== 顶部标题栏 =====
    local titleBar = UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        justifyContent = "space-between",
        padding = { 24, 30, 16, 30 },
        borderBottomWidth = 1,
        borderBottomColor = { 120, 110, 90, 120 },
    }
    M.ui.root:AddChild(titleBar)

    titleBar:AddChild(UI.Label {
        text = "🔍 侦探笔记",
        fontSize = 26,
        fontColor = { 220, 200, 160, 255 },
        fontWeight = "bold",
    })

    titleBar:AddChild(UI.Label {
        text = "当前案件：" .. caseName,
        fontSize = 16,
        fontColor = { 170, 160, 150, 255 },
    })

    titleBar:AddChild(UI.Label {
        text = "ESC / Tab 退出",
        fontSize = 14,
        fontColor = { 140, 140, 140, 255 },
    })

    -- ===== 分类标签栏 =====
    local tabBar = UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = 10,
        padding = { 10, 30, 10, 30 },
    }
    M.ui.root:AddChild(tabBar)

    for i, cat in ipairs(GameData.ClueCategories) do
        local unreadCount = M.CountUnreadInCategory(cat.id)
        local label = cat.name
        if unreadCount > 0 then
            label = cat.name .. "  [" .. unreadCount .. "]"
        end
        local btn = UI.Button {
            text = label,
            fontSize = 16,
            width = 140, height = 40,
            variant = (i == M.state.categoryIndex) and "primary" or "secondary",
            onClick = function()
                M.SelectCategory(i)
            end,
        }
        tabBar:AddChild(btn)
        M.ui.tabButtons[i] = btn
    end

    -- 只看标记⭐ 过滤按钮
    local filterText = M.state.filterStarredOnly and "⭐ 只看标记 [开]" or "⭐ 只看标记"
    M.ui.filterButton = UI.Button {
        text = filterText,
        fontSize = 15,
        width = 150, height = 40,
        variant = M.state.filterStarredOnly and "primary" or "secondary",
        onClick = function()
            M.state.filterStarredOnly = not M.state.filterStarredOnly
            M.state.selectedIndex = 1
            M.RefreshVisibleList()
            M.BuildUI()
        end,
    }
    tabBar:AddChild(M.ui.filterButton)

    -- ===== 主体：左侧列表 + 右侧详情 =====
    local body = UI.Panel {
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
        flexDirection = "row",
        padding = { 0, 30, 0, 30 },
        gap = 16,
    }
    M.ui.root:AddChild(body)

    -- 左侧列表（35%）
    local leftPanel = UI.Panel {
        width = "35%",
        height = "100%",
        flexDirection = "column",
        gap = 8,
    }
    body:AddChild(leftPanel)

    local scroll = UI.ScrollView {
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
        scrollY = true,
    }
    leftPanel:AddChild(scroll)

    M.ui.listContainer = UI.Panel {
        width = "100%",
        flexDirection = "column",
        gap = 6,
    }
    scroll:AddChild(M.ui.listContainer)

    if #M.state.visibleClues == 0 then
        local emptyText = M.state.filterStarredOnly and "该分类下没有已标记的线索" or "该分类下暂无已发现的线索"
        M.ui.listContainer:AddChild(UI.Label {
            text = emptyText,
            fontSize = 15,
            fontColor = { 130, 130, 130, 255 },
            whiteSpace = "normal",
        })
    else
        for idx, clue in ipairs(M.state.visibleClues) do
            local isSelected = (idx == M.state.selectedIndex)
            local isUnread = (GameData.GameState.readClues[clue.id] ~= true)
            local isStarred = GameData.GameState.starredClues[clue.id]

            local prefix = ""
            if isUnread then prefix = prefix .. "🔴 " end
            if isStarred then prefix = prefix .. "⭐ " end

            local btn = UI.Button {
                text = prefix .. clue.name,
                fontSize = 16,
                width = "100%",
                height = 44,
                textAlign = "left",
                variant = "secondary",
                backgroundColor = isSelected and { 60, 50, 90, 255 } or { 30, 26, 44, 255 },
                onClick = function()
                    M.SelectClue(idx)
                end,
            }
            M.ui.listContainer:AddChild(btn)
            M.ui.listItems[idx] = btn
        end
    end

    -- 右侧详情（65%）
    local rightPanel = UI.Panel {
        width = "65%",
        height = "100%",
        backgroundColor = { 26, 22, 40, 255 },
        borderRadius = 10,
        borderWidth = 1,
        borderColor = { 90, 80, 110, 200 },
        flexDirection = "column",
        padding = 24,
        gap = 14,
    }
    body:AddChild(rightPanel)

    local selectedClue = M.GetSelectedClue()
    if selectedClue then
        local cat = M.GetCategoryById(selectedClue.category)
        local isUnread = (GameData.GameState.readClues[selectedClue.id] ~= true)
        local isStarred = GameData.GameState.starredClues[selectedClue.id]

        M.ui.detailName = UI.Label {
            text = selectedClue.name,
            fontSize = 24,
            fontColor = { 240, 235, 225, 255 },
            fontWeight = "bold",
        }
        rightPanel:AddChild(M.ui.detailName)

        local catColor = cat and cat.color or { 180, 180, 180, 255 }
        M.ui.detailCategory = UI.Label {
            text = "【" .. (cat and cat.name or selectedClue.category) .. "】" .. (isStarred and "  ⭐已标记" or ""),
            fontSize = 15,
            fontColor = { catColor[1], catColor[2], catColor[3], 255 },
        }
        rightPanel:AddChild(M.ui.detailCategory)

        M.ui.detailText = UI.Label {
            text = selectedClue.detail or selectedClue.description or "",
            fontSize = 17,
            fontColor = { 210, 205, 200, 255 },
            whiteSpace = "normal",
        }
        rightPanel:AddChild(M.ui.detailText)

        M.ui.detailHint = UI.Label {
            text = isUnread and "【新线索】已自动标记为已读" or "按 F 键标记 / 取消标记",
            fontSize = 13,
            fontColor = { 150, 150, 150, 255 },
        }
        rightPanel:AddChild(M.ui.detailHint)

        -- 选中后自动标记为已读
        if isUnread then
            GameData.MarkClueRead(selectedClue.id)
        end
    else
        M.ui.detailName = UI.Label {
            text = "暂无内容",
            fontSize = 22,
            fontColor = { 150, 150, 150, 255 },
        }
        rightPanel:AddChild(M.ui.detailName)
    end

    -- ===== 底部操作提示 =====
    M.ui.root:AddChild(UI.Label {
        text = "W/S 或 ↑/↓ 选择条目    |    F 标记/取消    |    Q/E 切换分类    |    Tab/ESC 关闭",
        fontSize = 14,
        fontColor = { 150, 150, 150, 255 },
        textAlign = "center",
        padding = 10,
        width = "100%",
    })

    local uiRoot = UI.GetRoot()
    if uiRoot then uiRoot:AddChild(M.ui.root) end
end

-- ============================================================================
-- 选择分类 / 条目
-- ============================================================================
function M.SelectCategory(index)
    M.state.categoryIndex = index
    M.state.selectedIndex = 1
    M.RefreshVisibleList()
    M.BuildUI()
end

function M.SelectClue(index)
    M.state.selectedIndex = index
    -- 仅刷新详情，重建UI（简单可靠）
    M.BuildUI()
end

-- ============================================================================
-- 辅助查询
-- ============================================================================
function M.GetSelectedClue()
    return M.state.visibleClues[M.state.selectedIndex]
end

function M.GetCategoryById(catId)
    local GameData = require("scripts.GameData")
    for _, cat in ipairs(GameData.ClueCategories) do
        if cat.id == catId then return cat end
    end
    return nil
end

-- 某分类下的未读数量
function M.CountUnreadInCategory(catId)
    local GameData = require("scripts.GameData")
    local count = 0
    for _, clue in pairs(GameData.Clues) do
        if clue.category == catId and GameData.HasClue(clue.id) then
            if GameData.GameState.readClues[clue.id] ~= true then
                count = count + 1
            end
        end
    end
    return count
end

-- 全局未读数量（供 HUD 红点）
function M.GetUnreadCount()
    local GameData = require("scripts.GameData")
    local count = 0
    for _, clue in pairs(GameData.Clues) do
        if GameData.HasClue(clue.id) and GameData.GameState.readClues[clue.id] ~= true then
            count = count + 1
        end
    end
    return count
end

-- ============================================================================
-- 更新（键盘输入处理）
-- ============================================================================
function M.Update(deltaTime)
    if not M.state.isOpen then return end

    local GameData = require("scripts.GameData")

    -- 注意：Tab / ESC 关闭由 main.lua 的 HandleInput 统一处理

    -- Q/E 或 ←/→ 切换分类
    local categoryCount = #GameData.ClueCategories
    if input:GetKeyPress(KEY_Q) or input:GetKeyPress(KEY_LEFT) then
        M.state.categoryIndex = M.state.categoryIndex - 1
        if M.state.categoryIndex < 1 then M.state.categoryIndex = categoryCount end
        M.state.selectedIndex = 1
        M.RefreshVisibleList()
        M.BuildUI()
        return
    end
    if input:GetKeyPress(KEY_E) or input:GetKeyPress(KEY_RIGHT) then
        M.state.categoryIndex = M.state.categoryIndex + 1
        if M.state.categoryIndex > categoryCount then M.state.categoryIndex = 1 end
        M.state.selectedIndex = 1
        M.RefreshVisibleList()
        M.BuildUI()
        return
    end

    -- W/S 或 ↑/↓ 切换条目
    local listCount = #M.state.visibleClues
    if listCount > 0 then
        if input:GetKeyPress(KEY_W) or input:GetKeyPress(KEY_UP) then
            M.state.selectedIndex = M.state.selectedIndex - 1
            if M.state.selectedIndex < 1 then M.state.selectedIndex = listCount end
            M.BuildUI()
            return
        end
        if input:GetKeyPress(KEY_S) or input:GetKeyPress(KEY_DOWN) then
            M.state.selectedIndex = M.state.selectedIndex + 1
            if M.state.selectedIndex > listCount then M.state.selectedIndex = 1 end
            M.BuildUI()
            return
        end
    end

    -- F 标记/取消标记
    if input:GetKeyPress(KEY_F) then
        local clue = M.GetSelectedClue()
        if clue then
            GameData.ToggleClueStarred(clue.id)
            M.BuildUI()
        end
        return
    end
end

return M
