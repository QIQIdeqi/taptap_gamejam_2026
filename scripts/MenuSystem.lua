-- ============================================================================
-- MenuSystem.lua - 菜单系统
-- 使用 UrhoX 声明式 UI API
-- ============================================================================

local UI = require("urhox-libs.UI")

local M = {}

M.MenuType = {
    Main = "main",
    Pause = "pause",
    Save = "save",
    Load = "load",
    Settings = "settings",
}

M.currentMenu = nil
M.previousMenu = nil

M.ui = { root = nil }
M.callbacks = {}

-- ============================================================================
-- 初始化
-- ============================================================================

function M.Init(callbacks)
    M.callbacks = callbacks or {}
end

-- ============================================================================
-- 清理
-- ============================================================================

function M.ClearMenu()
    if M.ui.root then
        M.ui.root:Destroy()
        M.ui.root = nil
    end
end

-- ============================================================================
-- 显示菜单
-- ============================================================================

function M.ShowMenu(menuType)
    M.ClearMenu()
    M.currentMenu = menuType

    if menuType == M.MenuType.Main then M.ShowMainMenu()
    elseif menuType == M.MenuType.Pause then M.ShowPauseMenu()
    elseif menuType == M.MenuType.Save then M.ShowSaveMenu()
    elseif menuType == M.MenuType.Load then M.ShowLoadMenu()
    elseif menuType == M.MenuType.Settings then M.ShowSettingsMenu()
    end
end

-- ============================================================================
-- 主菜单
-- ============================================================================

function M.ShowMainMenu()
    -- 设计分辨率为 1528x1029；菜单整体固定在左侧安全区，避免按钮落到背景人物和照片上。
    M.ui.root = UI.Panel {
        width = "100%", height = "100%",
        backgroundImage = "image/beijin.png",
        backgroundFit = "cover",
        pointerEvents = "auto",
    }

    local logo = UI.Panel {
        position = "absolute",
        left = 28, top = 18,
        width = 350, height = 176,
        backgroundImage = "image/LOGO.png",
        backgroundFit = "contain",
        pointerEvents = "none",
    }
    M.ui.root:AddChild(logo)

    local function createImageButton(normalImage, hoverImage, top, onClick)
        local button = UI.Panel {
            position = "absolute",
            left = 34, top = top,
            width = 280, height = 72,
            backgroundImage = normalImage,
            backgroundFit = "contain",
            backgroundPosition = "left center",
            backgroundColor = { 0, 0, 0, 0 },
            pointerEvents = "auto",
        }
        button.props.onPointerEnter = function(_, widget)
            widget:SetStyle({ backgroundImage = hoverImage })
        end
        button.props.onPointerLeave = function(_, widget)
            widget:SetStyle({ backgroundImage = normalImage })
        end
        button.props.onClick = onClick
        return button
    end

    -- 四个按钮间隔 18px，不再互相覆盖；按钮高度按素材内容比例收敛。
    M.ui.root:AddChild(createImageButton(
        "image/kaishi.png", "image/kaishi_up.png", 420,
        function()
            if M.callbacks.onNewGame then M.callbacks.onNewGame() end
        end
    ))
    M.ui.root:AddChild(createImageButton(
        "image/duqu.png", "image/duqu_up.png", 510,
        function()
            M.previousMenu = M.MenuType.Main
            M.ShowMenu(M.MenuType.Load)
        end
    ))
    M.ui.root:AddChild(createImageButton(
        "image/shezhi.png", "image/shezhi_up.png", 600,
        function()
            M.previousMenu = M.MenuType.Main
            M.ShowMenu(M.MenuType.Settings)
        end
    ))
    M.ui.root:AddChild(createImageButton(
        "image/tuichu.png", "image/tuichu_up.png", 690,
        function()
            if M.callbacks.onExitGame then M.callbacks.onExitGame() end
        end
    ))

    local uiRoot = UI.GetRoot()
    if uiRoot then uiRoot:AddChild(M.ui.root) end
end

-- ============================================================================
-- 暂停菜单
-- ============================================================================

function M.ShowPauseMenu()
    M.ui.root = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 0, 0, 0, 160 },
        flexDirection = "column",
        justifyContent = "center",
        alignItems = "center",
        gap = 16,
    }

    M.ui.root:AddChild(UI.Label {
        text = "已暂停",
        fontSize = 36,
        fontColor = { 220, 200, 160, 255 },
        textAlign = "center",
    })

    local btnContainer = UI.Panel {
        width = 280,
        flexDirection = "column",
        gap = 10,
        padding = 15,
    }
    M.ui.root:AddChild(btnContainer)

    btnContainer:AddChild(UI.Button {
        text = "继续游戏",
        fontSize = 20,
        width = "100%", height = 42,
        onClick = function() if M.callbacks.onResume then M.callbacks.onResume() end end,
    })

    btnContainer:AddChild(UI.Button {
        text = "保存游戏",
        fontSize = 20,
        width = "100%", height = 42,
        variant = "secondary",
        onClick = function()
            M.previousMenu = M.MenuType.Pause
            M.ShowMenu(M.MenuType.Save)
        end,
    })

    btnContainer:AddChild(UI.Button {
        text = "读取存档",
        fontSize = 20,
        width = "100%", height = 42,
        variant = "secondary",
        onClick = function()
            M.previousMenu = M.MenuType.Pause
            M.ShowMenu(M.MenuType.Load)
        end,
    })

    btnContainer:AddChild(UI.Button {
        text = "设置",
        fontSize = 20,
        width = "100%", height = 42,
        variant = "secondary",
        onClick = function()
            M.previousMenu = M.MenuType.Pause
            M.ShowMenu(M.MenuType.Settings)
        end,
    })

    btnContainer:AddChild(UI.Button {
        text = "返回主菜单",
        fontSize = 20,
        width = "100%", height = 42,
        variant = "secondary",
        onClick = function() if M.callbacks.onExitToMain then M.callbacks.onExitToMain() end end,
    })

    btnContainer:AddChild(UI.Button {
        text = "退出游戏",
        fontSize = 20,
        width = "100%", height = 42,
        variant = "danger",
        onClick = function() if M.callbacks.onExitGame then M.callbacks.onExitGame() end end,
    })

    local uiRoot = UI.GetRoot()
    if uiRoot then uiRoot:AddChild(M.ui.root) end
end

-- ============================================================================
-- 存档菜单
-- ============================================================================

function M.ShowSaveMenu()
    local SaveSystem = require("scripts.SaveSystem")

    M.ui.root = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 20, 15, 30, 230 },
        flexDirection = "column",
        padding = 30,
        gap = 8,
    }

    M.ui.root:AddChild(UI.Label {
        text = "保存游戏",
        fontSize = 28,
        fontColor = { 220, 200, 160, 255 },
        textAlign = "center",
    })

    -- 可滚动列表
    local scroll = UI.ScrollView {
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
        scrollY = true,
    }
    M.ui.root:AddChild(scroll)

    local listPanel = UI.Panel {
        width = "100%",
        flexDirection = "column",
        gap = 8,
    }
    scroll:AddChild(listPanel)

    local slots = SaveSystem.GetAllSlotsInfo()
    for _, info in ipairs(slots) do
        listPanel:AddChild(M.CreateSlotButton(info, true))
    end

    M.ui.root:AddChild(UI.Button {
        text = "返回",
        fontSize = 18,
        width = 200, height = 38,
        onClick = function()
            M.ShowMenu(M.previousMenu or M.MenuType.Pause)
        end,
    })

    local uiRoot = UI.GetRoot()
    if uiRoot then uiRoot:AddChild(M.ui.root) end
end

-- ============================================================================
-- 读档菜单
-- ============================================================================

function M.ShowLoadMenu()
    local SaveSystem = require("scripts.SaveSystem")

    M.ui.root = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 20, 15, 30, 230 },
        flexDirection = "column",
        padding = 30,
        gap = 8,
    }

    M.ui.root:AddChild(UI.Label {
        text = "读取存档",
        fontSize = 28,
        fontColor = { 220, 200, 160, 255 },
        textAlign = "center",
    })

    local scroll = UI.ScrollView {
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
        scrollY = true,
    }
    M.ui.root:AddChild(scroll)

    local listPanel = UI.Panel {
        width = "100%",
        flexDirection = "column",
        gap = 8,
    }
    scroll:AddChild(listPanel)

    local slots = SaveSystem.GetAllSlotsInfo()
    for _, info in ipairs(slots) do
        listPanel:AddChild(M.CreateSlotButton(info, false))
    end

    M.ui.root:AddChild(UI.Button {
        text = "返回",
        fontSize = 18,
        width = 200, height = 38,
        onClick = function()
            M.ShowMenu(M.previousMenu or M.MenuType.Main)
        end,
    })

    local uiRoot = UI.GetRoot()
    if uiRoot then uiRoot:AddChild(M.ui.root) end
end

-- ============================================================================
-- 创建存档槽位按钮
-- ============================================================================

function M.CreateSlotButton(info, isSaveMode)
    local SaveSystem = require("scripts.SaveSystem")

    local text
    if info.isEmpty then
        local label = info.isAuto and "自动存档" or ("存档槽 " .. (info.slotNumber or "?"))
        text = label .. "  [空]"
    else
        local label = info.isAuto and "自动" or ("#" .. (info.slotNumber or "?"))
        local timeStr = SaveSystem.FormatPlayTime(info.playTime)
        text = string.format("%s | %s - %s | %s | %s",
            label, info.chapterTitle or "", info.sceneName or "", timeStr, info.saveTime or "")
    end

    local container = UI.Panel {
        width = "100%",
        flexDirection = "row",
        gap = 8,
        alignItems = "center",
    }

    if not info.isEmpty and info.sceneImage then
        container:AddChild(UI.Panel {
            width = 120, height = 55,
            backgroundImage = info.sceneImage,
            backgroundFit = "cover",
            backgroundColor = { 0, 0, 0, 60 },
            borderRadius = 6,
        })
    end

    local btn = UI.Button {
        text = text,
        fontSize = 16,
        flexGrow = 1, height = 55,
        variant = "secondary",
        onClick = function()
            if isSaveMode then
                if info.isEmpty then
                    if M.callbacks.onSaveGame then M.callbacks.onSaveGame(info.slotId) end
                    M.ShowMenu(M.MenuType.Save)
                else
                    M.ShowOverwriteConfirm(info.slotId)
                end
            else
                if not info.isEmpty then
                    if M.callbacks.onLoadGame then M.callbacks.onLoadGame(info.slotId) end
                end
            end
        end,
    }
    container:AddChild(btn)

    if (not info.isEmpty) and (not info.isAuto) then
        container:AddChild(UI.Button {
            text = "删除",
            fontSize = 14, width = 70, height = 55,
            backgroundColor = { 120, 40, 40, 255 },
            fontColor = { 255, 255, 255, 255 },
            onClick = function()
                M.ShowDeleteConfirm(info.slotId)
            end,
        })
    end

    return container
end

-- ============================================================================
-- 覆写确认
-- ============================================================================

function M.ShowOverwriteConfirm(slotId)
    M.ShowConfirmDialog("该存档槽已有数据，是否覆写？", function()
        if M.callbacks.onSaveGame then M.callbacks.onSaveGame(slotId) end
        M.ShowMenu(M.MenuType.Save)
    end, function()
        M.ShowMenu(M.MenuType.Save)
    end)
end

-- ============================================================================
-- 删除确认
-- ============================================================================

function M.ShowDeleteConfirm(slotId)
    M.ShowConfirmDialog("确认删除该存档？此操作不可恢复。", function()
        local SaveSystem = require("scripts.SaveSystem")
        SaveSystem.DeleteSlot(slotId)
        M.ShowMenu(M.MenuType.Save)
    end, function()
        M.ShowMenu(M.MenuType.Save)
    end)
end

-- ============================================================================
-- 通用确认弹窗
-- ============================================================================

function M.ShowConfirmDialog(message, onConfirm, onCancel)
    M.ClearMenu()

    M.ui.root = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 0, 0, 0, 160 },
        flexDirection = "column",
        justifyContent = "center",
        alignItems = "center",
    }

    local panel = UI.Panel {
        width = 400,
        backgroundColor = { 30, 25, 40, 255 },
        borderRadius = 12,
        borderWidth = 1,
        borderColor = { 100, 90, 120, 200 },
        flexDirection = "column",
        gap = 20,
        padding = 25,
        shadowBlur = 20,
        shadowColor = { 0, 0, 0, 100 },
    }
    M.ui.root:AddChild(panel)

    panel:AddChild(UI.Label {
        text = message,
        fontSize = 20,
        fontColor = { 240, 240, 240, 255 },
        whiteSpace = "normal",
        textAlign = "center",
    })

    local btnRow = UI.Panel {
        flexDirection = "row",
        gap = 20,
        justifyContent = "center",
    }
    panel:AddChild(btnRow)

    btnRow:AddChild(UI.Button {
        text = "确认",
        fontSize = 18,
        width = 120, height = 40,
        onClick = function() if onConfirm then onConfirm() end end,
    })

    btnRow:AddChild(UI.Button {
        text = "取消",
        fontSize = 18,
        width = 120, height = 40,
        variant = "secondary",
        onClick = function() if onCancel then onCancel() end end,
    })

    local uiRoot = UI.GetRoot()
    if uiRoot then uiRoot:AddChild(M.ui.root) end
end

-- ============================================================================
-- 设置菜单
-- ============================================================================

function M.ShowSettingsMenu()
    M.ui.root = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 20, 15, 30, 230 },
        flexDirection = "column",
        justifyContent = "center",
        alignItems = "center",
        gap = 16,
    }

    M.ui.root:AddChild(UI.Label {
        text = "设置",
        fontSize = 28,
        fontColor = { 220, 200, 160, 255 },
        textAlign = "center",
    })

    local volPanel = UI.Panel {
        flexDirection = "row",
        gap = 20,
        alignItems = "center",
        padding = 10,
    }
    M.ui.root:AddChild(volPanel)

    volPanel:AddChild(UI.Label {
        text = "音量",
        fontSize = 18,
    })

    volPanel:AddChild(UI.Slider {
        value = 70, min = 0, max = 100,
        width = 200, height = 20,
        onChange = function(_self, value)
            audio:SetMasterGain(SOUND_MASTER, value / 100)
        end,
    })

    M.ui.root:AddChild(UI.Button {
        text = "返回",
        fontSize = 18,
        width = 200, height = 40,
        onClick = function()
            M.ShowMenu(M.previousMenu or M.MenuType.Main)
        end,
    })

    local uiRoot = UI.GetRoot()
    if uiRoot then uiRoot:AddChild(M.ui.root) end
end

-- ============================================================================
-- 关闭/检查
-- ============================================================================

function M.Close()
    M.ClearMenu()
    M.currentMenu = nil
end

function M.IsOpen()
    return M.currentMenu ~= nil
end

return M
