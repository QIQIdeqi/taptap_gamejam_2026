-- ============================================================================
-- NoteSystem.lua - 侦探笔记系统
-- Figma 基准：1251 x 731（Page 1：物证界面 / 人物录界面）
-- 交互：Tab/ESC 关闭、Q/E 或左右键切换标签、W/S 或上下键切换条目、F 标记
-- ============================================================================

local UI = require("urhox-libs.UI")

local M = {}

local DESIGN_WIDTH = 1251
local DESIGN_HEIGHT = 731
local NOTE_ASSET_ROOT = "image/ui/note/"

-- Figma 标签顺序与 GameData 的历史顺序不同，UI 使用单独映射以免影响其他系统。
local TAB_DEFINITIONS = {
    { id = "evidence", label = "物证" },
    { id = "personnel", label = "人物录" },
    { id = "testimony", label = "证词" },
    { id = "trace", label = "痕迹" },
}

local TAB_X = { -5, 91, 181, 272 }

local PERSONNEL = {
    char_lizhi = { characterId = "LiZhi", gender = "男", image = "image/char_lizhi.png" },
    char_wenyin = { characterId = "ChenWenyin", gender = "女", image = "image/char_wenyin.png" },
    char_xuqinglan = { characterId = "XuQinglan", gender = "女", image = "image/char_xuqinglan.png" },
    char_yanchengfeng = { characterId = "YanChengfeng", gender = "男", image = "image/char_yanchengfeng.png" },
    char_zhaoheng = { characterId = "ZhaoHeng", gender = "男", image = "image/char_zhaoheng.png" },
    char_zhouwen = { characterId = "ZhouWen", gender = "男", image = "image/char_zhouwen.png" },
    char_zhangchengyu = { characterId = "ZhangChengyu", gender = "男", image = "image/char_zhangchengyu.png" },
}

M.state = {
    isOpen = false,
    categoryIndex = 1,
    selectedIndex = 1,
    filterStarredOnly = false,
    visibleClues = {},
    layoutSignature = nil,
    layoutPollTimer = 0,
}

M.callbacks = {}
M.ui = {
    root = nil,
    stage = nil,
    tabButtons = {},
    listContainer = nil,
    listItems = {},
    detailName = nil,
    detailCategory = nil,
    detailText = nil,
    detailHint = nil,
    detailImage = nil,
    filterButton = nil,
}

local function toResourcePath(path)
    if not path then return nil end
    return (path:gsub("^assets/", ""))
end

local function currentTab()
    return TAB_DEFINITIONS[M.state.categoryIndex] or TAB_DEFINITIONS[1]
end

local function getNativeMenuTop()
    local sdkService = rawget(_G, "sdk")
    if not sdkService or not sdkService.GetNativeExitMenuRect then return 0 end
    local ok, rect = pcall(function()
        return sdkService:GetNativeExitMenuRect()
    end)
    if not ok or not rect or not rect.bottom then return 0 end
    return rect.bottom * graphics.height / UI.GetScale()
end

local function getLayoutMetrics()
    local viewportWidth, viewportHeight = UI.GetViewportSize()
    local insets = UI.GetSafeAreaInsets()
    local safeLeft = insets.left or 0
    local safeTop = math.max(insets.top or 0, getNativeMenuTop())
    local safeRight = insets.right or 0
    local safeBottom = insets.bottom or 0
    local availableWidth = math.max(1, viewportWidth - safeLeft - safeRight)
    local availableHeight = math.max(1, viewportHeight - safeTop - safeBottom)
    local scale = math.min(availableWidth / DESIGN_WIDTH, availableHeight / DESIGN_HEIGHT)
    local stageWidth = DESIGN_WIDTH * scale
    local stageHeight = DESIGN_HEIGHT * scale
    local stageLeft = safeLeft + (availableWidth - stageWidth) * 0.5
    local stageTop = safeTop + (availableHeight - stageHeight) * 0.5
    local signature = string.format(
        "%.2f:%.2f:%.2f:%.2f:%.2f:%.2f",
        viewportWidth, viewportHeight, safeLeft, safeTop, safeRight, safeBottom
    )
    return {
        scale = scale,
        left = stageLeft,
        top = stageTop,
        width = stageWidth,
        height = stageHeight,
        signature = signature,
    }
end

local function scaled(value, scale)
    return value * scale
end

local function fontSize(value, scale)
    return math.max(7, value * scale)
end

local function absoluteProps(x, y, width, height, scale, extra)
    local props = extra or {}
    props.position = "absolute"
    props.left = scaled(x, scale)
    props.top = scaled(y, scale)
    props.width = scaled(width, scale)
    props.height = scaled(height, scale)
    return props
end

local function addImage(parent, image, x, y, width, height, scale, zIndex, extra)
    local props = extra or {}
    props.backgroundImage = NOTE_ASSET_ROOT .. image
    props.backgroundFit = props.backgroundFit or "fill"
    props.backgroundColor = props.backgroundColor or { 0, 0, 0, 0 }
    props.pointerEvents = props.pointerEvents or "none"
    props.zIndex = zIndex or 1
    local panel = UI.Panel(absoluteProps(x, y, width, height, scale, props))
    parent:AddChild(panel)
    return panel
end

local function addLabel(parent, text, x, y, width, height, size, color, scale, extra)
    local props = extra or {}
    props.text = text or ""
    props.fontSize = fontSize(size, scale)
    props.fontColor = color
    props.zIndex = props.zIndex or 20
    props.pointerEvents = props.pointerEvents or "none"
    local label = UI.Label(absoluteProps(x, y, width, height, scale, props))
    parent:AddChild(label)
    return label
end

local function chapterLabel(chapter)
    local labels = {
        prologue = "序章",
        chapter1 = "第一章",
        chapter2 = "第二章",
        chapter3 = "第三章",
        chapter4 = "第四章",
    }
    return labels[chapter] or "已收录"
end

local function getCharacterData(clue, GameData)
    local mapping = clue and PERSONNEL[clue.id]
    local character = mapping and GameData.GetCharacter(mapping.characterId) or nil
    return mapping, character
end

function M.Init(callbacks)
    M.callbacks = callbacks or {}
end

function M.IsOpen()
    return M.state.isOpen
end

function M.Toggle()
    if M.state.isOpen then M.Close() else M.Open() end
end

function M.Open()
    if M.state.isOpen then return end
    M.state.isOpen = true
    M.state.filterStarredOnly = false
    M.state.selectedIndex = 1
    M.state.layoutPollTimer = 0
    M.RefreshVisibleList()
    M.BuildUI()
end

function M.Close()
    if not M.state.isOpen then return end
    M.state.isOpen = false
    if M.imagePreviewOverlay then
        M.imagePreviewOverlay:Destroy()
        M.imagePreviewOverlay = nil
    end
    if M.ui.root then
        M.ui.root:Destroy()
        M.ui.root = nil
    end
    M.ui.stage = nil
    M.ui.tabButtons = {}
    M.ui.listItems = {}
end

function M.RefreshVisibleList()
    local GameData = require("scripts.GameData")
    local categoryId = currentTab().id
    M.state.visibleClues = {}

    for _, clue in pairs(GameData.Clues) do
        if clue.category == categoryId and GameData.HasClue(clue.id) then
            if not M.state.filterStarredOnly or GameData.GameState.starredClues[clue.id] then
                table.insert(M.state.visibleClues, clue)
            end
        end
    end

    local chapterOrder = { prologue = 0, chapter1 = 1, chapter2 = 2, chapter3 = 3, chapter4 = 4 }
    table.sort(M.state.visibleClues, function(a, b)
        local aUnread = GameData.GameState.readClues[a.id] ~= true
        local bUnread = GameData.GameState.readClues[b.id] ~= true
        if aUnread ~= bUnread then return aUnread end
        local aChapter = chapterOrder[a.chapter] or 99
        local bChapter = chapterOrder[b.chapter] or 99
        if aChapter ~= bChapter then return aChapter < bChapter end
        return a.id < b.id
    end)

    if #M.state.visibleClues == 0 then
        M.state.selectedIndex = 0
    elseif M.state.selectedIndex < 1 or M.state.selectedIndex > #M.state.visibleClues then
        M.state.selectedIndex = 1
    end
end

local function addTabs(stage, scale)
    for index, definition in ipairs(TAB_DEFINITIONS) do
        local isSelected = not M.state.filterStarredOnly and index == M.state.categoryIndex
        local width = isSelected and 103 or 95
        local tabImage = NOTE_ASSET_ROOT .. (isSelected and "tab_active.png" or "tab_idle.png")
        local button = UI.Button(absoluteProps(TAB_X[index], 75, width, 32, scale, {
            text = definition.label,
            fontSize = fontSize(16, scale),
            fontColor = { 233, 211, 190, 255 },
            textAlign = "center",
            padding = 0,
            borderWidth = 0,
            borderRadius = 0,
            backgroundColor = { 0, 0, 0, 0 },
            hoverBackgroundColor = { 255, 255, 255, 12 },
            pressedBackgroundColor = { 255, 255, 255, 20 },
            backgroundImage = tabImage,
            hoverBackgroundImage = tabImage,
            pressedBackgroundImage = NOTE_ASSET_ROOT .. "tab_active.png",
            backgroundFit = "fill",
            zIndex = 20,
            onClick = function()
                M.SelectCategory(index)
            end,
        }))
        stage:AddChild(button)
        M.ui.tabButtons[index] = button
    end

    local filterSelected = M.state.filterStarredOnly
    local filterWidth = filterSelected and 103 or 95
    local filterImage = NOTE_ASSET_ROOT .. (filterSelected and "tab_active.png" or "tab_idle.png")
    M.ui.filterButton = UI.Button(absoluteProps(365, 75, filterWidth, 32, scale, {
        text = "",
        padding = 0,
        borderWidth = 0,
        borderRadius = 0,
        backgroundColor = { 0, 0, 0, 0 },
        hoverBackgroundColor = { 255, 255, 255, 12 },
        pressedBackgroundColor = { 255, 255, 255, 20 },
        backgroundImage = filterImage,
        hoverBackgroundImage = filterImage,
        pressedBackgroundImage = NOTE_ASSET_ROOT .. "tab_active.png",
        backgroundFit = "fill",
        zIndex = 20,
        onClick = function()
            M.state.filterStarredOnly = not M.state.filterStarredOnly
            M.state.selectedIndex = 1
            M.RefreshVisibleList()
            M.BuildUI()
        end,
    }))
    stage:AddChild(M.ui.filterButton)
    addImage(stage, "mark_icon.png", 378, 79, 22, 24, scale, 22)
    addLabel(stage, "标记", 403, 79, 56, 27, 16, { 233, 211, 190, 255 }, scale, {
        textAlign = "left",
        zIndex = 23,
    })
end

local function addList(stage, scale, GameData)
    local definition = currentTab()
    local countText = M.state.filterStarredOnly
        and ("/ 标记 " .. #M.state.visibleClues)
        or ("/ 全部 " .. #M.state.visibleClues)

    addLabel(stage, definition.label, 22, 122, 100, 34, 22, { 233, 211, 190, 255 }, scale, {
        fontWeight = "bold",
    })
    addLabel(stage, countText, 112, 128, 190, 30, 16, { 196, 196, 196, 255 }, scale)

    local scroll = UI.ScrollView(absoluteProps(14, 154, 425, 530, scale, {
        scrollY = true,
        scrollX = false,
        backgroundColor = { 0, 0, 0, 0 },
        zIndex = 18,
    }))
    stage:AddChild(scroll)

    M.ui.listContainer = UI.Panel {
        width = scaled(416, scale),
        flexDirection = "column",
        backgroundColor = { 0, 0, 0, 0 },
    }
    scroll:AddChild(M.ui.listContainer)

    if #M.state.visibleClues == 0 then
        M.ui.listContainer:AddChild(UI.Label {
            width = scaled(390, scale),
            height = scaled(118, scale),
            text = M.state.filterStarredOnly and "当前分类没有已标记内容" or "当前分类暂无收录内容",
            fontSize = fontSize(16, scale),
            fontColor = { 196, 196, 196, 255 },
            textAlign = "center",
            verticalAlign = "middle",
            whiteSpace = "normal",
        })
        return
    end

    for index, clue in ipairs(M.state.visibleClues) do
        local isSelected = index == M.state.selectedIndex
        local isUnread = GameData.GameState.readClues[clue.id] ~= true
        local isStarred = GameData.GameState.starredClues[clue.id] == true
        local isPersonnel = definition.id == "personnel"
        local item = UI.Panel {
            width = scaled(416, scale),
            height = scaled(118, scale),
            position = "relative",
            backgroundColor = { 0, 0, 0, 0 },
            cursor = "pointer",
            onClick = function()
                M.SelectClue(index)
            end,
        }
        M.ui.listContainer:AddChild(item)

        addImage(item, isPersonnel and "person_card.png" or "evidence_card.png", 3, 0, 410, 118, scale, 1)

        if isPersonnel then
            local mapping = PERSONNEL[clue.id]
            if mapping and mapping.image then
                item:AddChild(UI.Panel(absoluteProps(13, 14, 88, 88, scale, {
                    backgroundImage = mapping.image,
                    backgroundFit = "contain",
                    backgroundColor = { 8, 10, 12, 70 },
                    pointerEvents = "none",
                    zIndex = 3,
                })))
            else
                addLabel(item, "人物头像", 13, 42, 88, 30, 12, { 233, 211, 190, 220 }, scale)
            end
            local titlePrefix = isUnread and "• " or ""
            addLabel(item, titlePrefix .. clue.name, 112, 22, 230, 28, 16,
                isUnread and { 255, 104, 104, 255 } or { 233, 211, 190, 255 }, scale, {
                    fontWeight = "bold",
                })
            addLabel(item, clue.description or "", 112, 56, 238, 48, 13,
                { 196, 196, 196, 255 }, scale, { whiteSpace = "normal" })
        else
            local titlePrefix = isUnread and "• " or ""
            addLabel(item, titlePrefix .. clue.name, 42, 36, 326, 42, 16,
                isUnread and { 255, 104, 104, 255 } or { 233, 211, 190, 255 }, scale, {
                    textAlign = "center",
                    verticalAlign = "middle",
                    fontWeight = isUnread and "bold" or "normal",
                })
        end

        if isStarred then addImage(item, "mark_icon.png", 362, 11, 22, 24, scale, 4) end
        if isSelected then addImage(item, "selected_outline.png", 0, 0, 416, 121, scale, 5) end
        M.ui.listItems[index] = item
    end
end

local function addMarkHint(stage, scale, GameData, x, y, width)
    local clue = M.GetSelectedClue()
    if not clue then return end
    local isStarred = GameData.GameState.starredClues[clue.id] == true
    local hint = UI.Button(absoluteProps(x, y, width, 34, scale, {
        text = isStarred and "按F键取消标记" or "按F键标记/取消标记",
        fontSize = fontSize(16, scale),
        fontColor = { 44, 44, 44, 255 },
        textAlign = "center",
        padding = 0,
        borderWidth = 0,
        borderRadius = 0,
        backgroundColor = { 0, 0, 0, 0 },
        hoverBackgroundColor = { 92, 38, 32, 25 },
        pressedBackgroundColor = { 92, 38, 32, 45 },
        zIndex = 31,
        onClick = function()
            M.ToggleSelectedStar()
        end,
    }))
    stage:AddChild(hint)
    M.ui.detailHint = hint
end

local function addEvidenceDetail(stage, scale, GameData, clue)
    addImage(stage, "photo_frame.png", 498, 173, 449, 438, scale, 12)

    local imagePath = clue and toResourcePath(clue.image) or nil
    if imagePath then
        M.ui.detailImage = UI.Panel(absoluteProps(546, 247, 352, 302, scale, {
            backgroundImage = imagePath,
            backgroundFit = "contain",
            backgroundColor = { 7, 9, 10, 235 },
            cursor = "pointer",
            zIndex = 14,
            onClick = function()
                M.ShowImagePreview(imagePath)
            end,
        }))
        stage:AddChild(M.ui.detailImage)
    else
        addLabel(stage, clue and "暂无物证图像" or "暂无内容", 546, 352, 352, 44, 15,
            { 233, 211, 190, 220 }, scale, { textAlign = "center" })
    end

    local category = currentTab()
    local name = clue and clue.name or "暂无内容"
    local infoPrefix = "物证信息："
    if category.id == "testimony" then infoPrefix = "证词信息：" end
    if category.id == "trace" then infoPrefix = "痕迹信息：" end

    M.ui.detailName = addLabel(stage, name, 940, 190, 272, 52, 24,
        { 251, 51, 54, 255 }, scale, { fontWeight = "bold", whiteSpace = "normal" })
    M.ui.detailText = addLabel(stage, clue and (infoPrefix .. (clue.detail or clue.description or "")) or "",
        940, 250, 270, 235, 14, { 44, 44, 44, 255 }, scale, { whiteSpace = "normal" })

    if clue then
        addLabel(stage, "获取时间", 928, 545, 112, 28, 16, { 44, 44, 44, 255 }, scale, {
            fontWeight = "bold",
        })
        addLabel(stage, chapterLabel(clue.chapter), 1006, 580, 130, 28, 14,
            { 44, 44, 44, 255 }, scale)
        addMarkHint(stage, scale, GameData, 540, 618, 300)
    end
    addImage(stage, "stamp.png", 1118, 590, 126, 126, scale, 18)
end

local function addPersonnelDetail(stage, scale, GameData, clue)
    local mapping, character = getCharacterData(clue, GameData)
    local portraitPath = mapping and mapping.image or nil

    addImage(stage, "photo_frame.png", 545, 124, 312, 305, scale, 12)
    if portraitPath then
        M.ui.detailImage = UI.Panel(absoluteProps(581, 176, 246, 218, scale, {
            backgroundImage = portraitPath,
            backgroundFit = "contain",
            backgroundColor = { 7, 9, 10, 220 },
            cursor = "pointer",
            zIndex = 14,
            onClick = function()
                M.ShowImagePreview(portraitPath)
            end,
        }))
        stage:AddChild(M.ui.detailImage)
    else
        addLabel(stage, "人物头像", 581, 260, 246, 34, 14,
            { 233, 211, 190, 220 }, scale, { textAlign = "center" })
    end

    addImage(stage, "person_name_bar.png", 907, 140, 167, 45, scale, 12)
    addImage(stage, "gender_bar.png", 911, 226, 147, 36, scale, 12)
    addImage(stage, "age_bar.png", 910, 265, 147, 36, scale, 12)
    addImage(stage, "identity_bar.png", 910, 306, 146, 38, scale, 12)
    addImage(stage, "person_details_panel.png", 545, 454, 341, 225, scale, 12)
    addImage(stage, "acquired_panel.png", 885, 534, 341, 135, scale, 12)

    local name = clue and clue.name or "暂无人物"
    local gender = mapping and mapping.gender or "未知"
    local age = character and character.age and tostring(character.age) or "未知"
    local role = character and character.role or "未知"
    local remarks = clue and (clue.description or "") or ""
    local detail = clue and (clue.detail or remarks) or ""

    addLabel(stage, name, 908, 180, 284, 40, 24, { 251, 51, 54, 255 }, scale, { fontWeight = "bold" })
    addLabel(stage, gender, 969, 231, 78, 24, 13, { 233, 211, 190, 255 }, scale)
    addLabel(stage, age, 969, 270, 78, 24, 13, { 233, 211, 190, 255 }, scale)
    addLabel(stage, role, 969, 312, 78, 24, 10, { 233, 211, 190, 255 }, scale, {
        whiteSpace = "nowrap",
        overflow = "hidden",
    })
    addLabel(stage, "备注信息：", 910, 352, 110, 28, 14, { 44, 44, 44, 255 }, scale, {
        fontWeight = "bold",
    })
    addLabel(stage, remarks, 910, 378, 290, 76, 13, { 44, 44, 44, 255 }, scale, {
        whiteSpace = "normal",
    })
    addLabel(stage, "人物详情", 557, 462, 120, 27, 15, { 233, 211, 190, 255 }, scale)
    addLabel(stage, detail, 560, 505, 304, 145, 13, { 62, 62, 62, 255 }, scale, {
        whiteSpace = "normal",
    })
    addLabel(stage, "获取时间", 898, 542, 104, 25, 13, { 233, 211, 190, 255 }, scale)
    addLabel(stage, clue and chapterLabel(clue.chapter) or "", 905, 582, 282, 58, 14,
        { 62, 62, 62, 255 }, scale, { whiteSpace = "normal" })

    if clue then addMarkHint(stage, scale, GameData, 552, 425, 300) end
    addImage(stage, "stamp.png", 1113, 586, 126, 126, scale, 18)
end

function M.BuildUI()
    local GameData = require("scripts.GameData")
    local layout = getLayoutMetrics()

    if M.ui.root then
        M.ui.root:Destroy()
        M.ui.root = nil
    end
    M.ui.tabButtons = {}
    M.ui.listItems = {}
    M.ui.detailImage = nil
    M.state.layoutSignature = layout.signature

    M.ui.root = UI.Panel {
        position = "absolute",
        left = 0,
        top = 0,
        width = "100%",
        height = "100%",
        backgroundColor = { 0, 0, 0, 245 },
        zIndex = 50000,
    }

    local stage = UI.Panel {
        position = "absolute",
        left = layout.left,
        top = layout.top,
        width = layout.width,
        height = layout.height,
        backgroundColor = { 0, 0, 0, 255 },
        overflow = "visible",
        zIndex = 1,
    }
    M.ui.root:AddChild(stage)
    M.ui.stage = stage

    local scale = layout.scale
    addImage(stage, "top_background.png", 0, 0, 1251, 91, scale, 2)
    addImage(stage, "left_panel.png", 0, 101, 467, 630, scale, 2)
    addImage(stage, "paper_panel.png", 467, 76, 790, 655, scale, 2)
    addImage(stage, "title_logo.png", 13, 9, 216, 58, scale, 4)

    addTabs(stage, scale)
    addList(stage, scale, GameData)

    stage:AddChild(UI.Button(absoluteProps(1060, 20, 184, 44, scale, {
        text = "ESC/Tab 退出",
        fontSize = fontSize(20, scale),
        fontColor = { 233, 211, 190, 255 },
        textAlign = "right",
        padding = 0,
        borderWidth = 0,
        backgroundColor = { 0, 0, 0, 0 },
        hoverBackgroundColor = { 255, 255, 255, 12 },
        pressedBackgroundColor = { 255, 255, 255, 20 },
        zIndex = 30,
        onClick = function()
            M.Close()
        end,
    })))

    local selectedClue = M.GetSelectedClue()
    if currentTab().id == "personnel" then
        addPersonnelDetail(stage, scale, GameData, selectedClue)
    else
        addEvidenceDetail(stage, scale, GameData, selectedClue)
    end

    if selectedClue and GameData.GameState.readClues[selectedClue.id] ~= true then
        GameData.MarkClueRead(selectedClue.id)
    end

    local uiRoot = UI.GetRoot()
    if uiRoot then uiRoot:AddChild(M.ui.root) end
end

function M.SelectCategory(index)
    if index < 1 or index > #TAB_DEFINITIONS then return end
    M.state.categoryIndex = index
    M.state.filterStarredOnly = false
    M.state.selectedIndex = 1
    M.RefreshVisibleList()
    M.BuildUI()
end

function M.SelectClue(index)
    if index < 1 or index > #M.state.visibleClues then return end
    M.state.selectedIndex = index
    M.BuildUI()
end

function M.ToggleSelectedStar()
    local GameData = require("scripts.GameData")
    local clue = M.GetSelectedClue()
    if not clue then return end
    GameData.ToggleClueStarred(clue.id)
    if M.state.filterStarredOnly then M.RefreshVisibleList() end
    M.BuildUI()
end

function M.ShowImagePreview(imagePath)
    if not imagePath then return end
    local uiRoot = UI.GetRoot()
    if not uiRoot then return end
    if M.imagePreviewOverlay then M.imagePreviewOverlay:Destroy() end

    local overlay = UI.Panel {
        position = "absolute",
        left = 0,
        top = 0,
        width = "100%",
        height = "100%",
        backgroundColor = { 0, 0, 0, 232 },
        zIndex = 100000,
        cursor = "pointer",
        onClick = function()
            M.CloseImagePreview(M.imagePreviewOverlay)
        end,
    }
    overlay:AddChild(UI.Panel {
        position = "absolute",
        left = "8%",
        top = "8%",
        width = "84%",
        height = "82%",
        backgroundImage = toResourcePath(imagePath),
        backgroundFit = "contain",
        backgroundColor = { 0, 0, 0, 0 },
        pointerEvents = "none",
    })
    overlay:AddChild(UI.Label {
        position = "absolute",
        right = 24,
        top = 20,
        text = "点击任意处关闭",
        fontSize = 16,
        fontColor = { 233, 211, 190, 255 },
        pointerEvents = "none",
    })
    uiRoot:AddChild(overlay)
    M.imagePreviewOverlay = overlay
end

function M.CloseImagePreview(overlay)
    if overlay and overlay.Destroy then overlay:Destroy() end
    if M.imagePreviewOverlay == overlay then M.imagePreviewOverlay = nil end
end

function M.GetSelectedClue()
    return M.state.visibleClues[M.state.selectedIndex]
end

function M.GetCategoryById(categoryId)
    local GameData = require("scripts.GameData")
    for _, category in ipairs(GameData.ClueCategories) do
        if category.id == categoryId then return category end
    end
    return nil
end

function M.CountUnreadInCategory(categoryId)
    local GameData = require("scripts.GameData")
    local count = 0
    for _, clue in pairs(GameData.Clues) do
        if clue.category == categoryId and GameData.HasClue(clue.id) then
            if GameData.GameState.readClues[clue.id] ~= true then count = count + 1 end
        end
    end
    return count
end

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

function M.Update(deltaTime)
    if not M.state.isOpen then return end

    M.state.layoutPollTimer = M.state.layoutPollTimer + (deltaTime or 0)
    if M.state.layoutPollTimer >= 0.5 then
        M.state.layoutPollTimer = 0
        if getLayoutMetrics().signature ~= M.state.layoutSignature then
            M.BuildUI()
            return
        end
    end

    if input:GetKeyPress(KEY_Q) or input:GetKeyPress(KEY_LEFT) then
        local index = M.state.categoryIndex - 1
        if index < 1 then index = #TAB_DEFINITIONS end
        M.SelectCategory(index)
        return
    end
    if input:GetKeyPress(KEY_E) or input:GetKeyPress(KEY_RIGHT) then
        local index = M.state.categoryIndex + 1
        if index > #TAB_DEFINITIONS then index = 1 end
        M.SelectCategory(index)
        return
    end

    local listCount = #M.state.visibleClues
    if listCount > 0 then
        if input:GetKeyPress(KEY_W) or input:GetKeyPress(KEY_UP) then
            local index = M.state.selectedIndex - 1
            if index < 1 then index = listCount end
            M.SelectClue(index)
            return
        end
        if input:GetKeyPress(KEY_S) or input:GetKeyPress(KEY_DOWN) then
            local index = M.state.selectedIndex + 1
            if index > listCount then index = 1 end
            M.SelectClue(index)
            return
        end
    end

    if input:GetKeyPress(KEY_F) then M.ToggleSelectedStar() end
end

return M
