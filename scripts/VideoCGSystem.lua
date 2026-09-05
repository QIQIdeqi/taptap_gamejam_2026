-- ============================================================================
-- VideoCGSystem.lua - 片头 CG 视频播放系统
-- 文档：engine-docs/recipes/video.md
-- 流程：全屏播放 mp4 动画 -> onEnded / 点击跳过 -> onComplete 回调
-- ============================================================================

local UI = require("urhox-libs.UI")
local Video = require("urhox-libs/Video")

local M = {}

M.state = {
    active = false,
    onComplete = nil,
    panel = nil,
    player = nil,
    finishing = false,   -- 防重入：onEnded 与点击跳过可能同时触发
    subtitles = nil,     -- 字幕表：{ {start=秒, finish=秒, speaker="李志", text="..."}, ... }
    subtitleLabel = nil, -- 底部字幕 Label
}

function M.IsSupported()
    return Video.isSupported == true
end

function M.IsActive()
    return M.state.active
end

-- 播放 CG 视频；src 为资源路径（如 "assets/video/opening_cg.mp4"）
-- opts.subtitles 可选：{ {start=秒, finish=秒, speaker="李志", text="..."}, ... }
-- 视频不支持 / 根节点缺失时直接回调 onComplete，保证流程不断
function M.Play(src, onComplete, opts)
    opts = opts or {}

    if not M.IsSupported() then
        print("[CG] 视频播放不支持（非 WASM 平台），跳过 CG")
        if onComplete then onComplete() end
        return false
    end

    local uiRoot = UI.GetRoot()
    if not uiRoot then
        print("[CG] UI 根节点缺失，跳过 CG")
        if onComplete then onComplete() end
        return false
    end

    M.Stop()

    M.state.active = true
    M.state.finishing = false
    M.state.onComplete = onComplete
    M.state.subtitles = opts.subtitles

    local player = nil

    -- 全屏面板：拦截点击（跳过）+ 挂载 VideoPlayer
    local panel = UI.Panel({
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = { 0, 0, 0, 255 },
        zIndex = 99998,
    })

    -- 透明点击层：VideoPlayer 自带点击播放/暂停，需在其上放一层拦截实现"点击跳过"
    local tapLayer = UI.Panel({
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = { 0, 0, 0, 0 },
        zIndex = 99999,
        onClick = function(self, event)
            M.Finish()
        end,
    })

    player = Video.VideoPlayer({
        src = src,
        width = "100%", height = "100%",
        autoPlay = true,
        loop = false,
        muted = true,
        volume = 0,
        objectFit = "contain",
        backgroundColor = { 0, 0, 0, 255 },
        onReady = function(self)
            print("[CG] 视频就绪：" .. tostring(src))
        end,
        onEnded = function(self)
            print("[CG] 视频播放结束")
            M.Finish()
        end,
        onTimeUpdate = function(self, time, duration)
            M.UpdateSubtitle(time)
        end,
    })

    panel:AddChild(player)
    panel:AddChild(tapLayer)

    -- 底部字幕层（穿透点击，仅显示）
    if M.state.subtitles and #M.state.subtitles > 0 then
        local subContainer = UI.Panel({
            position = "absolute",
            left = 0, right = 0, bottom = 64,
            alignItems = "center",
            justifyContent = "center",
            backgroundColor = { 0, 0, 0, 0 },
            pointerEvents = "none",
            zIndex = 100000,
        })
        local subLabel = UI.Label({
            text = "",
            fontSize = 24,
            fontColor = { 255, 255, 255, 255 },
            textAlign = "center",
            whiteSpace = "normal",
            lineHeight = 1.5,
            paddingLeft = 24, paddingRight = 24, paddingTop = 12, paddingBottom = 12,
            backgroundColor = { 0, 0, 0, 150 },
            borderRadius = 8,
            textShadow = { offsetX = 0, offsetY = 2, blur = 4, color = { 0, 0, 0, 200 } },
            maxWidth = "80%",
            pointerEvents = "none",
        })
        subContainer:AddChild(subLabel)
        panel:AddChild(subContainer)
        M.state.subtitleLabel = subLabel
        subLabel:SetVisible(false)
    end

    -- 跳过提示（右下角）
    panel:AddChild(UI.Label({
        position = "absolute",
        bottom = 24, right = 24,
        width = 140, height = 32,
        text = "点击跳过 ›",
        fontSize = 16,
        fontColor = { 255, 255, 255, 170 },
        textAlign = "right",
    }))

    uiRoot:AddChild(panel)

    M.state.panel = panel
    M.state.player = player

    print("[CG] 开始播放片头动画：" .. tostring(src))
    return true
end

-- 根据当前播放时间更新底部字幕
function M.UpdateSubtitle(time)
    local subs = M.state.subtitles
    local label = M.state.subtitleLabel
    if not subs or not label then return end

    local found = nil
    for _, s in ipairs(subs) do
        if time >= s.start and time < s.finish then
            found = s
            break
        end
    end

    if found then
        local txt
        if found.speaker and found.speaker ~= "" then
            txt = found.speaker .. "：" .. found.text
        else
            txt = found.text
        end
        if label:GetText() ~= txt then
            label:SetText(txt)
        end
        label:SetVisible(true)
    else
        label:SetVisible(false)
    end
end

-- 结束（播放完或跳过）：清理并回调
function M.Finish()
    if M.state.finishing then return end
    M.state.finishing = true

    local cb = M.state.onComplete
    M.Stop()
    if cb then cb() end
end

-- 强制停止并清理（不触发 onComplete）
function M.Stop()
    M.state.active = false
    local panel = M.state.panel
    if panel then
        pcall(function() panel:Destroy() end)
    end
    M.state.panel = nil
    M.state.player = nil
    M.state.onComplete = nil
    M.state.subtitles = nil
    M.state.subtitleLabel = nil
end

return M
