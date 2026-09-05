-- CSVLoader.lua
-- 运行时从 CSV 读取台词 / 线索文本，供策划在 Excel / 表格中编辑。
-- 用法（在 GameData.lua 末尾调用）：
--   local CSVLoader = require("scripts.CSVLoader")
--   local csv = CSVLoader.LoadAll()
--   if csv.dialogues then M.Dialogues = csv.dialogues end
--   if csv.clues     then M.Clues     = csv.clues     end
--
-- 设计要点：
--   * CSV 行数即台词句数 —— 增加/删除一行，游戏就多/少说一句（"根据行数说多少句"）。
--   * 对话按 dialogue_id 分组，按 line_no 排序，重建为 lines 数组，DialogueSystem 无需改动即可消费。
--   * 多个候选路径回退；找不到 CSV 时返回 nil，调用方保留内嵌兜底数据，游戏不会崩。

local M = {}

-- 候选路径（前两个是相对项目根的常见位置；第一个是推荐位置）
local DIALOGUE_PATHS = {
    "assets/data/dialogues.csv",
    "data/dialogues.csv",
    "dialogues.csv",
}
local CLUE_PATHS = {
    "assets/data/clues.csv",
    "data/clues.csv",
    "clues.csv",
}

-- 读取文本文件；不存在/打不开返回 nil
local function readText(path)
    if not fileSystem or not fileSystem:FileExists(path) then return nil end
    local f = File(path, FILE_READ)
    if not f or not f:IsOpen() then return nil end
    local s = f:ReadString()
    f:Close()
    return s
end

-- 健壮 CSV 解析：支持引号字段、字段内逗号、"" 转义、字段内换行、\r\n 换行、UTF-8 BOM
local function parseCSV(text)
    if not text or #text == 0 then return {} end
    -- 去掉 UTF-8 BOM (EF BB BF)
    if text:byte(1) == 0xEF and text:byte(2) == 0xBB and text:byte(3) == 0xBF then
        text = text:sub(4)
    end
    local rows = {}
    local row, field = {}, ""
    local inQuotes = false
    local i, n = 1, #text
    while i <= n do
        local c = text:sub(i, i)
        if inQuotes then
            if c == '"' then
                if text:sub(i + 1, i + 1) == '"' then
                    field = field .. '"'
                    i = i + 2
                else
                    inQuotes = false
                    i = i + 1
                end
            else
                field = field .. c
                i = i + 1
            end
        else
            if c == '"' then
                inQuotes = true
                i = i + 1
            elseif c == ',' then
                row[#row + 1] = field
                field = ""
                i = i + 1
            elseif c == '\r' then
                i = i + 1
            elseif c == '\n' then
                row[#row + 1] = field
                rows[#rows + 1] = row
                row, field = {}, ""
                i = i + 1
            else
                field = field .. c
                i = i + 1
            end
        end
    end
    -- 收尾（文件末尾没有换行时）
    if #field > 0 or #row > 0 then
        row[#row + 1] = field
        rows[#rows + 1] = row
    end
    return rows
end

local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- 对话 CSV -> { [dialogue_id] = { id, background, lines = { {speaker,text,portrait,clue}, ... } } }
function M.LoadDialogues(csvText)
    local rows = parseCSV(csvText)
    if not rows or #rows < 2 then return nil end
    local header = rows[1]
    local col = {}
    for idx, h in ipairs(header) do
        col[trim(h)] = idx
    end
    if not col.dialogue_id or not col.text then return nil end

    local dialogues = {}
    local temp = {} -- dialogue_id -> { [line_no] = line }
    for r = 2, #rows do
        local row = rows[r]
        local did = trim(row[col.dialogue_id] or "")
        if did ~= "" then
            dialogues[did] = dialogues[did] or { id = did, lines = {}, background = "" }
            temp[did] = temp[did] or {}
            local ln = tonumber(row[col.line_no]) or (#(temp[did]) + 1)
            local bg = row[col.background] or ""
            if dialogues[did].background == "" and bg ~= "" then
                dialogues[did].background = bg
            end
            temp[did][ln] = {
                speaker  = row[col.speaker]  or "",
                text     = row[col.text]     or "",
                portrait = row[col.portrait] or "",
                clue     = row[col.clue]     or "",
                portraitPosition = row[col.portrait_position] or "1",
                background = bg,
            }
        end
    end
    -- 按 line_no 排序重建为连续数组（行数即句数）
    for did, t in pairs(temp) do
        local keys = {}
        for k, _ in pairs(t) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return a < b end)
        local arr = {}
        for _, k in ipairs(keys) do
            local ln = t[k]
            -- 与组默认背景相同则不保留行级 background（语义：该行不切镜头）
            if ln.background == dialogues[did].background then
                ln.background = nil
            end
            arr[#arr + 1] = ln
        end
        dialogues[did].lines = arr
    end
    return dialogues
end

-- 线索 CSV -> { [id] = { id, name, category, chapter, description, detail, image } }
function M.LoadClues(csvText)
    local rows = parseCSV(csvText)
    if not rows or #rows < 2 then return nil end
    local header = rows[1]
    local col = {}
    for idx, h in ipairs(header) do
        col[trim(h)] = idx
    end
    if not col.id then return nil end

    local clues = {}
    for r = 2, #rows do
        local row = rows[r]
        local id = trim(row[col.id] or "")
        if id ~= "" then
            clues[id] = {
                id          = id,
                name        = row[col.name]        or "",
                category    = row[col.category]    or "",
                chapter     = row[col.chapter]     or "",
                description = row[col.description] or "",
                detail      = row[col.detail]      or "",
                image       = row[col.image]       or "",
            }
        end
    end
    return clues
end

-- 依次尝试候选路径，返回 (文本内容, 命中路径)
local function loadFirst(paths)
    for _, p in ipairs(paths) do
        local s = readText(p)
        if s then return s, p end
    end
    return nil
end

-- 一次性加载对话 + 线索，返回 { dialogues, clues, dlgPath, cluePath }
function M.LoadAll()
    local dlgText, dlgPath = loadFirst(DIALOGUE_PATHS)
    local clueText, cluePath = loadFirst(CLUE_PATHS)
    local result = {
        dialogues = dlgText and M.LoadDialogues(dlgText) or nil,
        clues     = clueText and M.LoadClues(clueText) or nil,
        dlgPath   = dlgPath,
        cluePath  = cluePath,
    }
    return result
end

return M
