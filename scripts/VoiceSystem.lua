-- ============================================================================
-- VoiceSystem.lua - 角色配音系统
-- 播放 ElevenLabs(Eleven v3) 生成的台词音频，与 DialogueSystem 打字机同步
--
-- 音频由 Maker MCP `text_to_dialogue` 生成，落在 assets/audio/voice/
-- 实测编码为 Ogg Vorbis(44.1kHz 单声道)，Urho3D 的 LoadOggVorbis 可直接解码，
-- 无需 ffmpeg 转码。
--
-- 音色映射由 Maker 持久化在 .project/elevenlabs-voice-mapping.json，
-- 本文件只负责「哪句台词播哪个音频文件」。
-- ============================================================================

local M = {}

M.enabled = false         -- 音频暂时全部关闭
M.node = nil              -- 承载 SoundSource 的节点
M.source = nil            -- SoundSource 组件
M.currentPath = nil       -- 当前正在播的音频路径

-- 角色音色哈希：ElevenLabs voiceId 片段，用于拼装文件名
-- 新增角色配音后在此登记即可
local HASH = {
    LiZhi = "96d00e9b7ef61b68",
    LiZhiSister = "75428c8194d8c22f",
    NewsAnchor = "377667b6ea69f8d7",
}

local DIR = "assets/audio/voice/"

-- 拼装音频路径：v("prologue_1_2", HASH.LiZhi)
local function v(name, hash)
    return DIR .. name .. "_1_" .. hash .. ".ogg"
end

-- ============================================================================
-- 台词音频映射表
--   dialogueId -> { [行号] = 音频路径 }
-- 行号即 CSV 的 line_no（1-based）。未登记的行不播配音，静默跳过。
-- ============================================================================

M.voiceTable = {
    ["opening_prologue_1"] = {
        [2] = v("prologue_1_2", HASH.LiZhi),
        [4] = v("prologue_1_4", HASH.LiZhi),
    },
    ["opening_prologue_2"] = {
        [2] = v("prologue_2_2", HASH.LiZhi),
        [5] = v("prologue_2_5", HASH.LiZhi),
    },
    ["opening_prologue_3"] = {
        [3]  = v("prologue_3_3", HASH.LiZhi),
        [4]  = v("prologue_3_4", HASH.LiZhiSister),
        [5]  = v("prologue_3_5", HASH.LiZhi),
        [6]  = v("prologue_3_6", HASH.LiZhiSister),
        [8]  = v("prologue_3_8", HASH.LiZhi),
        [9]  = v("prologue_3_9", HASH.LiZhiSister),
        [10] = v("prologue_3_10", HASH.LiZhi),
        [11] = v("prologue_3_11", HASH.LiZhiSister),
        [12] = v("prologue_3_12", HASH.LiZhi),
        [13] = v("prologue_3_13", HASH.LiZhi),
    },
    ["opening_prologue_4"] = {
        [2] = v("prologue_4_2", HASH.NewsAnchor),
        [3] = v("prologue_4_3", HASH.LiZhi),
        [5] = v("prologue_4_5", HASH.LiZhi),
        [7] = v("prologue_4_7", HASH.LiZhi),
    },
    ["opening_prologue_5"] = {
        [2] = v("prologue_5_2", HASH.LiZhi),
    },
    ["opening_prologue_5_after"] = {
        [2] = v("prologue_5a_2", HASH.LiZhi),
    },
}

-- ============================================================================
-- 内部：确保 SoundSource 存在
-- 音频全部走 pcall：配音失败绝不能让游戏崩掉，最多是没有声音
-- ============================================================================

function M.EnsureSource()
    if M.source then return M.source end
    local ok, err = pcall(function()
        M.node = Node()
        M.source = M.node:CreateComponent("SoundSource")
        if M.source then
            M.source.soundType = SOUND_VOICE
            M.source.gain = 1.0
        end
    end)
    if not ok or not M.source then
        print("[VOICE ERROR] SoundSource 创建失败: " .. tostring(err))
        M.source = nil
    end
    return M.source
end

-- ============================================================================
-- 播放某句台词的配音
-- @param dialogueId string 对话 id
-- @param lineIndex  number  行号（1-based，对应 CSV line_no）
-- @return boolean 是否真的播了
-- ============================================================================

function M.Play(dialogueId, lineIndex)
    if not M.enabled then return false end
    if not dialogueId or not lineIndex then return false end

    local lines = M.voiceTable[dialogueId]
    if not lines then return false end
    local path = lines[lineIndex]
    if not path then return false end

    local src = M.EnsureSource()
    if not src then return false end

    local ok, err = pcall(function()
        local sound = cache:GetResource("Sound", path)
        if not sound then
            print("[VOICE WARN] 音频资源加载失败: " .. tostring(path))
            return
        end
        src:Stop()
        src:Play(sound)
        M.currentPath = path
        print(string.format("[VOICE] 播放 %s#%d -> %s", dialogueId, lineIndex, path))
    end)
    if not ok then
        print("[VOICE ERROR] 播放失败: " .. tostring(err))
        return false
    end
    return M.currentPath == path
end

-- ============================================================================
-- 停止当前配音
-- ============================================================================

function M.Stop()
    if not M.source then return end
    pcall(function() M.source:Stop() end)
    M.currentPath = nil
end

-- ============================================================================
-- 查询 / 开关
-- ============================================================================

function M.IsPlaying()
    if not M.source then return false end
    local ok, playing = pcall(function() return M.source.playing end)
    return ok and playing or false
end

function M.SetEnabled(value)
    M.enabled = value and true or false
    if not M.enabled then M.Stop() end
end

-- 某句台词是否有配音（供 UI 判断是否显示"有语音"标记）
function M.HasVoice(dialogueId, lineIndex)
    if not dialogueId or not lineIndex then return false end
    local lines = M.voiceTable[dialogueId]
    return lines ~= nil and lines[lineIndex] ~= nil
end

return M
