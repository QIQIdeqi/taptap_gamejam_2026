-- ============================================================================
-- MusicSystem.lua - 背景音乐播放与淡出
-- ============================================================================

local M = {}

M.enabled = true
M.path = "assets/audio/first_stage_theme.mp3"
M.node = nil
M.source = nil
M.targetGain = 0.32
M.fade = nil

local function _ensureSource()
    if M.source then return M.source end
    local ok, err = pcall(function()
        M.node = Node()
        M.source = M.node:CreateComponent("SoundSource")
        if M.source then
            M.source.soundType = SOUND_MUSIC
            M.source.looped = true
        end
    end)
    if not ok or not M.source then
        print("[MUSIC ERROR] SoundSource 创建失败: " .. tostring(err))
        M.source = nil
    end
    return M.source
end

function M.PlayFirstStage()
    if not M.enabled then return false end
    local source = _ensureSource()
    if not source then return false end

    local ok, result = pcall(function()
        local sound = cache:GetResource("Sound", M.path)
        if not sound then
            print("[MUSIC ERROR] 音乐资源加载失败: " .. M.path)
            return false
        end
        source:Stop()
        source.looped = true
        source.gain = 0
        source:Play(sound)
        M.fade = { from = 0, to = M.targetGain, t = 0, duration = 1.2 }
        print("[MUSIC] 第一阶段音乐开始: " .. M.path)
        return true
    end)
    if not ok then
        print("[MUSIC ERROR] 音乐播放失败: " .. tostring(result))
        return false
    end
    return result == true
end

function M.FadeOut(duration)
    if not M.source then return end
    local current = M.source.gain or M.targetGain
    M.fade = {
        from = current,
        to = 0,
        t = 0,
        duration = duration or 1.5,
        stopWhenDone = true,
    }
    print(string.format("[MUSIC] 音乐淡出 %.2fs", M.fade.duration))
end

function M.Stop()
    if M.source then
        pcall(function() M.source:Stop() end)
        pcall(function() M.source.gain = 0 end)
    end
    M.fade = nil
end

function M.Update(deltaTime)
    if not M.fade or not M.source then return end
    M.fade.t = math.min(M.fade.t + deltaTime, M.fade.duration)
    local k = M.fade.duration > 0 and (M.fade.t / M.fade.duration) or 1
    local gain = M.fade.from + (M.fade.to - M.fade.from) * k
    pcall(function() M.source.gain = gain end)
    if k >= 1 then
        local stopWhenDone = M.fade.stopWhenDone
        M.fade = nil
        if stopWhenDone then
            pcall(function() M.source:Stop() end)
        end
    end
end

return M
