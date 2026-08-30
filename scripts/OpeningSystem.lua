-- ============================================================================
-- OpeningSystem.lua - 开场动画系统
-- 文档 3.1 / 第二阶段 1.1
-- 流程：黑屏显示"时间 / 地点"3秒（淡出） -> 依次播放分镜对话 -> 完成回调
-- ============================================================================

local UI = require("urhox-libs.UI")

local M = {}

M.state = {
    active = false,
    phase = "location",     -- location(显示时间地点) / dialogue(播放对话) / done
    timer = 0,
    opening = nil,
    dialogueIndex = 1,
    onComplete = nil,
    transition = nil,       -- 镜头切换过渡 { t, dur, from, to }
}

M.ui = {
    root = nil,
    timeLabel = nil,
    locationLabel = nil,
    -- 分镜画面：双缓冲，切换时前后景交叉淡入淡出实现"镜头切换"
    shotA = nil,
    shotB = nil,
    shotFront = nil,
    shotBack = nil,
}

-- 默认镜头切换时长（秒）
local DEFAULT_SHOT_FADE = 0.6
-- 行内镜头切换时长（秒）：同一分镜内换景别，比整镜切换更快
local LINE_SHOT_FADE = 0.35

-- 每个分镜的轻微推拉和横移，避免背景只做静态交叉淡入。
-- x/y 是镜头在可移动范围内的归一化焦点位置，zoom 为背景缩放倍率。
local CAMERA_PRESETS = {
    opening_prologue_1 = { from = { zoom = 1.00, x = 0.35, y = 0.48 }, to = { zoom = 1.06, x = 0.52, y = 0.46 } },
    opening_prologue_2 = { from = { zoom = 1.04, x = 0.68, y = 0.48 }, to = { zoom = 1.10, x = 0.46, y = 0.46 } },
    opening_prologue_3 = { from = { zoom = 1.02, x = 0.38, y = 0.48 }, to = { zoom = 1.12, x = 0.52, y = 0.44 } },
    opening_prologue_4 = { from = { zoom = 1.06, x = 0.64, y = 0.46 }, to = { zoom = 1.02, x = 0.42, y = 0.48 } },
    opening_prologue_5 = { from = { zoom = 1.00, x = 0.54, y = 0.48 }, to = { zoom = 1.08, x = 0.44, y = 0.44 } },
    opening_prologue_5_after = { from = { zoom = 1.08, x = 0.44, y = 0.44 }, to = { zoom = 1.12, x = 0.58, y = 0.42 } },
    opening_chapter1_1 = { from = { zoom = 1.02, x = 0.40, y = 0.48 }, to = { zoom = 1.08, x = 0.52, y = 0.46 } },
    opening_chapter1_2 = { from = { zoom = 1.05, x = 0.70, y = 0.46 }, to = { zoom = 1.02, x = 0.42, y = 0.48 } },
    opening_chapter1_3 = { from = { zoom = 1.00, x = 0.24, y = 0.48 }, to = { zoom = 1.08, x = 0.56, y = 0.44 } },
    opening_chapter1_4 = { from = { zoom = 1.04, x = 0.62, y = 0.46 }, to = { zoom = 1.10, x = 0.44, y = 0.44 } },
    opening_chapter1_5 = { from = { zoom = 1.02, x = 0.52, y = 0.48 }, to = { zoom = 1.08, x = 0.66, y = 0.44 } },
}

-- 诊断角标开关：画面左上角显示当前分镜信息，验证无误后置 false
M.debugCorner = true

-- ============================================================================
-- 启动开场动画
-- ============================================================================
function M.Start(openingId, onComplete)
    local GameData = require("scripts.GameData")
    local opening = GameData.GetOpening(openingId)
    if not opening then
        if onComplete then onComplete() end
        return
    end

    M.state.active = true
    M.state.phase = "location"
    M.state.timer = 0
    M.state.opening = opening
    M.state.dialogueIndex = 1
    M.state.onComplete = onComplete

    M.BuildLocationUI()
end

-- ============================================================================
-- 停止（清理）
-- ============================================================================
function M.Stop()
    M.state.active = false
    M.state.phase = "done"
    M.DestroyUI()
end

function M.IsActive()
    return M.state.active
end

-- 跳过按钮：挂到 UI.GetRoot() 最顶层，确保不被 DialogueSystem 全屏面板遮挡
local function _AddSkipButton()
    local uiRoot = UI.GetRoot()
    if not uiRoot then return nil end
    local btn = UI.Button {
        position = "absolute",
        top = 16, right = 16,
        width = 64, height = 34,
        backgroundColor = { 0, 0, 0, 130 },
        borderWidth = 1, borderColor = { 255, 255, 255, 100 },
        borderRadius = 6,
        text = "跳过 ›",
        fontColor = { 255, 255, 255, 230 },
        fontSize = 16,
        zIndex = 99999,
        onClick = function(self, event)
            M.Finish()
        end,
    }
    uiRoot:AddChild(btn)
    return btn
end

-- ============================================================================
-- 显示时间地点黑屏UI
-- ============================================================================
function M.BuildLocationUI()
    M.DestroyUI()

    local opening = M.state.opening or { time = "", location = "" }
    local firstBg = M.GetOpeningDialogueBackground(1)

    M.ui.root = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 6, 5, 12, 255 },
        backgroundImage = firstBg,
        backgroundFit = "cover",
        flexDirection = "column",
        alignItems = "center",
        justifyContent = "center",
        gap = 18,
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
    }

    -- 暗化遮罩：保证时间/地点文字可读
    local overlay = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 0, 0, 0, 150 },
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
    }
    M.ui.root:AddChild(overlay)

    M.ui.timeLabel = UI.Label {
        text = opening.time or "",
        fontSize = 34,
        fontColor = { 230, 225, 215, 255 },
        fontWeight = "bold",
        textAlign = "center",
    }
    M.ui.root:AddChild(M.ui.timeLabel)

    M.ui.locationLabel = UI.Label {
        text = opening.location or "",
        fontSize = 22,
        fontColor = { 180, 175, 165, 255 },
        textAlign = "center",
    }
    M.ui.root:AddChild(M.ui.locationLabel)

    local uiRoot = UI.GetRoot()
    if uiRoot then uiRoot:AddChild(M.ui.root) end
    M._skipBtn = _AddSkipButton()
end

function M.DestroyUI()
    if M._skipBtn then
        M._skipBtn:Destroy()
        M._skipBtn = nil
    end
    if M.ui.root then
        M.ui.root:Destroy()
        M.ui.root = nil
    end
    M.DestroyShotPanels()
    M.ui.timeLabel = nil
    M.ui.locationLabel = nil
end

-- ============================================================================
-- 分镜画面（镜头）
-- 一个"镜头" = 全屏背景图 + 暗化遮罩 + 角色立绘层
-- 双缓冲：切换时前后景交叉淡入淡出，做出真正的镜头切换，而不是瞬间换图
-- ============================================================================

local function _EaseInOut(t)
    if t < 0.5 then return 2 * t * t end
    return 1 - ((-2 * t + 2) ^ 2) / 2
end

local function _CopyCamera(camera)
    return {
        zoom = camera.zoom or 1.0,
        x = camera.x or 0.5,
        y = camera.y or 0.5,
    }
end

local function _SetCamera(panel, camera)
    if not panel or not panel._scene then return end
    local sw, sh = graphics:GetWidth(), graphics:GetHeight()
    local zoom = camera.zoom or 1.0
    local sceneW, sceneH = sw * zoom, sh * zoom
    local maxX, maxY = sceneW - sw, sceneH - sh
    local left = -maxX * (camera.x or 0.5)
    local top = -maxY * (camera.y or 0.5)
    pcall(function()
        panel._scene:SetStyle({ left = left, top = top, width = sceneW, height = sceneH })
    end)
end

local function _GetCameraPlan(dialogueId)
    return CAMERA_PRESETS[dialogueId] or {
        from = { zoom = 1.01, x = 0.42, y = 0.48 },
        to = { zoom = 1.06, x = 0.58, y = 0.45 },
    }
end

local function _StartCamera(panel, dialogueId, duration, lineShot)
    if not panel then return end
    local plan = _GetCameraPlan(dialogueId)
    local from = _CopyCamera(plan.from)
    local to = _CopyCamera(plan.to)
    if lineShot then
        from.zoom = math.max(from.zoom, 1.04)
        to.zoom = math.max(to.zoom, from.zoom + 0.02)
    end
    panel._camera = {
        t = 0,
        dur = math.max(duration or 0, lineShot and 2.2 or 3.4),
        from = from,
        to = to,
    }
    _SetCamera(panel, from)
end

local function _UpdateCamera(panel, deltaTime)
    local camera = panel and panel._camera
    if not camera then return end
    camera.t = math.min(camera.t + deltaTime, camera.dur)
    local k = _EaseInOut(camera.dur > 0 and camera.t / camera.dur or 1)
    local current = {
        zoom = camera.from.zoom + (camera.to.zoom - camera.from.zoom) * k,
        x = camera.from.x + (camera.to.x - camera.from.x) * k,
        y = camera.from.y + (camera.to.y - camera.from.y) * k,
    }
    _SetCamera(panel, current)
end

function M.CreateShotPanel()
    local panel = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 6, 5, 12, 255 },
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        overflow = "hidden",
        pointerEvents = "none",
    }
    local scene = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 6, 5, 12, 255 },
        backgroundFit = "cover",
        position = "absolute",
        top = 0, left = 0,
        pointerEvents = "none",
    }
    panel:AddChild(scene)
    panel._scene = scene
    local content = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 0, 0, 0, 0 },
        position = "absolute",
        top = 0, left = 0,
        pointerEvents = "none",
    }
    scene:AddChild(content)
    panel._content = content
    return panel
end

-- 把某个分镜的内容（背景 + 角色站位）填进镜头面板
function M.FillShot(panel, dialogueId, overrideBg)
    if not panel then return end
    local GameData = require("scripts.GameData")

    local dlg = GameData.GetDialogue(dialogueId)
    -- overrideBg：行内切镜头时只换背景，角色站位沿用当前分镜
    local bg = overrideBg
    if not bg or bg == "" then
        bg = (dlg and dlg.background and dlg.background ~= "") and dlg.background or ""
    end
    pcall(function() panel._scene:SetStyle({ backgroundImage = bg, backgroundFit = "cover" }) end)
    print(string.format("[OPEN DEBUG] FillShot: id=%s bg=%s", tostring(dialogueId), tostring(bg)))

    if panel._content then
        pcall(function() panel._content:Destroy() end)
    end
    local content = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 0, 0, 0, 0 },
        position = "absolute",
        top = 0, left = 0,
        pointerEvents = "none",
    }
    panel._scene:AddChild(content)
    panel._content = content

    -- 暗化遮罩：保证对话文字可读
    content:AddChild(UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 0, 0, 0, 150 },
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
    })

    local shot = GameData.OpeningShots and GameData.OpeningShots[dialogueId]
    local sw, sh = graphics:GetWidth(), graphics:GetHeight()

    if shot and shot.actors then
        for _, a in ipairs(shot.actors) do
            local h = a.h or 0.5
            local ratio = a.ratio or 0.671
            content:AddChild(UI.Panel {
                position = "absolute",
                left = string.format("%.3f%%", ((a.x or 0.5) - ratio * h / 2) * 100),
                top = string.format("%.3f%%", ((a.y or 0.9) - h) * 100),
                width = string.format("%.3f%%", ratio * h * 100),
                height = string.format("%.3f%%", h * 100),
                backgroundImage = a.sprite,
                backgroundFit = "contain",
                backgroundColor = { 0, 0, 0, 0 },
            })
        end
    end

    -- 诊断角标：用于确认分镜代码是否真的执行、背景取到的是哪张图
    if M.debugCorner then
        local shortBg = tostring(bg):match("([^/]+)$") or "?"
        content:AddChild(UI.Label {
            position = "absolute",
            left = 12, top = 10, width = 820, height = 26,
            text = string.format("[分镜] %s | %s | 角色%d | %dx%d",
                tostring(dialogueId), shortBg, shot and #shot.actors or 0, sw, sh),
            fontSize = 14, fontColor = { 255, 220, 120, 235 },
        })
    end
end

-- 切到指定分镜：后景填好内容后与前景交叉淡入淡出
function M.TransitionToShot(dialogueId)
    local front, back = M.ui.shotFront, M.ui.shotBack
    if not (front and back) then return end
    local GameData = require("scripts.GameData")
    local shot = GameData.OpeningShots and GameData.OpeningShots[dialogueId]
    local dur = (shot and shot.transitionDur) or DEFAULT_SHOT_FADE

    -- 记录当前分镜：行内切镜头时需沿用它的角色站位
    M.state.currentShotId = dialogueId
    M.state.currentLineBg = nil

    M.FillShot(back, dialogueId)
    _StartCamera(back, dialogueId, dur, false)
    back:SetStyle({ opacity = 0 })
    front:SetStyle({ opacity = 1 })
    M.state.transition = { t = 0, dur = dur, from = front, to = back }
    print(string.format("[OPEN DEBUG] 镜头切换 -> %s (%.2fs)", tostring(dialogueId), dur))
end

-- 行内镜头切换：同一分镜内，台词推进到配置了不同背景的行时交叉淡入换镜。
-- 只换背景，角色站位沿用当前分镜（currentShotId），避免人物跟着背景一起跳。
function M.TransitionToLineShot(bg)
    if not M.state.active then return end
    if not bg or bg == "" then return end
    if bg == M.state.currentLineBg then return end

    local front, back = M.ui.shotFront, M.ui.shotBack
    if not (front and back) then return end

    M.state.currentLineBg = bg
    M.FillShot(back, M.state.currentShotId, bg)
    _StartCamera(back, M.state.currentShotId, LINE_SHOT_FADE, true)
    back:SetStyle({ opacity = 0 })
    front:SetStyle({ opacity = 1 })
    M.state.transition = { t = 0, dur = LINE_SHOT_FADE, from = front, to = back }
    print(string.format("[OPEN DEBUG] 行内切镜头 -> %s", tostring(bg):match("([^/]+)$") or tostring(bg)))
end

function M.DestroyShotPanels()
    for _, k in ipairs({ "shotA", "shotB" }) do
        local p = M.ui[k]
        if p then
            pcall(function() p:Destroy() end)
            M.ui[k] = nil
        end
    end
    M.ui.shotFront, M.ui.shotBack = nil, nil
    M.state.transition = nil
end

-- 读取当前过场分镜（按 dialogueIndex）对应的背景图
function M.GetCurrentDialogueBackground()
    local GameData = require("scripts.GameData")
    local dialogues = (M.state.opening and M.state.opening.dialogues) or {}
    local id = dialogues[M.state.dialogueIndex]
    if not id then return nil end
    local dlg = GameData.GetDialogue(id)
    if dlg and dlg.background and dlg.background ~= "" then
        return dlg.background
    end
    return nil
end

-- 读取指定序号过场分镜的背景图（用于 location 阶段显示首图）
function M.GetOpeningDialogueBackground(index)
    local GameData = require("scripts.GameData")
    local dialogues = (M.state.opening and M.state.opening.dialogues) or {}
    local id = dialogues[index]
    if not id then return nil end
    local dlg = GameData.GetDialogue(id)
    if dlg and dlg.background and dlg.background ~= "" then
        return dlg.background
    end
    return nil
end

-- 对话阶段：建立双缓冲镜头并显示第一镜
function M.BuildBackdrop()
    M.DestroyShotPanels()
    M.ui.shotA = M.CreateShotPanel()
    M.ui.shotB = M.CreateShotPanel()
    local uiRoot = UI.GetRoot()
    if uiRoot then
        uiRoot:AddChild(M.ui.shotA)
        uiRoot:AddChild(M.ui.shotB)
    end
    M.ui.shotFront = M.ui.shotA
    M.ui.shotBack = M.ui.shotB

    local firstId = (M.state.opening and M.state.opening.dialogues or {})[1]
    M.FillShot(M.ui.shotFront, firstId)
    _StartCamera(M.ui.shotFront, firstId, 0, false)
    M.ui.shotFront:SetStyle({ opacity = 1 })
    M.ui.shotBack:SetStyle({ opacity = 0 })
    M._skipBtn = _AddSkipButton()
end

-- ============================================================================
-- 更新
-- ============================================================================
function M.Update(deltaTime)
    if not M.state.active then return end

    _UpdateCamera(M.ui.shotFront, deltaTime)
    if M.ui.shotBack ~= M.ui.shotFront then
        _UpdateCamera(M.ui.shotBack, deltaTime)
    end

    -- 镜头切换过渡：前后景交叉淡入淡出
    local tr = M.state.transition
    if tr then
        tr.t = tr.t + deltaTime
        local k = (tr.dur > 0) and (tr.t / tr.dur) or 1
        if k > 1 then k = 1 end
        pcall(function() tr.to:SetStyle({ opacity = k }) end)
        pcall(function() tr.from:SetStyle({ opacity = 1 - k }) end)
        if k >= 1 then
            -- 刚淡入的成为新的前景，原前景转为待用的后景
            M.ui.shotFront, M.ui.shotBack = tr.to, tr.from
            M.state.transition = nil
        end
    end

    local GameData = require("scripts.GameData")
    local DialogueSystem = require("scripts.DialogueSystem")

    if M.state.phase == "location" then
        M.state.timer = M.state.timer + deltaTime
        local duration = M.state.opening.duration or 3.0
        local fadeStart = duration - 0.5

        -- 淡出效果
        if M.state.timer >= fadeStart and fadeStart > 0 then
            local alpha = 255 * (1 - (M.state.timer - fadeStart) / 0.5)
            if alpha < 0 then alpha = 0 end
            if alpha > 255 then alpha = 255 end
            if M.ui.timeLabel then
                M.ui.timeLabel:SetStyle({ fontColor = { 230, 225, 215, math.floor(alpha) } })
            end
            if M.ui.locationLabel then
                M.ui.locationLabel:SetStyle({ fontColor = { 180, 175, 165, math.floor(alpha) } })
            end
        end

        if M.state.timer >= duration then
            -- 进入对话阶段：显示暗色背景避免透出旧场景
            M.DestroyUI()
            M.BuildBackdrop()
            M.state.phase = "dialogue"
            M.PlayNextDialogue()
        end
        return
    end

    if M.state.phase == "dialogue" then
        -- 对话由 DialogueSystem 驱动，这里等待回调
        return
    end
end

-- ============================================================================
-- 播放下一个对话
-- ============================================================================
function M.PlayNextDialogue()
    local DialogueSystem = require("scripts.DialogueSystem")
    local GameData = require("scripts.GameData")

    local dialogues = M.state.opening.dialogues or {}
    if M.state.dialogueIndex > #dialogues then
        -- 全部播完
        M.Finish()
        return
    end

    local dialogueId = dialogues[M.state.dialogueIndex]
    M.state.dialogueIndex = M.state.dialogueIndex + 1

    -- 镜头切到该分镜：背景 + 角色站位，交叉淡入淡出
    M.TransitionToShot(dialogueId)

    DialogueSystem.Start(dialogueId, function()
        M.PlayNextDialogue()
    end, false)
end

-- ============================================================================
-- 完成
-- ============================================================================
function M.Finish()
    local onComplete = M.state.onComplete
    M.Stop()
    if onComplete then
        onComplete()
    end
end

return M
