return function(inherited, __embed)
local __embedSource = type(__embed) == "string" and __embed or nil
local __privacyG = (type(getgenv) == "function" and getgenv()) or _G
do
local __oldSession = __privacyG.EnderHubSession
if type(__oldSession) == "table" and type(__oldSession.stop) == "function" then __oldSession.stop("restart") end
__privacyG.EnderHubBootStage = "startup"
end
local HX = {} 

HX.t0 = os.clock()

HX.bootMillis = 0
pcall(function()
    HX.bootMillis = DateTime.now().UnixTimestampMillis
end)
if type(HX.bootMillis) ~= "number" or HX.bootMillis <= 0 then
    local seconds = 0
    pcall(function() seconds = os.time() end)
    if type(seconds) == "number" and seconds > 0 then
        HX.bootMillis = seconds * 1000
    else
        HX.bootMillis = 0
    end
end

local runtime = {}
if type(inherited) == "table" then

    HX.inheritedRuntime = true
end

local genvEarly = (getgenv and getgenv()) or _G

function HX.bootStage(name)
    genvEarly.EnderHubBootStage = name
    if type(writefile) == "function" then
        pcall(writefile, "EnderHubBootStage.txt", tostring(name))
    end
end
HX.bootStage("start")
do
    local previous = genvEarly.EnderHubSession
    if type(previous) == "table" and type(previous.stop) == "function" and not previous.stopped then
        pcall(previous.stop, "re-executed")
    end
    local previousUi = genvEarly.EnderHubRuntime
    if type(previousUi) == "table" and type(previousUi.WindUI) == "table" then
        local old = previousUi.WindUI
        pcall(function() old.Window = nil end)
        for _, field in ipairs({ "ScreenGui", "NotificationGui", "DropdownGui", "TooltipGui" }) do
            pcall(function()
                local gui = old[field]
                if typeof(gui) == "Instance" then
                    gui:Destroy()
                end
            end)
        end
    end
    genvEarly.EnderHubRuntime = nil
end

HX.WINDUI_MARK = "enderhub-windui-mac-chrome50-calendar"

HX.RAW_BASE = "https://raw.githubusercontent.com/QilexCrown/EnderHubLoader/refs/heads/main/"

if type(runtime.Fetch) ~= "function" then
    runtime.Fetch = function(path)
        local url = HX.RAW_BASE .. tostring(path)
        local bust = genvEarly.EnderHubCacheBust
        if type(bust) == "string" and bust ~= "" then
            url = url .. "?v=" .. bust
        end
        if type(game.HttpGet) == "function" then
            return game:HttpGet(url)
        end
        return game:HttpGetAsync(url)
    end
end

if type(runtime.Compile) ~= "function" then
    runtime.Compile = function(source, name)
        if type(loadstring) == "function" then
            return loadstring(source, name)
        end
        return nil
    end
end

HX.rawWarn = warn
HX.rawPrint = print

HX.Log = {
    level = "info",
    order = { debug = 10, info = 20, warn = 30, error = 40 },
    history = {},
    limit = 400,
    seen = {},
    quiet = {},
    sink = nil,
}

function HX.Log.stamp()
    local ok, value = pcall(function()
        return os.date("%H:%M:%S")
    end)
    return ok and value or "??:??:??"
end

function HX.Log.format(level, tag, message)
    return string.format(
        "[%s] %-5s %s: %s",
        HX.Log.stamp(),
        string.upper(level),
        tostring(tag),
        tostring(message)
    )
end

function HX.Log.push(level, tag, message, silent)
    local weight = HX.Log.order[level] or 20
    if weight < (HX.Log.order[HX.Log.level] or 20) then
        return nil
    end

    local text = tostring(message)
    local entry = {
        level = level,
        weight = weight,
        tag = tostring(tag),
        message = text,
        at = os.clock(),
        stamp = HX.Log.stamp(),
    }

    table.insert(HX.Log.history, entry)
    if #HX.Log.history > HX.Log.limit then
        table.remove(HX.Log.history, 1)
    end

    if not silent then

    end

    if HX.Log.sink then
        pcall(HX.Log.sink, entry)
    end
    return entry
end

function HX.Log.debug(tag, message) return HX.Log.push("debug", tag, message) end
function HX.Log.info(tag, message) return HX.Log.push("info", tag, message) end
function HX.Log.warn(tag, message) return HX.Log.push("warn", tag, message) end
function HX.Log.error(tag, message) return HX.Log.push("error", tag, message) end

function HX.Log.once(key, level, tag, message)
    if HX.Log.seen[key] then return nil end
    HX.Log.seen[key] = true
    return HX.Log.push(level, tag, message)
end

function HX.Log.throttle(key, seconds, level, tag, message)
    local now = os.clock()
    local last = HX.Log.seen[key]
    if last and (now - last) < (seconds or 5) then
        return nil
    end
    HX.Log.seen[key] = now
    return HX.Log.push(level, tag, message)
end

function HX.Log.trace()
    local ok, text = pcall(function()
        return debug.traceback("", 2)
    end)
    return ok and text or ""
end

function HX.Log.guard(tag, fn, ...)
    local packed = table.pack(...)
    local ok, result = xpcall(function()
        return fn(table.unpack(packed, 1, packed.n))
    end, function(reason)
        return tostring(reason) .. "\n" .. HX.Log.trace()
    end)

    if not ok then
        HX.Log.error(tag, result)
        return false, result
    end
    return true, result
end

function HX.Log.timed(tag, fn, ...)
    local started = os.clock()
    local ok, result = HX.Log.guard(tag, fn, ...)
    HX.Log.debug(tag, string.format("%.1f ms", (os.clock() - started) * 1000))
    return ok, result
end

function HX.Log.tail(count)
    count = math.max(1, count or 10)
    local out = {}
    local from = math.max(1, #HX.Log.history - count + 1)
    for index = from, #HX.Log.history do
        table.insert(out, HX.Log.history[index])
    end
    return out
end

function HX.Log.attach(notify)
    HX.Log.sink = function(entry)
        if entry.weight < 30 then return end
        local key = entry.tag .. "|" .. entry.message
        local now = os.clock()
        local last = HX.Log.quiet[key]
        if last and (now - last) < 6 then return end
        HX.Log.quiet[key] = now
        notify(entry)
    end
end

function HX.Log.watch()
    local genv = HX.bootGenv
    local LogService = game:GetService("LogService")
    if genv and genv.EnderHubLogWatcher then
        pcall(function()
            genv.EnderHubLogWatcher:Disconnect()
        end)
    end
    local connection = LogService.MessageOut:Connect(function(message, kind)
        if kind ~= Enum.MessageType.MessageError then
            return
        end
        local text = tostring(message)

        if not string.find(text, "ImageLabel", 1, true)
            and not string.find(text, "WindUI", 1, true)
            and not string.find(text, "enderhub", 1, true)
            and not string.find(text, "EnderHub", 1, true) then
            return
        end
        HX.Log.push("error", "roblox", text, true)
    end)
    if genv then
        genv.EnderHubLogWatcher = connection
    end
    return connection
end

HX.bootGenv = (getgenv and getgenv()) or _G
HX.bootGenv.EnderHubBootMark = "v170:boot"

function HX.embedText()
    if type(__embedSource) == "string" and #__embedSource > 10000 then
        return __embedSource
    end
    local scopes = {}
    if type(shared) == "table" then
        scopes[#scopes + 1] = shared
    end
    scopes[#scopes + 1] = HX.bootGenv
    if type(getgenv) == "function" then
        scopes[#scopes + 1] = getgenv()
    end
    scopes[#scopes + 1] = _G
    for _, scope in ipairs(scopes) do
        local text = type(scope) == "table" and rawget(scope, "EnderHubWindUIEmbed") or nil
        if type(text) == "string" and #text > 10000 then
            return text
        end
    end
    return nil
end

function HX.hardenIcons(ui)
    if type(ui) ~= "table" then
        return false
    end

    local icons = nil
    if type(ui.Creator) == "table" and type(ui.Creator.Icons) == "table" then
        icons = ui.Creator.Icons
    elseif type(ui.Icons) == "table" then
        icons = ui.Icons
    end
    if type(icons) ~= "table" or type(icons.Image) ~= "function" then
        return false
    end
    if icons.EnderHubImageLabelSafe then
        return true
    end

    local originalImage = icons.Image
    icons.Image = function(config)
        local ok, result = pcall(originalImage, config)
        local frame = ok and type(result) == "table" and result.IconFrame or nil

        if typeof(frame) == "Instance" then
            if frame.Name ~= "ImageLabel" then
                frame.Name = "ImageLabel"
            end
            return result
        end

        HX.Log.warn("ui.icons", "icon frame unavailable: " .. tostring(ok and "no frame returned" or result))
        frame = Instance.new("ImageLabel")
        frame.Name = "ImageLabel"
        frame.BackgroundTransparency = 1
        frame.Size = (type(config) == "table" and typeof(config.Size) == "UDim2")
            and config.Size
            or UDim2.new(0, 24, 0, 24)

        if type(result) ~= "table" then
            result = { IconFrame = frame }
        else
            result.IconFrame = frame
        end
        return result
    end

    icons.EnderHubImageLabelSafe = true
    return true
end

HX.WINDUI_URL = "https://raw.githubusercontent.com/QilexCrown/WindUI/main/dist/main.lua?v="
    .. HX.WINDUI_MARK
HX.WINDUI_TAG = "enderhub-fork"
HX.WINDUI_NEED = "src/elements/Toggle.lua"
HX.WINDUI_CACHE = "EnderHub/windui.luau"

function HX.cacheWindUI()
    if type(readfile) ~= "function" or type(isfile) ~= "function" then return nil end
    local ok, data = pcall(function()
        if not isfile(HX.WINDUI_CACHE) then return nil end
        return readfile(HX.WINDUI_CACHE)
    end)
    if not ok or type(data) ~= "string" or #data < 10000 then return nil end
    if not string.find(data, HX.WINDUI_MARK, 1, true) then return nil end
    return data
end

function HX.storeWindUI(text)
    if type(text) ~= "string" or #text < 10000 then return end
    if type(writefile) ~= "function" then return end
    pcall(function()
        if type(isfile) == "function" then
            local known = isfile(HX.WINDUI_CACHE)
            if not known and type(makefolder) == "function" then
                pcall(makefolder, "EnderHub")
            end
        end
        writefile(HX.WINDUI_CACHE, text)
    end)
end

function HX.isForkWindUI(module)
    return type(module) == "table"
        and type(module.CreateWindow) == "function"
        and type(module.AddTheme) == "function"
        and type(module.SetTheme) == "function"
        and type(module.GlassButton) == "function"
        and type(module.InfoCard) == "function"
end

function HX.winduiAlive(module)
    if not HX.isForkWindUI(module) then return false end
    local gui = module.ScreenGui
    return typeof(gui) == "Instance" and gui.Parent ~= nil
end

function HX.dropWindUIGuis(module)
    if type(module) ~= "table" then return end
    for _, field in ipairs({ "ScreenGui", "NotificationGui", "DropdownGui", "TooltipGui" }) do
        pcall(function()
            local gui = module[field]
            if typeof(gui) == "Instance" then
                gui:Destroy()
            end
        end)
    end
end

if not HX.winduiAlive(runtime.WindUI) then
    HX.dropWindUIGuis(runtime.WindUI)
    runtime.WindUI = nil
    HX.bootStage("windui")

    local embed = HX.embedText()
    local source
    local origin = "embed"
    if type(embed) == "string" and #embed > 10000 then
        source = embed
        HX.storeWindUI(embed)
    else
        source = HX.bootGenv.EnderHubWindUISource
        local function usable(text)
            if type(text) ~= "string" or #text < 10000 then return false end
            if not string.find(text, HX.WINDUI_MARK, 1, true) then return false end
            local stamp = tonumber(HX.bootGenv.EnderHubWindUIStamp)
            return stamp == nil or #text == stamp
        end
        origin = "genv"
        if not usable(source) then
            source = HX.cacheWindUI()
            origin = "disk"
        end
        if not usable(source) then
            origin = "net"
            local ok, data = pcall(function()
                return game:HttpGet(HX.WINDUI_URL)
            end)
            if ok and usable(data) then
                source = data
                HX.storeWindUI(data)
            end
        end
    end
    HX.winduiOrigin = origin

    
    local function tryBundle(text)
        if type(text) ~= "string" or #text < 10000 then
            return nil, "bundle missing or too short"
        end

        
        if not string.find(text, HX.WINDUI_NEED, 1, true) then
            return nil, "bundle has no Toggle element"
        end
        local ok, module = pcall(function()
            return loadstring(text)()
        end)
        if not ok then
            return nil, tostring(module)
        end
        if type(module) ~= "table" then
            return nil, "bundle returned " .. type(module)
        end
        if not HX.isForkWindUI(module) then
            return nil, "bundle is not the fork (BuildTag " .. tostring(module.BuildTag) .. ")"
        end
        return module, nil
    end

    local module, why = tryBundle(source)
    if not module then
        HX.Log.warn("ui.windui", string.format("embedded bundle unusable: %s", tostring(why)))
        local got, data = pcall(function()
            return game:HttpGet(HX.WINDUI_URL)
        end)
        if got then
            if type(data) == "string" and string.find(data, HX.WINDUI_MARK, 1, true) then
                module, why = tryBundle(data)
                if module then
                    HX.bootGenv.EnderHubWindUISource = data
                    HX.storeWindUI(data)
                end
            else
                why = "network bundle is a different build"
            end
        else
            why = tostring(data)
        end
    end
    if module then
        HX.bootGenv.EnderHubWindUISource = HX.bootGenv.EnderHubWindUISource or source
        HX.winduiOrigin = HX.winduiOrigin or origin

        module.BootCard = false
        runtime.WindUI = module
    else
        HX.Log.error("ui.windui", string.format("no usable WindUI bundle: %s", tostring(why)))
    end
    HX.bootGenv.EnderHubRuntime = runtime
end

local WindUI = runtime.WindUI
if not HX.isForkWindUI(WindUI) then
    error("Ender Hub: WindUI could not be loaded (need CreateWindow, AddTheme, SetTheme)", 0)
end
HX.bootStage("windui-ready")

if not HX.hardenIcons(WindUI) then
    HX.Log.warn("ui.icons", "icon library missing from WindUI; image frames stay unguarded")
else
    HX.Log.debug("ui.icons", "image frames guarded")
end
HX.bootStage("icons")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
HX.TextChatService = game:GetService("TextChatService")
HX.ReplicatedStorage = game:GetService("ReplicatedStorage")
HX.Workspace = game:GetService("Workspace")
HX.TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
HX.StarterGui = game:GetService("StarterGui")
HX.StarterPack = game:GetService("StarterPack")
HX.StarterPlayer = game:GetService("StarterPlayer")

local CoreGui
do
    local ok, service = pcall(function() return game:GetService("CoreGui") end)
    CoreGui = (ok and service) or nil
end
if not CoreGui then
    local player = Players.LocalPlayer
    CoreGui = player and player:WaitForChild("PlayerGui")
end
HX.Lighting = game:GetService("Lighting")
HX.SoundService = game:GetService("SoundService")
local TeleportService = game:GetService("TeleportService")
HX.ProximityPromptService = game:GetService("ProximityPromptService")
HX.CollectionService = game:GetService("CollectionService")
HX.ContextActionService = game:GetService("ContextActionService")
HX.GuiService = game:GetService("GuiService")
HX.MarketplaceService = game:GetService("MarketplaceService")
HX.PathfindingService = game:GetService("PathfindingService")
HX.Debris = game:GetService("Debris")
HX.Stats = game:GetService("Stats")
HX.Teams = game:GetService("Teams")
HX.Chat = game:GetService("Chat")
HX.VirtualUser = game:GetService("VirtualUser")
HX.VirtualInputManager = game:GetService("VirtualInputManager")

local lp = Players.LocalPlayer
HX.LocalPlayer = lp
HX.Camera = HX.Workspace.CurrentCamera
HX.Mouse = lp and lp:GetMouse()
HX.bootStage("services")

local getgenv = getgenv or function() return _G end
HX.CoreGui = HX.CoreGui or CoreGui

local pickCallable = function(...)
    for index = 1, select("#", ...) do
        local candidate = select(index, ...)
        if type(candidate) == "function" then
            return candidate
        end
    end
    return nil
end
HX.gethui = HX.gethui or pickCallable(gethui) or function() return CoreGui end
HX.cloneref = HX.cloneref or pickCallable(cloneref, clonereference) or function(inst) return inst end
HX.firetouchinterest = HX.firetouchinterest or pickCallable(firetouchinterest)
HX.fireproximityprompt = HX.fireproximityprompt or pickCallable(fireproximityprompt)
HX.fireclickdetector = HX.fireclickdetector or pickCallable(fireclickdetector)
HX.setclipboard = HX.setclipboard or pickCallable(toclipboard, setclipboard, setrbxclipboard) or function() end
HX.hookmetamethod = HX.hookmetamethod or pickCallable(hookmetamethod)
HX.hookfunction = HX.hookfunction or pickCallable(replaceclosure, hookfunction) or function(target) return target end
HX.newcclosure = HX.newcclosure or pickCallable(newcclosure) or function(f) return f end
HX.getnamecallmethod = HX.getnamecallmethod or pickCallable(getnamecallmethod)
HX.checkcaller = HX.checkcaller or pickCallable(checkcaller) or function() return false end
HX.Version = "1.6.87"
HX.ReleaseVersion = "2.8.3"
HX.bootStage("helpers")

local genv = (getgenv and getgenv()) or _G
HX.rawTask = task
local Window 

HX.Session = {
    stopped = false,
    stopping = false,
    threads = {},
    listeners = {},
}

genv.EnderHubClosed = nil
genv.EnderHubSession = HX.Session
HX.bootStage("session")

function HX.Session.onStop(callback)
    if type(callback) ~= "function" then return end
    if HX.Session.stopped then
        pcall(callback, "already stopped")
        return
    end
    table.insert(HX.Session.listeners, callback)
end

function HX.rememberThread(thread)
    if HX.Session.stopped then
        pcall(HX.rawTask.cancel, thread)
        return false
    end
    if #HX.Session.threads >= 256 then
        for index = #HX.Session.threads, 1, -1 do
            if coroutine.status(HX.Session.threads[index]) == "dead" then
                table.remove(HX.Session.threads, index)
            end
        end
    end
    table.insert(HX.Session.threads, thread)
    return true
end

function HX.runTracked(callback, ...)
    local packed = table.pack(...)
    return HX.rawTask.spawn(function()
        if HX.Session.stopped then return end
        HX.rememberThread(coroutine.running())
        callback(table.unpack(packed, 1, packed.n))
    end)
end

local task = setmetatable({
    spawn = HX.runTracked,
    defer = function(callback, ...)
        local packed = table.pack(...)
        HX.rawTask.defer(function()
            if HX.Session.stopped then return end
            callback(table.unpack(packed, 1, packed.n))
        end)
    end,
    delay = function(seconds, callback, ...)
        local packed = table.pack(...)
        return HX.rawTask.delay(seconds, function()
            if HX.Session.stopped then return end
            callback(table.unpack(packed, 1, packed.n))
        end)
    end,
}, { __index = HX.rawTask })

function HX.sourceOf(callback)
    if type(callback) ~= "function" then return nil end
    local ok, source = pcall(function()
        return debug.info(callback, "s")
    end)
    if ok and type(source) == "string" then return source end
    return nil
end

function HX.disconnectOwnedSignals()
    if type(getconnections) ~= "function" then return end
    local mySource = HX.sourceOf(function() end)
    if not mySource then return end

    local signals = {}
    local function watch(getter)
        local ok, signal = pcall(getter)
        if ok and signal ~= nil then table.insert(signals, signal) end
    end

    watch(function() return RunService.RenderStepped end)
    watch(function() return RunService.Heartbeat end)
    watch(function() return RunService.Stepped end)
    watch(function() return RunService.PreRender end)
    watch(function() return RunService.PreSimulation end)
    watch(function() return RunService.PostSimulation end)
    watch(function() return UserInputService.InputBegan end)
    watch(function() return UserInputService.InputChanged end)
    watch(function() return UserInputService.InputEnded end)
    watch(function() return UserInputService.TextBoxFocused end)
    watch(function() return UserInputService.TextBoxFocusReleased end)
    watch(function() return Players.PlayerAdded end)
    watch(function() return Players.PlayerRemoving end)
    watch(function() return HX.Workspace.ChildAdded end)
    watch(function() return HX.Workspace.ChildRemoved end)
    watch(function() return HX.Workspace.DescendantAdded end)
    watch(function() return HX.Workspace.DescendantRemoving end)
    watch(function() return HX.TextChatService.ChildAdded end)
    watch(function() return HX.TextChatService.DescendantAdded end)
    watch(function() return HX.TextChatService.SendingMessage end)
    watch(function() return HX.TextChatService.MessageReceived end)
    watch(function() return HX.Camera:GetPropertyChangedSignal("CFrame") end)
    watch(function() return lp:GetPropertyChangedSignal("Character") end)
    if lp then
        local character = lp.Character
        if character then
            watch(function() return character.ChildAdded end)
            watch(function() return character.ChildRemoved end)
            watch(function() return character.DescendantAdded end)
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                watch(function() return humanoid.Died end)
                watch(function() return humanoid.HealthChanged end)
                watch(function() return humanoid.StateChanged end)
                local animator = humanoid:FindFirstChildOfClass("Animator")
                if animator then
                    watch(function() return animator.AnimationPlayed end)
                end
            end
        end
    end

    for _, signal in ipairs(signals) do
        local ok, list = pcall(getconnections, signal)
        if ok and type(list) == "table" then
            for _, connection in ipairs(list) do
                local callback = nil
                pcall(function() callback = connection.Function end)
                if HX.sourceOf(callback) == mySource then
                    pcall(function() connection:Disconnect() end)
                    pcall(function() connection.Disconnect(connection) end)
                end
            end
        end
    end
end

function HX.Session.stop(reason)
    if HX.Session.stopped or HX.Session.stopping then return end
    HX.Session.stopping = true

    local api = runtime.Api
    if type(api) == "table" and type(api.stop) == "function" then
        pcall(api.stop)
    end

    local current = coroutine.running()
    for _, thread in ipairs(HX.Session.threads) do
        if thread ~= current then
            pcall(HX.rawTask.cancel, thread)
        end
    end
    table.clear(HX.Session.threads)

    pcall(HX.disconnectOwnedSignals)

    for _, callback in ipairs(HX.Session.listeners) do
        pcall(callback, reason or "stop")
    end
    table.clear(HX.Session.listeners)

    if Window then
        pcall(function() Window:Destroy() end)
    end

    if genv.EnderHubSession == HX.Session then
        genv.EnderHubSession = nil
    end
    genv.EnderHubClosed = true
    HX.Session.stopped = true
    HX.Session.stopping = false
end

local Api = (function()
HX.bootStage("api")

local function genv()
    return (typeof(getgenv) == "function" and getgenv()) or _G
end

function HX.jsonEncode(value)
    local service = game:GetService("HttpService")
    local ok, encoded = pcall(function()
        return service:JSONEncode(value)
    end)
    if ok and type(encoded) == "string" then return encoded end
    return "{}"
end

function HX.jsonDecode(body)
    if type(body) ~= "string" or body == "" then return nil end
    local service = game:GetService("HttpService")
    local ok, decoded = pcall(function()
        return service:JSONDecode(body)
    end)
    if ok and type(decoded) == "table" then return decoded end
    return nil
end

local Api = {}
HX.bootStage("api-init")
Api.hosts = {}
Api.hostIndex = 1
Api.base = ""
Api.secret = ""
Api.key = ""
Api.ok = false
Api.premium = false
Api.reason = ""
Api.ban = nil
Api.banUntil = nil
Api.closing = false
Api.profile = {}
Api.closed = false
Api.mode = nil
Api.lastStatus = nil
Api.heartbeatThread = nil
Api.chatThread = nil
Api.connections = {}
Api.chatQueue = {}
Api.chatSeen = {}
Api.chatOrder = {}
Api.warned = false
Api.startedAt = os.time()
Api.ip = nil
Api.banPopupShown = false
Api.lockdown = nil
Api.plan = ""
Api.developer = false

function HX.send()
    return nil
end

function HX.reportOffline()
    return nil
end

HX.PLACE_KIND = {
    [11137575513] = "Normal",
    [108097274488844] = "OG",
    [12943247001] = "VC",
    [12943245078] = "XL",
}

function HX.executorName()
    if type(identifyexecutor) == "function" then
        local ok, name, version = pcall(identifyexecutor)
        if ok and type(name) == "string" and name ~= "" then
            if type(version) == "string" and version ~= "" then
                return name .. " " .. version
            end
            return name
        end
    end
    return "unknown"
end

function HX.platformName()
    local input = game:GetService("UserInputService")
    local ok, platform = pcall(function()
        return input:GetPlatform()
    end)
    if ok and platform ~= nil then
        local name = string.gsub(tostring(platform), "Enum.Platform%.", "")
        if name ~= "" then return name end
    end
    if input.TouchEnabled and not input.KeyboardEnabled then
        return "Mobile"
    end
    return "Desktop"
end

function HX.placeName()
    local ok, info = pcall(function()
        return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
    end)
    if ok and type(info) == "table" and info.Name then
        return tostring(info.Name)
    end
    return tostring(game.Name)
end

HX.hwidCache = nil

function HX.hardwareId()
    return ""
end

function Api.hardwareId()
    return HX.hardwareId()
end

function HX.statsNumber(path)
    local ok, value = pcall(function()
        local node = game:GetService("Stats")
        for _, step in ipairs(path) do
            node = node[step]
        end
        return node:GetValue()
    end)
    if ok and type(value) == "number" and value == value then
        return math.floor(value)
    end
    return nil
end

function HX.memoryMb()
    local ok, value = pcall(function()
        return game:GetService("Stats"):GetTotalMemoryUsageMb()
    end)
    if ok and type(value) == "number" and value == value then
        return math.floor(value)
    end
    return nil
end

function HX.pingMs()
    return HX.statsNumber({ "Network", "ServerStatsItem", "Data Ping" })
end

function HX.serverUptimeSec()
    local ok, value = pcall(function()
        return workspace.DistributedGameTime
    end)
    if ok and type(value) == "number" and value == value then
        return math.floor(value)
    end
    return nil
end

function HX.playerCounts()
    local players = game:GetService("Players")
    local ok, list = pcall(function() return players:GetPlayers() end)
    local count = (ok and type(list) == "table") and #list or nil
    local okMax, maxPlayers = pcall(function() return players.MaxPlayers end)
    return count, (okMax and type(maxPlayers) == "number") and math.floor(maxPlayers) or nil
end

function HX.inputFlags()
    local ok, input = pcall(function()
        return game:GetService("UserInputService")
    end)
    if not ok or typeof(input) ~= "Instance" then return nil, nil, nil, nil end
    local touch, keyboard, mouse, gamepad
    pcall(function() touch = input.TouchEnabled and true or false end)
    pcall(function() keyboard = input.KeyboardEnabled and true or false end)
    pcall(function() mouse = input.MouseEnabled and true or false end)
    pcall(function() gamepad = input.GamepadEnabled and true or false end)
    return touch, keyboard, mouse, gamepad
end

function HX.fetchIp()
    return ""
end

HX.fpsFrames = 0
HX.fpsValue = nil

function HX.startFps()
    if HX.fpsStarted then return end
    local ok, run = pcall(function()
        return game:GetService("RunService")
    end)
    if not ok or typeof(run) ~= "Instance" then return end
    HX.fpsStarted = true

    local frames = 0
    local elapsed = 0
    pcall(function()
        run.Heartbeat:Connect(function(dt)
            local step = tonumber(dt)
            if not step or step <= 0 then return end
            frames = frames + 1
            elapsed = elapsed + step
            if elapsed < 0.5 then return end
            local fps = math.floor((frames / elapsed) + 0.5)
            if fps > 0 and fps < 1000 then
                HX.fpsValue = fps
            end
            frames = 0
            elapsed = 0
        end)
    end)
end

pcall(HX.startFps)

function Api.setProfile()
    Api.profile = {}
end

function HX.basePayload()
    return { key = Api.key }
end

function Api.closeScript()
    if Api.closing then return end
    Api.closing = true
    pcall(Api.stop)
    local ok, runtime = pcall(function()
        return genv().EnderHubRuntime
    end)
    if ok and type(runtime) == "table" then
        local ui = runtime.WindUI
        if type(ui) == "table" then
            pcall(function()
                if ui.Window and type(ui.Window.Destroy) == "function" then
                    ui.Window:Destroy()
                end
            end)
            for _, field in ipairs({ "ScreenGui", "NotificationGui", "DropdownGui", "TooltipGui" }) do
                pcall(function()
                    local gui = ui[field]
                    if typeof(gui) == "Instance" then
                        gui:Destroy()
                    end
                end)
            end
        end
    end
    pcall(function()
        genv().EnderHubRuntime = nil
        genv().EnderHubClosed = true
    end)
end

function HX.dialog(spec)
    if type(spec) ~= "table" then return nil end
    local ok, ui = pcall(function()
        return genv().EnderHubRuntime and genv().EnderHubRuntime.WindUI
    end)
    if not ok or type(ui) ~= "table" then return nil end

    local window = nil
    pcall(function() window = ui.Window end)
    if type(window) ~= "table" or type(window.Dialog) ~= "function" then return nil end

    local made = nil
    pcall(function()
        made = window:Dialog({
            Title = spec.Title,
            Content = spec.Content,
            Icon = spec.Icon,
            IconThemed = spec.IconThemed,
            Width = spec.Width,
            Buttons = spec.Buttons,
        })
    end)
    return made
end

function HX.keyShape(key)
    local clean = string.upper((string.gsub(tostring(key or ""), "%s+", "")))
    if #clean < 8 or #clean > 64 then return nil end
    if not string.match(clean, "^[A-Z0-9][A-Z0-9%-_%.]*$") then return nil end
    return clean
end

function Api.verify(key)
    local shape = HX.keyShape(key)
    Api.key = shape or ""
    Api.ok = true
    Api.premium = true
    Api.reason = ""
    Api.ban = nil
    Api.banUntil = nil
    Api.lockdown = nil
    Api.developer = false
    return true, nil
end

function Api.heartbeat()
    return nil
end

function HX.remember(slot, speaker, text)
    local key = string.format("%s\0%s\0%d", speaker, text, slot)
    if Api.chatSeen[key] then return false end
    Api.chatSeen[key] = true
    table.insert(Api.chatOrder, key)
    if #Api.chatOrder > 600 then
        local oldest = table.remove(Api.chatOrder, 1)
        Api.chatSeen[oldest] = nil
    end
    return true
end

function HX.clock()
    local ok, stamp = pcall(function()
        return os.date("%H:%M:%S")
    end)
    if ok and type(stamp) == "string" then return stamp end
    return ""
end

-- Chat forwarding removed: the Main chat view is local-only.
function Api.flushChat() Api.chatQueue = {} end

function Api.start()
    if Api.closed then return end
    Api.startedAt = os.time()
    pcall(HX.startFps)
end

function Api.stop()
    Api.closed = true
    Api.profile, Api.ip, Api.hwid = {}, nil, nil
    local current = coroutine.running()
    local thread = Api.heartbeatThread
    Api.heartbeatThread = nil
    if thread and thread ~= current then
        pcall(task.cancel, thread)
    end
    local chatThread = Api.chatThread
    Api.chatThread = nil
    if chatThread and chatThread ~= current then
        pcall(task.cancel, chatThread)
    end
    local controlThread = Api.controlThread
    Api.controlThread = nil
    if controlThread and controlThread ~= current then
        pcall(task.cancel, controlThread)
    end
    for _, connection in ipairs(Api.connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(Api.connections)
    pcall(Api.flushChat)
end

function Api.gate(WindUI, player)
    pcall(Api.setProfile, player)
    return true
end

HX.LANG_FILE = "EnderHub/Language.txt"

function HX.langRead()
    if type(readfile) ~= "function" or type(isfile) ~= "function" then return nil end
    local fine, body = pcall(function()
        if isfile(HX.LANG_FILE) then
            return readfile(HX.LANG_FILE)
        end
        return nil
    end)
    if not fine or type(body) ~= "string" then return nil end
    local clean = string.lower((string.gsub(body, "%s+", "")))
    if clean == "" then return nil end
    if not string.match(clean, "^%l%l$") then return nil end
    return clean
end

function HX.langWrite(code)
    if type(writefile) ~= "function" then return end
    pcall(function()
        if type(isfolder) == "function" and type(makefolder) == "function" then
            if not isfolder("EnderHub") then
                makefolder("EnderHub")
            end
        end
    end)
    pcall(writefile, HX.LANG_FILE, tostring(code or "en"))
end

    return Api
end)()
HX.bootStage("api-ready")

if type(runtime.Api) == "table" and type(runtime.Api.gate) == "function" then
    Api = runtime.Api
else
    runtime.Api = Api
    pcall(Api.setProfile, Players.LocalPlayer)
end

HX.LOC_RECORDS = {
    en = [[ACCESS_REQUIRED=Access RequiredALL_FEATURES_TURNED_OFF=All tool features turned offALL_HIGHLIGHTS_CLEARED=All highlights clearedALL_TOOLS_EQUIPPED=All Tools EquippedANTIS_SEC_CHAR_PROT_DESC=Protects your character movement and physicsANTIS_SEC_CHAR_PROT_TITLE=Character ProtectionANTIS_SEC_RESET_PROT_DESC=Protections that reset and return you to your exact spotANTIS_SEC_RESET_PROT_TITLE=Reset ProtectionANTIS_SEC_VISUAL_DESC=Remove annoying screen and lighting effectsANTIS_SEC_VISUAL_TITLE=VisualANTIS_TAB=AntisANTI_AFK_DESC=Prevents idle kicks and loops focused signal to serverANTI_AFK_NOTIFY_OFF=Anti AFK has been disabledANTI_AFK_NOTIFY_ON=Idle kick prevention and focused loop enabledANTI_AFK_TITLE=Anti AFKANTI_DRAG_DESC=Loops standing state and prevents sitting or draggingANTI_DRAG_NOTIFY_OFF=Anti Drag has been disabledANTI_DRAG_NOTIFY_ON=Anti Drag is now active and keeping you standingANTI_DRAG_TITLE=Anti DragANTI_FLING_DESC=Disables collisions on other players so they cannot fling youANTI_FLING_NOTIFY_OFF=Anti Fling has been disabledANTI_FLING_NOTIFY_ON=Player collisions disabled to prevent flingingANTI_FLING_TITLE=Anti FlingANTI_FLY_DESC=Prevents forced flying effects from being applied to youANTI_FLY_NOTIFY_OFF=Anti Fly has been disabledANTI_FLY_NOTIFY_ON=Blocking forced flying attributes on your characterANTI_FLY_TITLE=Anti FlyANTI_FREEZE_DESC=Resets when frozen or anchored and returns you to your old positionANTI_FREEZE_NOTIFY_OFF=Anti Freeze has been disabledANTI_FREEZE_NOTIFY_ON=Auto freeze recovery and position return enabledANTI_FREEZE_TITLE=Anti FreezeANTI_GLITCH_DESC=Cancels Farlands glitches and keeps your exact position and rotationANTI_GLITCH_NOTIFY_OFF=Anti Glitch has been disabledANTI_GLITCH_NOTIFY_ON=Farlands and high velocity glitch protection enabledANTI_GLITCH_TITLE=Anti GlitchANTI_INVISIBLE_DESC=Resets if your character is hidden and returns you to your old positionANTI_INVISIBLE_NOTIFY_OFF=Anti Invisible has been disabledANTI_INVISIBLE_NOTIFY_ON=Hidden character detection and position return enabledANTI_INVISIBLE_TITLE=Anti InvisibleANTI_JAIL_DESC=Disables collisions on jail parts around your characterANTI_JAIL_NOTIFY_OFF=Anti Jail has been disabledANTI_JAIL_NOTIFY_ON=Jail part collisions are now bypassedANTI_JAIL_TITLE=Anti JailANTI_MAPTIDE_DESC=Keeps your exact position and rotation or resets if none existsANTI_MAPTIDE_NOTIFY_OFF=Anti Maptide Nan has been disabledANTI_MAPTIDE_NOTIFY_ON=Void and NaN position recovery enabledANTI_MAPTIDE_TITLE=Anti Maptide NanANTI_MUTE_DESC=Work in progressANTI_MUTE_NOTIFY_OFF=Anti Mute has been disabledANTI_MUTE_NOTIFY_ON=Anti Mute is enabledANTI_MUTE_TITLE=Anti Mute (Rejoin Method)ANTI_NOCLIP_DESC=Prevents forced noclip collision groups on your characterANTI_NOCLIP_NOTIFY_OFF=Anti Noclip has been disabledANTI_NOCLIP_NOTIFY_ON=Anti Noclip is now managing character collisionsANTI_NOCLIP_TITLE=Anti NoclipANTI_TELEPORT_DESC=Cancels teleports and keeps your exact position and facingANTI_TELEPORT_NOTIFY_OFF=Anti Teleport has been disabledANTI_TELEPORT_NOTIFY_ON=Teleport protection is locking your position and rotationANTI_TELEPORT_TITLE=Anti TeleportANTI_VAMPIRE_DESC=Prevents Vampire gear from locking your camera and inventoryANTI_VAMPIRE_NOTIFY_OFF=Anti Vampire has been disabledANTI_VAMPIRE_NOTIFY_ON=Camera and backpack lock protection enabledANTI_VAMPIRE_TITLE=Anti VampireAPPEARANCE_TAB=AppearanceARKENSTONE_TARGET_DESC=Target anyone who gets The ArkenstoneASSET_ID_PLACEHOLDER=rbxassetid://0 or https://...AURAS=AurasAURA_METHOD=Aura MethodAURA_METHOD_DESC=Delete and paint tools onlyAURA_RANGE=Aura RangeAURA_RANGE_DESC=Range in studsAURA_SETTINGS=Aura SettingsAUTOLOAD_CONFIG=Autoload ConfigAUTOMATION=AutomationAUTOPICKUP_OFF=Auto Pickup Enlighten has been disabledAUTOPICKUP_ON=Fast Arkenstone pickup is now activeAUTOSAVE_ARMED=Instant death save is now armedAUTOSAVE_CONFIG=Autosave ConfigAUTOSAVE_DISABLED=Auto Save Enlighten has been disabledAUTO_BUILD_TITLE=Auto BuildAUTO_CLEARINV_DESC=Sends ;clearinv on your chosen targets the moment they hold The ArkenstoneAUTO_CLEARINV_TARGETS_DESC=Everyone, or a hand-picked listAUTO_CLEARINV_TARGETS_TITLE=Clearinv TargetsAUTO_CLEARINV_TITLE=Auto ClearinvAUTO_COLLECTING_OFF=Auto collect stoppedAUTO_COLLECTING_ON=Auto collecting dropped toolsAUTO_DROP_ALL_TOOLS_IF_DIED=Drop All Tools On DeathAUTO_DROP_OFF=Auto drop stoppedAUTO_DROP_ON=Tools will drop on deathAUTO_DROP_ON_DEATH=Auto Drop On DeathAUTO_PICKUP_DESC=Fast automatic detection and pickup for a dropped ArkenstoneAUTO_PICKUP_DROPPED_TOOLS=Auto Pickup Dropped ToolsAUTO_PICKUP_OFF=Auto Pickup Enlighten disabledAUTO_PICKUP_ON=Fast Arkenstone pickup activeAUTO_PICKUP_TITLE=Auto Pickup Dropped EnlightenAUTO_PICKUP_TOOLS=Auto Pickup ToolsAUTO_RESIZE_WAIT=Automatically Set Resize WaitAUTO_RIG_OPTION=AutoAUTO_RIG_OPTION_DESC=Use your current rig typeAUTO_SAVE_ENLIGHTEN_DESC=Instantly saves your enlighten and rerigs you when you dieAUTO_SAVE_ENLIGHTEN_TITLE=Auto Save EnlightenAUTO_SAVE_OFF=Auto Save Enlighten disabledAUTO_SAVE_ON=Instant death save is armedAUTO_SAVE_RIG_TYPE_DESC=Choose R6 or R15 for Auto Save EnlightenAUTO_SAVE_RIG_TYPE_TITLE=Auto Save Rig TypeBACKGROUND_WORD=BackgroundBANNED_PERMANENT=You have been banned (permanent)BANNED_TEMP=You have been banned (%s)BLOCKS_TRACERS=Blocks TracersBLOCKS_TRACERS_DESC=Draw lines to every highlighted brickBOOMBOX_DESC=Click any boombox in the world to read its sound idBOOMBOX_INFO=Boombox: %s
Sound ID: %s
Press Copy Sound ID to grab itBOOMBOX_INFO_NOSOUND=Boombox: %s
No sound playingBOOMBOX_SECTION=Boombox SelectBOOMBOX_SELECTED=Boombox SelectedBOOMBOX_SELECT_TITLE=Boombox Select (buggy)BRICK_HISTORY=Brick HistoryBRICK_HISTORY_DESC=Number of bricks kept in historyBUILD_AURA=Build AuraBUILD_AURA_DESC=Places bricks around youBUILD_DELETED=Build DeletedBUILD_DISPLAYED=Build DisplayedBUILD_LOADED=Build LoadedBUILD_MODE=Build ModeBUILD_MODE_DESC=Normal, detailed or alternatingBUILD_PERF_NOTE=Turn on Performance Stats so the automatic resize wait calibrates properlyBUILD_PROGRESS=Build Progress: %d%% (%d/%d)BUILD_PROGRESS_NONE=Build Progress: no build runningBUILD_SAVED=Build SavedBUILD_SECTION_DESC=Load, save and display brick buildsBUILD_SECTION_TITLE=Auto BuildBUILD_SETTINGS=SettingsBUILD_TAB=BuildBUILD_THANKS=Special thanks to @2AreYouMentalBY_QILEX=By QilexCANCEL=CancelCHARACTER_NOT_FOUND=Character not foundCHOOSE_MATERIAL=Choose MaterialCHOOSE_MATERIAL_DESC=Material used by the material auraCLEARED=ClearedCLEARED_DESC=All boombox highlights removedCLEARINV_OFF=Auto Clearinv disabledCLEARINV_ON=Auto Clearinv active for the selected targetsCLEAR_HIGHLIGHTS=Clear HighlightsCLOSE_SCRIPT=Close ScriptCLOSE_WINDOW_BODY=Do you want to close this window? You will not be able to open it again.CLOSE_WINDOW_BUTTON=Close WindowCLOSE_WINDOW_TITLE=Close WindowCONFIG_CREATOR=Config CreatorCONFIG_LOADER=Config LoaderCONFIG_MANAGER_DESC=Create, load, save, and manage your hub configsCONFIG_NAME=Config NameCONFIG_NAME_PLACEHOLDER=mainCONFIG_WARNING=Config WarningCONFIG_WORD=ConfigCOPIED=Copied!COPIED_DESC=Discord link copied to clipboardCOPY_DISCORD=Copy DiscordCOPY_KEY=Copy keyCOPY_KEY_LABEL=Copy KeyCOPY_SOUND_ID=Copy Sound IDCORAVEN_LITE=Coraven LiteCREATE_CONFIG=Create ConfigCREDITS_TITLE=CREDITS:CUSTOM_BACKGROUND=Custom BackgroundCUSTOM_FLY=Custom FlyCUSTOM_FLY_DESC=BodyVelocity flight - WASD to move, Space up, Shift downDELETE_AURA=Delete AuraDELETE_AURA_DESC=Deletes bricks around youDELETE_BUILD=Delete BuildDELETE_CONFIG=Delete ConfigDESCRIPTION_TEXT=This script is designed for The Chosen One.
Griefing, building and mechanic abuse live in their own tabs.
The hub never breaks game scripts, only talks to them.DETECTOR_OFF=Enlighten Detector has been disabledDETECTOR_ON=Now scanning players for The ArkenstoneDISABLED=DisabledDISPLAY_BUILD=Display BuildDROPDOWN_PLACEHOLDER=Select...DROP_ALL_TOOLS=Drop All ToolsENABLED=EnabledENABLE_FLY=Enable FlyENABLE_MUSIC=Enable MusicENDER_HUB=Ender HubENDER_HUB_V2=Ender Hub V2ENLIGHTEN_DETECTED=Enlighten DetectedENLIGHTEN_DETECTED_DESC=%s got The ArkenstoneENLIGHTEN_DETECTOR=Enlighten DetectorENLIGHTEN_TAB=EnlightenENLIGHTEN_UTILITIES_DESC=Use the Arkenstone without holding it and monitor server holdersENLIGHTEN_UTILITIES_SECTION=Enlighten UtilitiesENTER_KEY=Enter Your KeyEQUIP_ALL_TOOLS=Equip All ToolsEQUIP_SELECTED_TOOLS=Equip Selected ToolsERROR=ErrorESP_CHOSEN=Chosen ESPESP_CHOSEN_DESC=Highlight players on the Chosen teamESP_CLEAR=Clear All ESPESP_CLEARED=ESP ClearedESP_CLEARED_DESC=All ESP removedESP_PLAYERS=Players ESPESP_PLAYERS_DESC=Highlight every non-chosen playerESP_TAB=VisualsEVERYONE=EveryoneEXIT=ExitFEATURES_OFF=All local player features turned offFILE_NAME_PLACEHOLDER=Enter file nameFILE_NAME_SAVE=File Name To SaveFINDING_2_SPOTS=Finding server with 2 available spots...FINDING_LOWEST=Finding lowest population server...FINDING_MEDIUM=Finding medium population server...FINDING_SERVER=Finding %s serverFINDING_VC=Finding Voice Chat server...FINDING_XL=Finding XL server...FLY_GROUP=FlyFLY_SECTION=Fly SectionFLY_SECTION_DESC=Flight mechanics and controlsFLY_SPEED=Fly SpeedFOUND_BOOMBOXES=Found %d boombox(es)GAME_FLY=Game FlyGAME_FLY_DESC=Use the game's own flying attributeGITHUB_WORD=GithubGOT_ARKENSTONE=%s got The Arkenstone!GRIEF_EVIL_DESC=What you thinking is evil..GRIEF_GUARD=Grief Valtiel = banned from this featureGRIEF_SCROLL_NOTE=Scroll down for the griefing aurasGRIEF_SECTION_DESC=What you are thinking is evilGRIEF_SECTION_TITLE=GriefGRIEF_STEAL_DESC=mhhh i feel like i wanna steal bulidGRIEF_TAB=GriefHELPER=Helper: 2AreYouMentalHIGHLIGHT_PLAYER_BUILD=Highlight Player BuildHUB_OFFLINE=Ender Hub is offlineIMAGE_ASSET_ID=Image / Asset IDINFINITE_JUMP=Infinite JumpINFINITE_JUMP_DESC=Jump again while airborneINFINITE_YIELD=Infinite YieldINFO_DESC=Script By: Qilex
Discord: https://discord.gg/PVc5fxjz

This Script Designed To Use On The Chosen One Game.
We Have Cool Features And Content Tabs where you can use to Grief, Build, or Abuse the game mechanics!

âš ï¸ Warning: this script is not designed to break any game scripts

ðŸ“˜ Be Careful when using it

CREDITS:
â€¢ Script Creator: Qilex
â€¢ Helper: 2AreYouMental
â€¢ UI Library: Wind Ui
â€¢ Theme Creator: FaloINFO_FPS=FPSINFO_PING=PingINFO_PLAYERS=PlayersINFO_REGION=RegionINFO_SECTION=InformationINFO_SERVER=ServerINFO_SESSION=SessionINFO_TAB=InformationINFO_UNKNOWN=UnknownINFO_UPTIME=UptimeIY_CODE_TITLE=Infinite Yield CodeJOINING_NORMAL=Joining Normal ServerJOINING_SERVER=Joining %s server with %d playersJOINING_SERVER_TITLE=Joining ServerJOINING_VC=Joining VC ServerJOINING_XL=Joining XL ServerJOIN_DISCORD=Join DiscordJOIN_NORMAL_2_SPOTS=Join Normal (2 Spots)JOIN_NORMAL_LOW_POP=Join Normal (Low Pop)JOIN_NORMAL_MEDIUM_POP=Join Normal (Medium Pop)JOIN_SERVER=Join ServerJOIN_VC_SERVER=Join VC ServerJOIN_XL_SERVER=Join XL ServerKEYBIND_SET=Keybind SetKEYBIND_SET_DESC=UI toggle keybind updatedKEYBIND_UPDATED=UI toggle keybind updated to %sKEY_GET=Get KeyKEY_HINT=Click the island to hide the key systemKEY_REQUIRED=Key RequiredKEY_REQUIRED_NOTE=Key is required to use the script - get yours at discord.gg/enderhub - one key per account.KEY_SYSTEM=Key SystemKEY_VALID=Key ValidLANGUAGE_CHANGED=Language ChangedLANGUAGE_DESC=Select interface languageLANGUAGE_SELECTOR=Language SelectorLANGUAGE_SWITCHED=Language switched to %sLANGUAGE_WORD=LanguageLANG_PACK_UNAVAILABLE=Language pack unavailable - reconnect and try again.LATER=LaterLIBRARY=LibraryLOADED_SUCCESSFULLY=%s loaded successfully!LOADING_MODULES=Loading modules, ui, services...LOADING_STAGE=Loading %sLOADING_UI=Loading modules, ui...LOAD_BUILD=Load BuildLOAD_CONFIG=Load ConfigLOCALPLAYER_DESC=Movement, flight and character extrasLOCALPLAYER_LONG_DESC=Control Movment And Fly and More!LOCALPLAYER_TAB=LocalPlayerLOCAL_PLAYER_HEADER=Local PlayerLOCKED=LockedLOOK_CLEAR_NOON=Clear NoonLOOK_DAWN=DawnLOOK_DEFAULT=DefaultLOOK_DUSK=DuskLOOK_FOGGY_MORNING=Foggy MorningLOOK_GOLDEN_HOUR=Golden HourLOOK_NIGHT=NightLOOK_OVERCAST=OvercastLOOK_RAINY_AFTERNOON=Rainy AfternoonLOOK_SNOWY_DAY=Snowy DayLOOK_STORMY=StormyLOOK_SUNNY_MORNING=Sunny MorningLOOK_SUNSET=SunsetMAIN_SECTION=Main SectionMAIN_TAB=MainMATERIAL_AURA=Material AuraMATERIAL_AURA_DESC=Applies the chosen material to bricks around youMUSIC_DESC=Dynamic Island player and mini playerMUSIC_EFFECTS=Music Effects On WindowMUSIC_EFFECTS_DESC=Tints the window and draws bars across its floor while music playsMUSIC_WORD=MusicNOCLIP=NoclipNOCLIP_DESC=Disable collisions on every character partNOHOLD_OFF=Use Without Holding has been disabledNOHOLD_ON=Enlighten background hold & TextChatService command equip activeNOTHING_PLAYING=Nothing playingNOTIFY_HOLDER_DESC=Notifies you whenever someone in the server gets The ArkenstoneNOTIFY_HOLDER_TITLE=Notify Enlighten HolderNOTIFY_OFF=Enlighten detector disabledNOTIFY_ON=Now scanning players for The ArkenstoneNO_BOOMBOXES_FOUND=No boomboxes found on this serverNO_BOOMBOX_HINT=No boombox selected
Click on a boombox to select itNO_BOOMBOX_SELECTED=No boombox selectedNO_BOOMBOX_SELECTED_DESC=Click on a boombox to select itNO_BUILD_SELECTED=No build file selectedNO_HOLD_OFF=Use Without Holding disabledNO_HOLD_ON=Enlighten background hold and command equip activeNO_RESULTS=No results foundNO_SERVERS=No public servers foundNO_SERVERS_TITLE=No ServersNO_SOUND_ID=No sound id to copyNO_SOUND_PLAYING=No sound playingNO_TOOL=Tool not foundNO_TOOLS_SELECTED=No Tools SelectedOFF=OFFOFFLINE_BODY=Every feature is stopped while the hub is down. Nothing on your account changed - re-execute once the notice is lifted.OFFLINE_REASON=Reason: <b>%s</b>ON=ONOTHERS_GROUP=OthersOTHERS_SECTION=Others SectionOTHERS_SECTION_DESC=Additional character abilitiesOTHER_SCRIPTS_SECTION=Other ScriptsPAINT_AURA=Paint AuraPAINT_AURA_COLOR=Paint Aura ColorPAINT_AURA_DESC=Paints bricks around you with your colourPAUSED=PausedPC_ONLY=PC OnlyPC_ONLY_DESC=Freecam needs a keyboard and mousePING=Ping: %sPLAYERS=PlayersPLAYER_BUILD_SAVED=Player Build SavedPLEASE_SELECT_TOOLS_FIRST=Select tools firstPREMIUM=PremiumPREMIUM_REQUIRED=Premium requiredQUICK_JOIN_SECTION=Quick JoinR15_OPTION_DESC=Use ;r15 me on death saveR6_OPTION_DESC=Use ;r6 me on death saveRANGE_SHAPE=Range ShapeRANGE_SHAPE_DESC=Range detection shapeREADY_TO_COOK=Ready to cookREDO_EMPTY=Nothing to redoREFRESH_FOLDER=Refresh FolderREFRESH_TOOL_LIST=Refresh Tool ListRESET_MODE_DROPDOWN_DESC=Choose where to spawn after a protection resetRESET_MODE_DROPDOWN_TITLE=Reset Return ModeRESET_OPT_NONE_DESC=Respawn normally without teleporting backRESET_OPT_NONE_TITLE=NoneRESET_OPT_SPAWN_LAST_POS_DESC=Returns you to your last grounded positionRESET_OPT_SPAWN_LAST_POS_TITLE=Spawn Last PositionRESIZE_PERF_HINT=To make the Automatically Set Resize Wait work better, turn on Performance Stats.RESIZE_TIME=Resize TimeRESIZE_TIME_DESC=Set the resize delay in secondsRESIZE_WAIT=Resize Wait: %sRESPAWNED_AT=Respawned at Saved LocationRESPAWNED_AT_DESC=Teleported to the previous positionRESPAWN_SAME_LOCATION=Respawn Same LocationRESPAWN_SAME_LOCATION_DESC=Return to the spot you died onRESPAWN_SAVED=Respawn Location SavedRESPAWN_SAVED_DESC=Position saved for respawnRESTART_NOW=Restart nowRIG_SAVE_AUTO=Auto save will use your current rig typeRIG_SAVE_R15=Auto save will use ;r15 meRIG_SAVE_R6=Auto save will use ;r6 meRIG_SAVE_SET=Save Rig TypeSAVED_AND_APPLIED=Saved and appliedSAVED_CONFIGS=Saved ConfigsSAVED_THEME=Saved ThemeSAVE_AND_APPLY=Save & ApplySAVE_CONFIG=Save ConfigSAVE_ENLIGHTEN_DESC=Automatically secure and save The Arkenstone from being lostSAVE_ENLIGHTEN_SECTION=Save EnlightenSAVE_PLAYER_BUILD=Save Player BuildSAVE_SERVER_BUILDS=Save Server BuildsSAVE_TOOLS_DESC=Save Tools EtcSCAN_COMPLETE=Scan CompleteSCAN_HINT=Click 'Scan Server' to find all boomboxesSCAN_SERVER=Scan ServerSCRIPTS_TAB=ScriptsSCRIPT_CREATOR=Script Creator: QilexSCRIPT_EXECUTED=Script ExecutedSCRIPT_EXECUTED_DESC=Join the discord for more featuresSCRIPT_EXECUTED_TITLE=Script ExecutedSCRIPT_LOADED=Script LoadedSEARCH_PLACEHOLDER=Search...SELECTED_BOOMBOX=Selected BoomboxSELECT_MATERIAL_DESC=Select materialSELECT_METHOD_DESC=Select method (Delete & Paint tools only)SELECT_PLAYER=Select PlayerSELECT_PLAYER_DESC=Choose a player to save their buildSELECT_SAVED_BUILDS=Select Saved Build FilesSELECT_SAVED_BUILDS_DESC=Choose a build file to loadSELECT_SERVICE=Select ServiceSELECT_TOOLS=Select ToolsSELECT_TOOLS_DESC=Choose tools from your inventorySERVER_BOOMBOXES=Server BoomboxesSERVER_BOOMBOXES_DESC=Scan the server and list every boombox with its sound idSERVER_HIGHEST=Highest PopulationSERVER_HOP=Server HopSERVER_HOPPER=Server HopperSERVER_HOPPING=Finding a new %s serverSERVER_HOP_SECTION=Server HoppingSERVER_LIST_BUTTON=Server List (By Mental)SERVER_LIST_LOADED=Server Hopper loadedSERVER_LIST_MENTAL=Server List Script By MentalSERVER_LIST_SCRIPT=Server Hopper / ListSERVER_LIST_SECTION=Server ListSERVER_LOWEST=Lowest PopulationSERVER_MEDIUM=Medium PopulationSERVER_NONE=NoneSERVER_NORMAL=NormalSERVER_PRIVATE=PrivateSERVER_PUBLIC=PublicSERVER_RESERVED=ReservedSERVER_SELECT_TYPE_FIRST=Select a server type firstSERVER_SIZE=Server Size PreferenceSERVER_SIZE_DESC=Select the preferred server populationSERVER_SIZE_SELECTED=Server Size SelectedSERVER_SNIPE_HEADER=Server SnipeSERVER_SNIPE_TAB=Server SnipeSERVER_TYPE=Server TypeSERVER_TYPE_DESC=Select the server type to joinSERVER_TYPE_SECTION=Server TypeSERVER_TYPE_SELECTED=Server Type SelectedSERVER_VC=VCSERVER_WITH_PLAYERS=%s server with %s playersSERVER_XL=XLSESSION_OPEN=Session OpenSETTINGS_TAB=SettingsSHOVEL_AURA=Shovel AuraSHOVEL_AURA_DESC=Digs or fills terrain around youSHOVEL_MODE=Shovel ModeSHOVEL_MODE_DESC=Dig or fill terrainSHUFFLE_WORD=ShuffleSIGN_AURA=Sign AuraSIGN_AURA_DESC=Places signs around youSILENT_TAB=SilentSKIP_BLOCK=Skip BlockSKY_BIG_SUN=Big SunSKY_CLEAR=Clear SkySKY_DEFAULT=DefaultSKY_FULL_MOON=Full MoonSKY_MOONLESS=Moonless NightSKY_NEBULA=Purple NebulaSKY_STARFIELD=StarfieldSKY_TINY_SUN=Tiny SunSOUND_ID_COPIED=Sound ID %s copiedSOUND_ID_LABEL=Sound ID: %sSPAM_EQUIPPED_TOOL=Spam Equipped ToolSPAM_OFF=Spam stoppedSPAM_ON=Spamming equipped toolsSPEED_GROUP=SpeedSPEED_SECTION=Speed SectionSPEED_SECTION_DESC=Control your movement speedSPEED_TOGGLE=SpeedSPEED_TOGGLE_DESC=Override your humanoid walkspeedSUBMIT=SubmitSUCCESS=SuccessTAB_EMPTY=This tab is EmptyTCO_CODE_TITLE=The Chosen One Scripts CodeTCO_EXTRAS=TCO ExtrasTCO_SCRIPTS_SECTION=TCO ScriptsTELEPORTED_BACK=Teleported to previous positionTHEME_ACCENT=AccentTHEME_BACKGROUND=BackgroundTHEME_BUTTON=ButtonTHEME_CHANGED=Theme ChangedTHEME_CREATOR=Theme Creator: FaloTHEME_DARK=Dark ThemeTHEME_DARK_DESC=Switched to the dark themeTHEME_DIALOG=DialogTHEME_ICON=IconTHEME_LIGHT=Light ThemeTHEME_LIGHT_DESC=Switched to the light themeTHEME_NAME=Theme NameTHEME_NAME_PLACEHOLDER=My ThemeTHEME_OUTLINE=OutlineTHEME_PLACEHOLDER=PlaceholderTHEME_SWITCHED_TO=Switched to %sTHEME_TEXT_BOTTOM=Text BottomTHEME_TEXT_TOP=Text TopTHEME_WORD=ThemeTOOLS=toolsTOOLS_ABUSE_SECTION=Tools AbuseTOOLS_COUNT=%s toolsTOOLS_DROPPED=Tools DroppedTOOLS_DROPPED_COUNT=%s tools droppedTOOLS_EQUIPPED=Tools EquippedTOOLS_EQUIPPED_COUNT=%s tools equippedTOOLS_FEATURES=Tools FeaturesTOOLS_SAVE_SECTION=Tools SaveTOOLS_SECTION_DESC=Save tools, equip tools, spam toolsTOOLS_SECTION_TITLE=ToolsTOOLS_SELECTED=Tools SelectedTOOLS_TAB=ToolsTOOLS_TAB_CLEANED_UP=Tools tab cleaned upTOOL_INVENTORY_UPDATED=Tool inventory updatedTOOL_LIST_REFRESHED=Tool List RefreshedTOOL_MISSING=Tool MissingTOOL_SELECTOR_SECTION=Tool SelectorTOXIC_AURA=Toxic AuraTOXIC_AURA_DESC=Sends toxic paint to bricks around youUI_KEYBIND=UI KeybindUI_KEYBIND_DESC=Keybind to hide or show the interfaceUI_LIBRARY=UI Library: Wind UIUI_WORD=UIUNANCHOR_AURA=Unanchor AuraUNANCHOR_AURA_DESC=Unanchors bricks around youUNDO_EMPTY=Nothing to undoUPDATE_DIALOG_BODY=A new update is on the server. Restart now to load (%s)UPDATE_QUEUED=Update queuedUPDATE_QUEUED_DESC=The hub updates the next time you execute it.UPDATE_REEXEC=Re-execute the script to load the new build.UPDATE_TITLE=Ender Hub updatedUPDATE_TOAST_CONTENT=Restart to load %sUPDATE_TOAST_TITLE=Ender Hub has been updatedUSE_WITHOUT_HOLDING_DESC=Keeps Enlighten active so its commands always landUSE_WITHOUT_HOLDING_TITLE=Use Without HoldingVISUAL_OPT_ALL_DESC=Block all visual effectsVISUAL_OPT_ALL_TITLE=AllVISUAL_OPT_BLIND_DESC=Removes the screen blind UIVISUAL_OPT_BLIND_TITLE=BlindVISUAL_OPT_COLORLESS_DESC=Removes monochrome colour correctionVISUAL_OPT_COLORLESS_TITLE=ColorlessVISUAL_OPT_CURSED_DESC=Removes cursed and RGB screen effectsVISUAL_OPT_CURSED_TITLE=CursedVISUAL_OPT_FOG_DESC=Removes atmosphere fog densityVISUAL_OPT_FOG_TITLE=FogVISUAL_OPT_MYOPIC_DESC=Removes blur and depth of fieldVISUAL_OPT_MYOPIC_TITLE=MyopicVISUAL_PROT_DROPDOWN_DESC=Select visual effects to blockVISUAL_PROT_DROPDOWN_TITLE=Visual ProtectionsVISUAL_TOGGLE_DESC=Activates protection for the selected visual effectsVISUAL_TOGGLE_NOTIFY_OFF=Visual effect protection has been disabledVISUAL_TOGGLE_NOTIFY_ON=Actively blocking the selected visual effectsVISUAL_TOGGLE_TITLE=Turn On SelectedWAITING_FOR_KEY=Waiting for keyWALKSPEED=WalkspeedWALKSPEED_AMOUNT=Walkspeed AmountWALKTP=Walk TPWALKTP_DESC=Teleport while walking at the configured stepWALKTP_SPEED=Walk TP SpeedWANT_MORE_FEATURES=Wanna request more Features? join the discord!WARNING_SECTION=Warning SectionWARNING_TEXT=This feature may not work on every executor or serverWELCOME_USER=Welcome, %sWINDOW_WORD=WindowWIRING_SERVICES=Wiring servicesWORLD_AMBIENCE=AmbienceWORLD_AMBIENCE_OFF=OffWORLD_AMBIENCE_RAIN=RainWORLD_AMBIENCE_STORM=StormWORLD_AMBIENCE_THUNDER=ThunderWORLD_AMBIENCE_TOGGLE=Toggle ambienceWORLD_ASPECT_RATIO=Aspect ratioWORLD_ATMOSPHERE=AtmosphereWORLD_BLOOM=BloomWORLD_BLUR=BlurWORLD_BRIGHTNESS=BrightnessWORLD_CAMERA=CameraWORLD_COLOR=ColorWORLD_COLOR_CORRECTION=Color correctionWORLD_COLOR_GRADING=Color gradingWORLD_CONTRAST=ContrastWORLD_DENSITY=DensityWORLD_ENVIRONMENT=EnvironmentWORLD_FOV=FOVWORLD_FOV_CHANGER=FOV changerWORLD_HAZE=HazeWORLD_INTENSITY=IntensityWORLD_LOOK=LookWORLD_POST_FX=Post FXWORLD_PRESET=PresetWORLD_RAIN=RainWORLD_RAIN_SOUND=Rain soundWORLD_RATIO_X=Ratio XWORLD_RATIO_Y=Ratio YWORLD_RESET=Reset worldWORLD_SATURATION=SaturationWORLD_SIZE=SizeWORLD_SKYBOX=SkyboxWORLD_SNOW=SnowWORLD_SPREAD=SpreadWORLD_SUN_RAYS=Sun raysWORLD_TAB=WorldWORLD_THRESHOLD=ThresholdWORLD_THUNDER=ThunderWORLD_WEATHER=WeatherWORLD_WEATHER_CLEAR=ClearWORLD_WEATHER_RAIN=RainWORLD_WEATHER_SNOW=SnowWORLD_WEATHER_STORM=StormWORLD_WEATHER_TOGGLE=Toggle weatherWORLD_WIND_SOUND=Wind soundZTE_HUB=ZTE HubCREDITS_HEADER=CreditsCREDITS_OWNER=OwnerCREDITS_CO_OWNER=Co OwnerCREDITS_LEAD_DEV=Lead DevCREDITS_DEV=DeveloperFEEDBACK_TITLE=FeedbackFEEDBACK_DESC=Tell us what works and what does not - it goes straight to the teamFEEDBACK_PLACEHOLDER=Type your feedback here...FEEDBACK_SEND=Send feedbackFEEDBACK_SEND_DESC=Posts to the team with your username attachedFEEDBACK_EMPTY=Write something firstFEEDBACK_SENT=Feedback sent - thank youFEEDBACK_FAILED=Could not send - try again in a momentFEEDBACK_BUTTON=FeedbackWELCOME_WORD=Welcome,CONFIRM_CANCEL=CancelCONFIRM_YES=YesINFO_HOP=Server HopINFO_HOP_DESC=Leave this server and join another public oneINFO_HOP_CONFIRM=Hop to a different server now?INFO_HOP_EMPTY=No other public server foundINFO_HOP_FAILED=Could not hop - try again in a momentINFO_REJOIN=RejoinINFO_REJOIN_DESC=Reconnect to this same serverINFO_REJOIN_CONFIRM=Reconnect to this server now?INFO_REJOIN_FAILED=Could not rejoin - try again in a moment]],

}
HX.LOC_SEP = string.char(1)
HX.LOC_ITEM = "([^" .. HX.LOC_SEP .. "]*)" .. HX.LOC_SEP

do
    local late = {
        WELCOME_USER = "Welcome, %s",
        INFO_REGION = "Region",
        INFO_PING = "Ping",
        INFO_FPS = "FPS",
        INFO_PLAYERS = "Players",
        INFO_UPTIME = "Uptime",
        INFO_SESSION = "Session",
        INFO_SERVER = "Server",
        SERVER_PUBLIC = "Public",
        SERVER_PRIVATE = "Private",
        SERVER_RESERVED = "Reserved",
        INFO_UNKNOWN = "Unknown",
        MUSIC_EFFECTS = "Music Effects On Window",
        MUSIC_EFFECTS_DESC = "Tints the window and draws bars across its floor while music plays",
        UNDO_EMPTY = "Nothing to undo",
        REDO_EMPTY = "Nothing to redo",
        BUILD_PROGRESS = "Build Progress: %s%% (%s/%s)",
        PREMIUM = "Premium",
        LOCKED = "Locked",
        CLOSE_WINDOW_TITLE = "Close Window",
        CLOSE_WINDOW_BODY = "Do you want to close this window? You will not be able to open it again.",
        CLOSE_WINDOW_BUTTON = "Close Window",
        CANCEL = "Cancel",
    }
    local record = HX.LOC_RECORDS.en or ""
    local extra = {}
    for key, value in pairs(late) do
        if not string.find(record, HX.LOC_SEP .. key .. "=", 1, true)
            and not string.find(record, "^" .. key .. "=") then
            extra[#extra + 1] = key .. "=" .. value
        end
    end
    if #extra > 0 then
        HX.LOC_RECORDS.en = record .. HX.LOC_SEP .. table.concat(extra, HX.LOC_SEP)
    end
end

function HX.unpackLocale(record)
    local entries = {}
    
    for item in string.gmatch(record .. HX.LOC_SEP, HX.LOC_ITEM) do
        local key, value = string.match(item, "^([^=]+)=(.*)$")
        if key then entries[key] = value end
    end
    return entries
end

function HX.inlineLocalization()
    local translations = {}
    for code, record in pairs(HX.LOC_RECORDS) do
        translations[code] = HX.unpackLocale(record)
    end
    return {
        Enabled = true,
        Prefix = "loc:",
        DefaultLanguage = "en",
        Translations = translations,
    }
end

HX.language = "en"
HX.localization = nil
HX.switchingLanguage = false
HX.languageCache = {}

function HX.hasLanguage(code)
    local store = HX.localization
    if type(store) ~= "table" or type(store.Translations) ~= "table" then
        return false
    end
    return type(store.Translations[code]) == "table"
end

function HX.storeLanguage(code, bundle)
    if type(code) ~= "string" or type(bundle) ~= "table" then return false end
    if type(HX.localization) ~= "table" then return false end
    if type(HX.localization.Translations) ~= "table" then
        HX.localization.Translations = {}
    end
    HX.localization.Translations[code] = bundle
    HX.languageCache[code] = true

    HX.textIndex = {}
    return true
end

HX.LANG_CACHE_DIR = "EnderHub/languages"

HX.LANG_CACHE_EPOCH = "2026-11-16-c"

function HX.langCachePath(code)
    return HX.LANG_CACHE_DIR .. "/" .. HX.LANG_CACHE_EPOCH .. "-" .. tostring(code) .. ".luau"
end

function HX.langCacheRead(code)
    if type(readfile) ~= "function" then return nil end
    local ok, source = pcall(readfile, HX.langCachePath(code))
    if ok and type(source) == "string" and #source > 16 then
        return source
    end
    return nil
end

function HX.langCacheWrite(code, source)
    if type(writefile) ~= "function" then return end
    pcall(function()
        if type(isfolder) == "function" and type(makefolder) == "function"
            and not isfolder(HX.LANG_CACHE_DIR) then
            makefolder(HX.LANG_CACHE_DIR)
        end
        writefile(HX.langCachePath(code), source)
    end)
end

function HX.loadLanguage(code, source)
    if type(source) ~= "string" or #source < 16 then return false end
    local ok, bundle = pcall(function()
        local chunk = runtime.Compile(source, "lang:" .. tostring(code))
        if type(chunk) ~= "function" then return false end
        return chunk()
    end)
    if not ok or type(bundle) ~= "table" then return false end
    return HX.storeLanguage(code, bundle)
end

function HX.fetchLanguage(code)
    local cached = HX.langCacheRead(code)
    if cached and HX.loadLanguage(code, cached) then
        return true
    end
    if type(runtime.Fetch) ~= "function" then return false end
    local ok, source = pcall(runtime.Fetch, "languages/" .. tostring(code) .. ".luau")
    if not ok or type(source) ~= "string" or #source < 16 then return false end
    if not HX.loadLanguage(code, source) then return false end
    HX.langCacheWrite(code, source)
    return true
end

HX.languageCodes = {
    "en", "es", "ar", "ru", "de", "fr", "he", "id",
    "it", "da", "pl", "pt", "tr", "vi", "zh", "ja", "ko",
}

function HX.prefetchLanguages()
    task.spawn(function()
        for _, code in ipairs(HX.languageCodes) do
            if not HX.hasLanguage(code) then
                pcall(HX.fetchLanguage, code)
            end
            task.wait(0.15)
        end
    end)
end

function HX.ensureLanguage(code, callback)
    if type(code) ~= "string" or code == "" then
        callback(false)
        return
    end
    if HX.hasLanguage(code) then
        callback(true)
        return
    end

    HX.rawTask.spawn(function()
        local ok = false
        pcall(function()
            ok = HX.fetchLanguage(code)
        end)
        HX.rawTask.spawn(function()
            pcall(callback, ok)
        end)
    end)
end

function HX.translate(key)
    local store = HX.localization
    if type(store) ~= "table" or type(store.Translations) ~= "table" then
        return key
    end
    local active = store.Translations[HX.language]
    if type(active) == "table" and active[key] ~= nil then
        return active[key]
    end
    local english = store.Translations.en
    if type(english) == "table" and english[key] ~= nil then
        return english[key]
    end
    return key
end

HX.textIndex = {}

local function escapePattern(text)
    return (string.gsub(text, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%1"))
end

function HX.retranslateText(text, index)
    if type(text) ~= "string" or text == "" then return nil end
    local exact = index.exact[text]
    if exact then
        return HX.translate(exact)
    end

    if index.keys[text] then
        return HX.translate(text)
    end
    for _, row in ipairs(index.patterns) do
        local captures = { string.match(text, row.pattern) }
        if #captures > 0 then
            local translated = HX.translate(row.key)
            local ok, formatted = pcall(string.format, translated, table.unpack(captures))
            if ok then
                return formatted
            end
        end
    end
    return nil
end

function HX.buildTextIndex(code)
    local cacheKey = "__all"
    local cached = HX.textIndex[cacheKey]
    if cached then return cached end

    local store = HX.localization
    local bundles = {}
    if type(store) == "table" and type(store.Translations) == "table" then
        
        if type(store.Translations.en) == "table" then
            bundles[#bundles + 1] = store.Translations.en
        end
        for lang, bundle in pairs(store.Translations) do
            if lang ~= "en" and type(bundle) == "table" then
                bundles[#bundles + 1] = bundle
            end
        end
    end

    local index = { exact = {}, patterns = {}, keys = {} }
    local seenPattern = {}
    for _, bundle in ipairs(bundles) do
        for key, value in pairs(bundle) do
            index.keys[key] = true
            if type(value) == "string" and value ~= "" then
                if index.exact[value] == nil then
                    index.exact[value] = key
                end
                if string.find(value, "%", 1, true) and not seenPattern[key] then
                    seenPattern[key] = true
                    local built = escapePattern(value)
                    built = string.gsub(built, "%%%%", function() return "%%" end)
                    built = string.gsub(built, "%%[%-%d%.]*[sdfq]", "(.-)")
                    table.insert(index.patterns, { key = key, pattern = "^" .. built .. "$" })
                end
            end
        end
    end
    
    table.sort(index.patterns, function(a, b)
        return #a.pattern > #b.pattern
    end)

    HX.textIndex[cacheKey] = index
    return index
end

function HX.retranslateTree(sourceCode)
    local window = nil
    pcall(function()
        window = genv().EnderHubRuntime and genv().EnderHubRuntime.WindUI
            and genv().EnderHubRuntime.WindUI.Window
    end)
    if type(window) ~= "table" then return 0 end

    local root = nil
    pcall(function()
        root = window.UIElements and window.UIElements.Main
    end)
    if typeof(root) ~= "Instance" then return 0 end

    local index = HX.buildTextIndex(sourceCode or "en")
    local changed = 0

    local function visit(instance)
        if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
            local nextText = HX.retranslateText(instance.Text, index)
            if nextText and nextText ~= instance.Text then
                instance.Text = nextText
                changed += 1
            end
            if instance:IsA("TextBox") then
                local nextPlaceholder = HX.retranslateText(instance.PlaceholderText, index)
                if nextPlaceholder and nextPlaceholder ~= instance.PlaceholderText then
                    instance.PlaceholderText = nextPlaceholder
                    changed += 1
                end
            end
        end
        for _, child in ipairs(instance:GetChildren()) do
            visit(child)
        end
    end

    for _, child in ipairs(root:GetChildren()) do
        visit(child)
    end
    return changed
end

do
    local localization = runtime.Localization
    if type(localization) ~= "table"
        or localization.Enabled ~= true
        or type(localization.Translations) ~= "table" then
        localization = HX.inlineLocalization()
    end
    HX.localization = localization
    HX.language = localization.DefaultLanguage or "en"
    pcall(function()
        WindUI:Localization(localization)
        WindUI:SetLanguage(HX.language)
    end)
end
HX.bootStage("localization")

HX.WindowOptions = {
    Title = "Ender Hub",
    Icon = "rbxassetid://84919257334887",
    IconSize = 35,
    Author = "loc:BY_QILEX",
    NewElements = true,
    Folder = "Ender Hub V2",
    Theme = "Dark",
    Radius = 22,
    HideSearchBar = false,
    User = { Enabled = true, Anonymous = false },
    Topbar = { Height = 44, ButtonsType = "Mac" },
}

HX.IslandPalette = {

    

    
}

HX.KeyGate = { needed = false, notice = nil }
HX.bootStage("keygate")

function HX.stageLabel(keyName)
    local template = HX.translate("LOADING_STAGE")
    if template == "LOADING_STAGE" then
        template = "Loading %s"
    end
    return string.format(template, HX.translate(keyName))
end

HX.bootStage("keycard-build")
HX.bootStage("keycard-built")

function HX.isUsableWindow(candidate)
    return type(candidate) == "table"
        and type(candidate.CreateTopbarButton) == "function"
end

function HX.rebuildWindUI()
    local embed = HX.embedText()
    local source
    if type(embed) == "string" and #embed > 10000 then
        source = embed
    else
        local function usable(text)
            if type(text) ~= "string" or #text < 10000 then return false end
            if not string.find(text, HX.WINDUI_MARK, 1, true) then return false end
            local stamp = tonumber(genv.EnderHubWindUIStamp)
            return stamp == nil or #text == stamp
        end
        source = genv.EnderHubWindUISource
        if not usable(source) then
            source = HX.cacheWindUI()
        end
        if not usable(source) then
            local ok, data = pcall(function()
                return game:HttpGet(HX.WINDUI_URL)
            end)
            if ok and usable(data) then
                source = data
                HX.storeWindUI(data)
            end
        end
    end
    if type(source) ~= "string"
        or #source < 10000
        or not string.find(source, HX.WINDUI_MARK, 1, true) then
        return nil
    end
    genv.EnderHubWindUISource = source

    local ok, module = pcall(function()
        return loadstring(source)()
    end)
    if ok and HX.isForkWindUI(module) and type(module.CreateWindow) == "function" then
        module.BootCard = false
        HX.hardenIcons(module)
        return module
    end
    return nil
end

function HX.adoptWindUI(module)
    HX.dropWindUIGuis(WindUI)
    WindUI = module
    module.BootCard = false
    runtime.WindUI = module
    HX.hardenIcons(module)

    
    local localization = runtime.Localization
    if type(localization) ~= "table"
        or localization.Enabled ~= true
        or type(localization.Translations) ~= "table" then
        localization = HX.inlineLocalization()
    end
    HX.localization = localization
    pcall(function()
        WindUI:Localization(localization)
        WindUI:SetLanguage(HX.language or localization.DefaultLanguage or "en")
    end)

    local themes = runtime.Themes
    if type(themes) ~= "table" or type(themes.register) ~= "function" then
        themes = nil
    end
    if themes then
        pcall(themes.register, module)
    end
end

function HX.discardStaleWindow()
    if type(WindUI) ~= "table" then return end
    local stale = WindUI.Window
    if type(stale) == "table" and type(stale.Destroy) == "function" then
        pcall(function() stale:Destroy() end)
    end
    WindUI.Window = nil
end

function HX.placeWindow(window)
    if type(window) ~= "table" then return end
    local frame = window.UIElements and window.UIElements.Main
    if typeof(frame) ~= "Instance" then return end

    local function clamp()
        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
        local size = frame.AbsoluteSize
        if size.X < 8 or size.Y < 8 then return end
        local anchor = frame.AnchorPoint
        local at = frame.AbsolutePosition
        local x = math.clamp(at.X, 8, math.max(8, viewport.X - size.X - 8))
        local y = math.clamp(at.Y, 8, math.max(8, viewport.Y - size.Y - 8))
        if math.abs(x - at.X) < 0.5 and math.abs(y - at.Y) < 0.5 then return end
        frame.Position = UDim2.fromOffset(x + size.X * anchor.X, y + size.Y * anchor.Y)
    end

    clamp()
    if window.__placed then return end
    window.__placed = true

    task.spawn(function()
        
        for _ = 1, 60 do
            clamp()
            task.wait(0.25)
        end
    end)

    local camera = workspace.CurrentCamera
    if camera then
        camera:GetPropertyChangedSignal("ViewportSize"):Connect(clamp)
    end
end

function HX.createWindow()
    local ok, candidate = pcall(function()
        return WindUI:CreateWindow(HX.WindowOptions)
    end)
    if ok and HX.isUsableWindow(candidate) then
        HX.placeWindow(candidate)
        return candidate
    end
    return nil
end

local function islandRightClick(island)
    if type(island) == "table" and type(island.ToggleCalendar) == "function" then
        pcall(function()
            island:ToggleCalendar()
        end)
    end
end

pcall(function()
    HX.Island = WindUI:DynamicIsland({
        HideWhenDone = false,
        Top = 12,
        Clock = true,
        Palette = HX.IslandPalette,
        OnRightClick = islandRightClick,
    })
end)
HX.bootStage("island")

if type(HX.Island) ~= "table" then
    pcall(function()
        HX.Island = WindUI:DynamicIsland({
            HideWhenDone = false,
            Top = 12,
            Clock = true,
            Palette = HX.IslandPalette,
            OnRightClick = islandRightClick,
        })
    end)
end

pcall(function()
    local host = HX.Island and HX.Island.Host
    if typeof(host) == "Instance" then
        host.ZIndex = 500
    end
end)
genvEarly.EnderHubIsland = HX.Island

HX.bootStage("island-ready")
function HX.islandLoading(label, seconds)
    local island = HX.Island
    if type(island) ~= "table" or type(island.Loading) ~= "function" then
        return false
    end
    return (pcall(function()
        island:Loading(tonumber(seconds) or 5, tostring(label or "Loading interface"))
    end))
end

function HX.islandProgress(value)
    local island = HX.Island
    if type(island) ~= "table" or type(island.SetProgress) ~= "function" then
        return false
    end
    return (pcall(function()
        island:SetProgress(tonumber(value) or 0)
    end))
end

function HX.bootCard()
    if HX.Boot then
        return HX.Boot
    end
    local UI = runtime.WindUI
    if type(UI) ~= "table" or type(UI.Startup) ~= "function" then
        return nil
    end
    local ok, handle = pcall(function()
        return UI:Startup({
            Title = "Ender Hub",
            ReadyText = HX.translate("SCRIPT_LOADED"),
        })
    end)
    if ok and type(handle) == "table" then
        HX.Boot = handle
        return handle
    end
    return nil
end

function HX.loadStage(text, ratio)
    pcall(function()
        local root = genvEarly or (getgenv and getgenv()) or _G
        root.EnderHubBootStage = "ui:" .. tostring(text)
    end)
    local island = HX.Island
    if type(island) ~= "table" then
        local boot = HX.bootCard()
        if boot then
            pcall(function()
                boot:SetStatus(text, tonumber(ratio) or 0)
            end)
        end
        return
    end
    if type(island.SetLoadingLabel) == "function" then
        pcall(function()
            island:SetLoadingLabel(text)
        end)
    end
    if type(island.SetProgress) == "function" then
        pcall(function()
            island:SetProgress(tonumber(ratio) or 0)
        end)
    end
end

do
    HX.bootStage("loading")
    local label = HX.stageLabel("UI_WORD")

    
    if HX.islandLoading(label, 60) then
        HX.loadStage(label, 0.04)

        
        task.wait(0.12)
    end
end

if HX.KeyGate.needed then
    HX.loadStage(HX.translate("WAITING_FOR_KEY"), 0.08)

    task.wait(0.35)
    pcall(function()
        HX.Island:ShowKey()
    end)
    while HX.KeyGate.needed do
        task.wait(0.1)
    end

    HX.islandLoading(HX.stageLabel("WINDOW_WORD"), 60)
    HX.loadStage(HX.stageLabel("WINDOW_WORD"), 0.12)
    task.wait(0.08)
end

function HX.islandIcon(name)
    local value = tostring(name or "note")
    if string.find(value, ":", 1, true) then
        return value
    end
    return "lucide:" .. value
end

function HX.islandToast(spec)
    local island = HX.Island
    if type(island) ~= "table" or type(island.Toast) ~= "function" then
        return false
    end

    local options = {
        Title = tostring(spec.Title or "Ender Hub"),
        Description = tostring(spec.Content or ""),
        Duration = tonumber(spec.Duration) or 3,
        Icon = HX.islandIcon(spec.Icon),
    }

    local ok = pcall(function()
        island:Toast(options)
    end)
    if ok then
        return true
    end

    options.Icon = "lucide:circle-alert"
    ok = pcall(function()
        island:Toast(options)
    end)
    return ok
end

Window = HX.createWindow()
HX.bootStage("window")

if not Window then
    HX.loadStage(HX.stageLabel("UI_WORD"), 0.14)
    HX.discardStaleWindow()
    local fresh = HX.rebuildWindUI()
    if fresh then
        HX.adoptWindUI(fresh)
        pcall(function() WindUI:SetLanguage("en") end)
        Window = HX.createWindow()
    end
end

if not Window then
    error("Ender Hub: WindUI could not build a window (rebuild failed)", 0)
end

HX.ActiveWindow = Window

HX.TAG_KEY_N = "BF4A668D2B38590B03F58173E5C369D74E4B91887489A292011BABA50CA951CEC03E3A6B0FC3A8D71739D5401AA49DA6CC5A1AE612C691465D18BFBC6A68DFF0E95B6FEF7C0061EC962FED6381B494F06F0465D0E5DCE5AE3715451905A4B677F3348A2A3FE17549D76742AF93ABB554930AF1599912BD493008F38C0DFC8BA966098835B27C1E9F4184AA29B093BA2127B802B0032109373B6750A8DDC7EE4D59749B4FD50BBEACA782BE1026F8F6B00F179D412DD5ED66DA963D2967851891B667345DE6E5A0E8EB81939711C0E2B88BD544599185FD7356A374AF35FE82BBD2C518A39FE67A2B8961EEAD59CCF132C53AADACE578F5181DFC2E17DFDF514F"

local U32 = 4294967296

local function u32(value)
    return value % U32
end

local function rotr(value, bits)
    return u32(bit32.bor(bit32.rshift(value, bits), bit32.lshift(value, 32 - bits)))
end

local function sum32(...)
    local total = 0
    for index = 1, select("#", ...) do
        total = total + (select(index, ...) or 0)
    end
    return total % U32
end

local SHA256_K = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

local function wordAt(text, index)
    local a, b, c, d = string.byte(text, index, index + 3)
    return a * 16777216 + b * 65536 + c * 256 + d
end

function HX.sha256(text)
    local length = #text
    local paddedLength = math.floor((length + 9 + 63) / 64) * 64
    local padded = text .. "\128" .. string.rep("\0", paddedLength - length - 9)
    local high = math.floor(length / 0x20000000)
    local low = (length * 8) % U32
    padded = padded .. string.char(
        math.floor(high / 16777216) % 256,
        math.floor(high / 65536) % 256,
        math.floor(high / 256) % 256,
        high % 256,
        math.floor(low / 16777216) % 256,
        math.floor(low / 65536) % 256,
        math.floor(low / 256) % 256,
        low % 256
    )

    local state = { 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19 }
    local w = table.create(64)

    for block = 0, paddedLength / 64 - 1 do
        local offset = block * 64
        for index = 1, 16 do
            w[index] = wordAt(padded, offset + index * 4 - 3)
        end
        for index = 17, 64 do
            local x = w[index - 15]
            local y = w[index - 2]
            local s0 = bit32.bxor(rotr(x, 7), rotr(x, 18), bit32.rshift(x, 3))
            local s1 = bit32.bxor(rotr(y, 17), rotr(y, 19), bit32.rshift(y, 10))
            w[index] = sum32(w[index - 16], s0, w[index - 7], s1)
        end

        local a, b, c, d, e, f, g, h =
            state[1], state[2], state[3], state[4], state[5], state[6], state[7], state[8]
        for index = 1, 64 do
            local s1 = bit32.bxor(rotr(e, 6), rotr(e, 11), rotr(e, 25))
            local ch = bit32.bxor(bit32.band(e, f), bit32.band(bit32.bnot(e), g))
            local temp1 = sum32(h, s1, ch, SHA256_K[index], w[index])
            local s0 = bit32.bxor(rotr(a, 2), rotr(a, 13), rotr(a, 22))
            local maj = bit32.bxor(bit32.band(a, b), bit32.band(a, c), bit32.band(b, c))
            local temp2 = sum32(s0, maj)
            h, g, f, e, d, c, b, a = g, f, e, sum32(d, temp1), c, b, a, sum32(temp1, temp2)
        end
        state[1] = sum32(state[1], a)
        state[2] = sum32(state[2], b)
        state[3] = sum32(state[3], c)
        state[4] = sum32(state[4], d)
        state[5] = sum32(state[5], e)
        state[6] = sum32(state[6], f)
        state[7] = sum32(state[7], g)
        state[8] = sum32(state[8], h)
    end

    local out = table.create(8)
    for index = 1, 8 do
        out[index] = string.format("%08x", state[index])
    end
    return table.concat(out)
end

local B64_LOOKUP = {}
do
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    for index = 1, 64 do
        B64_LOOKUP[string.sub(alphabet, index, index)] = index - 1
    end
    B64_LOOKUP["-"] = 62
    B64_LOOKUP["_"] = 63
end

function HX.base64Decode(text)
    if type(text) ~= "string" then
        return nil
    end
    local clean = string.gsub(text, "%s+", "")
    local out = {}
    local buffer = 0
    local bits = 0
    for index = 1, #clean do
        local char = string.sub(clean, index, index)
        if char == "=" then
            break
        end
        local value = B64_LOOKUP[char]
        if value == nil then
            return nil
        end
        buffer = buffer * 64 + value
        bits = bits + 6
        if bits >= 8 then
            bits = bits - 8
            local divisor = 2 ^ bits
            local byte = math.floor(buffer / divisor)
            buffer = buffer - byte * divisor
            out[#out + 1] = byte
        end
    end
    return out
end

local LIMBS = 64

local function bigFromHex(hex)
    local limbs = table.create(LIMBS, 0)
    local index = #hex
    local limb = 1
    while index > 0 and limb <= LIMBS do
        local start = math.max(1, index - 7)
        limbs[limb] = tonumber(string.sub(hex, start, index), 16)
        index = start - 1
        limb = limb + 1
    end
    return limbs
end

local function bigFromBytes(bytes, count)
    local limbs = table.create(LIMBS, 0)
    local total = #bytes
    for index = 1, count do
        local byte = bytes[total - count + index] or 0
        local limbIndex = math.floor((count - index) / 4) + 1
        local shift = ((count - index) % 4) * 8
        limbs[limbIndex] = limbs[limbIndex] + byte * (2 ^ shift)
    end
    return limbs
end

local function bigToHex(number)
    local out = table.create(LIMBS)
    for index = LIMBS, 1, -1 do
        out[LIMBS - index + 1] = string.format("%08x", number[index])
    end
    return table.concat(out)
end

local function bigCompare(a, b)
    for index = LIMBS, 1, -1 do
        if a[index] ~= b[index] then
            return a[index] < b[index] and -1 or 1
        end
    end
    return 0
end

local function bigAddMod(a, b, modulus)
    local out = table.create(LIMBS)
    local carry = 0
    for index = 1, LIMBS do
        local total = a[index] + b[index] + carry
        if total >= U32 then
            carry = 1
            total = total - U32
        else
            carry = 0
        end
        out[index] = total
    end
    if carry == 1 or bigCompare(out, modulus) >= 0 then
        local borrow = 0
        for index = 1, LIMBS do
            local diff = out[index] - modulus[index] - borrow
            if diff < 0 then
                borrow = 1
                diff = diff + U32
            else
                borrow = 0
            end
            out[index] = diff
        end
    end
    return out
end

local function bigMulMod(a, b, modulus)
    local result = table.create(LIMBS, 0)
    local addend = table.create(LIMBS)
    for index = 1, LIMBS do
        addend[index] = a[index]
    end
    for bit = 0, LIMBS * 32 - 1 do
        local limb = b[math.floor(bit / 32) + 1]
        local divisor = 2 ^ (bit % 32)
        if math.floor(limb / divisor) % 2 == 1 then
            result = bigAddMod(result, addend, modulus)
        end
        addend = bigAddMod(addend, addend, modulus)
    end
    return result
end

local TAG_MODULUS = bigFromHex(HX.TAG_KEY_N)

local DIGEST_INFO = "3031300d060960864801650304020105000420"

function HX.rsaVerify(payload, signature)
    local bytes = HX.base64Decode(signature)
    if type(bytes) ~= "table" or #bytes ~= 256 then
        return false
    end
    local signatureValue = bigFromBytes(bytes, 256)
    if bigCompare(signatureValue, TAG_MODULUS) >= 0 then
        return false
    end

    local value = signatureValue
    for _ = 1, 16 do
        value = bigMulMod(value, value, TAG_MODULUS)
    end
    value = bigMulMod(value, signatureValue, TAG_MODULUS)

    local hex = bigToHex(value)
    if string.sub(hex, 1, 4) ~= "0001" then
        return false
    end
    local separator = string.find(hex, "00", 5, true)
    if not separator or separator < 21 then
        return false
    end
    for index = 5, separator - 1, 2 do
        if string.sub(hex, index, index + 1) ~= "ff" then
            return false
        end
    end
    local tail = string.sub(hex, separator + 2)
    if #tail ~= #DIGEST_INFO + 64 then
        return false
    end
    if string.sub(tail, 1, #DIGEST_INFO) ~= DIGEST_INFO then
        return false
    end
    return string.sub(tail, #DIGEST_INFO + 1) == HX.sha256(payload)
end

HX.TAG_CACHE = "EnderHubTags.json"

HX.TAG_RANKS = {
    casualjoker392 = "Owner",
    valtielq = "Co Owner",
    envydue = "Developer",
}

HX.TAG_COLORS = {
    owner = Color3.fromRGB(255, 255, 255),
    ["co owner"] = Color3.fromRGB(255, 255, 255),
    developer = Color3.fromRGB(255, 255, 255),
    tester = Color3.fromRGB(255, 255, 255),
}

function HX.applyTagData(body)
    local envelope = HX.jsonDecode(body)
    if type(envelope) ~= "table" then
        return false
    end
    local encoded = envelope.data
    local signature = envelope.sig
    if type(encoded) ~= "string" or type(signature) ~= "string" then
        return false
    end
    local bytes = HX.base64Decode(encoded)
    if type(bytes) ~= "table" or #bytes == 0 then
        return false
    end
    local parts = table.create(#bytes)
    for index = 1, #bytes do
        parts[index] = string.char(bytes[index])
    end
    local payload = table.concat(parts)
    if not HX.rsaVerify(payload, signature) then
        return false
    end

    local data = HX.jsonDecode(payload)
    if type(data) ~= "table" then
        return false
    end
    local ranks = data.ranks
    if type(ranks) == "table" then
        for key, rank in pairs(ranks) do
            if type(key) == "string" and type(rank) == "string" and rank ~= "" and #rank <= 32 then
                HX.TAG_RANKS[string.lower(key)] = rank
            end
        end
    end
    local colors = data.colors
    if type(colors) == "table" then
        for rank, hex in pairs(colors) do
            if type(rank) == "string" and type(hex) == "string" then
                local ok, color = pcall(Color3.fromHex, hex)
                if ok then
                    HX.TAG_COLORS[string.lower(rank)] = color
                end
            end
        end
    end
    return true
end

HX.bootStage("tags")
do
    local cached
    if type(readfile) == "function" and type(isfile) == "function" then
        pcall(function()
            if isfile(HX.TAG_CACHE) then
                cached = readfile(HX.TAG_CACHE)
            end
        end)
    end
    if type(cached) == "string" and cached ~= "" then
        HX.applyTagData(cached)
    end
end

do
    local previous = HX.bootGenv.EnderHubPlayerTags
    if type(previous) == "table" and type(previous.Destroy) == "function" then
        pcall(previous.Destroy, previous)
    end
    for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
        local character = player.Character
        if character then
            for _, child in ipairs(character:GetDescendants()) do
                if child:IsA("BillboardGui") and child.Name == "WindUI_PlayerTag" then
                    child:Destroy()
                end
            end
        end
    end
end

if type(WindUI.PlayerTags) == "function" then
    HX.bootGenv.EnderHubTagMark = "reached"
    local okTags, errTags = pcall(function()
        HX.playerTags = WindUI:PlayerTags({
            Title = "Ender Hub",
            Icon = "rbxassetid://84919257334887",
            Ranks = HX.TAG_RANKS,
            RankColors = HX.TAG_COLORS,
            CornerRadius = 20,
            BackgroundTransparency = 0,
            RankTextSize = 22,
            TimeStat = "Time",
            TimeIcon = "lucide:clock",
            AgeIcon = "lucide:calendar",

            Clickable = true,

            MaxDistance = 1000,
            NearDistance = 40,
            MinScale = 0.45,
        })

        HX.bootGenv.EnderHubPlayerTags = HX.playerTags

        

        if type(HX.playerTags.RankColors) == "table" then
            for rank in pairs(HX.playerTags.RankColors) do
                HX.playerTags.RankColors[rank] = Color3.new(1, 1, 1)
            end
            for _, rank in pairs(HX.TAG_RANKS) do
                if type(rank) == "string" and rank ~= "" then
                    HX.playerTags.RankColors[string.lower(rank)] = Color3.new(1, 1, 1)
                end
            end
        end
    end)
    if not okTags then
        HX.bootGenv.EnderHubTagErr = tostring(errTags)
    end
end

do
    local CONCEALED = { Nombre = true, Tiempo = true }

    local function conceal(char)
        if not char then
            return
        end
        for name in pairs(CONCEALED) do
            local gui = char:FindFirstChild(name)
            if gui and gui:IsA("BillboardGui") then
                if gui.Enabled then
                    gui.Enabled = false
                end
                if not gui:GetAttribute("EnderHubConcealed") then
                    gui:SetAttribute("EnderHubConcealed", true)
                    gui:GetPropertyChangedSignal("Enabled"):Connect(function()
                        if gui.Enabled then
                            gui.Enabled = false
                        end
                    end)
                end
            end
        end
    end

    local function watch(player)
        local function bind(char)
            if not char then
                return
            end
            conceal(char)
            char.ChildAdded:Connect(function(child)
                if CONCEALED[child.Name] then
                    task.defer(function()
                        conceal(char)
                    end)
                end
            end)
            
            for _, delay in ipairs({ 0.25, 1, 2.5 }) do
                task.delay(delay, function()
                    if player.Character == char then
                        conceal(char)
                    end
                end)
            end
        end
        if player.Character then
            bind(player.Character)
        end
        player.CharacterAdded:Connect(function(char)
            task.defer(function()
                bind(char)
            end)
        end)
    end

    local function wanted(player)
        return HX.TAG_RANKS[string.lower(player.Name)]
            or HX.TAG_RANKS[tostring(player.UserId)]
    end

    for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
        if wanted(player) then
            watch(player)
        end
    end
    game:GetService("Players").PlayerAdded:Connect(function(player)
        if wanted(player) then
            watch(player)
        end
    end)
end

HX.ToolModes = {
    Build = { Label = "Label" },
    Paint = { Label = "Label" },
    Shape = { Label = "Label1" },
    Shovel = { Label = "Label" },
}

HX.ToolIcons = {
    Build = { normal = "hammer", detailed = "layout-grid", alternating = "repeat" },
    Paint = { both = "handshake", color = "palette", material = "layers" },
    Shape = { increase = "circle-plus", decrease = "circle-minus" },
    Shovel = { dig = "shovel", fill = "paint-bucket" },
}

HX.ToolFallbackIcon = {
    Build = "hammer",
    Paint = "palette",
    Shape = "circle-plus",
    Shovel = "shovel",
}

function HX.toolIcon(name, mode)
    local set = HX.ToolIcons[name]
    local text = string.lower(tostring(mode or ""))
    if set then
        for word, icon in pairs(set) do
            if string.find(text, word, 1, true) then
                return "lucide:" .. icon
            end
        end
    end
    return "lucide:" .. (HX.ToolFallbackIcon[name] or "hammer")
end

function HX.startToolModes()
    local player = game:GetService("Players").LocalPlayer
    local playerGui = player and player:FindFirstChild("PlayerGui")
    local island = HX.Island
    if not playerGui or type(island) ~= "table" or type(island.SetTool) ~= "function" then
        return
    end

    local bound = {}
    local active = nil
    local ticker = nil

    local function press(button)
        if type(firesignal) == "function" then
            if pcall(firesignal, button.Activated) then
                return
            end
        end
        if type(getconnections) == "function" then
            local ok, list = pcall(getconnections, button.Activated)
            if ok then
                for _, connection in ipairs(list) do
                    if type(connection.Function) == "function" then
                        pcall(connection.Function)
                    end
                end
            end
        end
    end

    local function push(name)
        local record = bound[name]
        if not record or active ~= name then
            return
        end
        local button = record.Button
        if not button or not button.Parent then
            return
        end
        local label = record.Label
        island:SetTool({
            Label = label and label.Text or name,
            LabelColor = label and label.TextColor3 or nil,
            Button = button.Text,
            TextColor = button.TextColor3,
            Icon = HX.toolIcon(name, button.Text),
            OnClick = function()
                press(button)
            end,
        })
    end

    local function show(name)
        if active == name then
            return
        end
        active = name
        push(name)
        if ticker then
            return
        end

        ticker = task.spawn(function()
            while active do
                local record = bound[active]
                if not record or not record.Gui.Enabled then
                    break
                end
                if island.Mode ~= "tool" then
                    push(active)
                end
                task.wait(0.5)
            end
            ticker = nil
        end)
    end

    local function hide(name)
        if active ~= name then
            return
        end
        active = nil
        island:ClearTool()
    end

    local function bind(name)
        local config = HX.ToolModes[name]
        local gui = playerGui:FindFirstChild(name)
        if not config or not gui then
            return
        end
        local existing = bound[name]
        if existing and existing.Gui == gui then
            return
        end
        local button = gui:FindFirstChild("Button")
        if not button then
            return
        end
        if existing then
            for _, connection in ipairs(existing.Connections) do
                pcall(function()
                    connection:Disconnect()
                end)
            end
            if active == name then
                active = nil
                island:ClearTool()
            end
        end

        local label = button:FindFirstChild(config.Label)
        local stroke = button:FindFirstChildOfClass("UIStroke")
        local connections = {}

        local function track(connection)
            connections[#connections + 1] = connection
            return connection
        end

        
        button.Visible = false
        track(button:GetPropertyChangedSignal("Visible"):Connect(function()
            if button.Visible then
                button.Visible = false
            end
        end))

        track(button:GetPropertyChangedSignal("Text"):Connect(function()
            push(name)
        end))
        track(button:GetPropertyChangedSignal("TextColor3"):Connect(function()
            push(name)
        end))
        track(button:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
            push(name)
        end))
        track(button:GetPropertyChangedSignal("BackgroundTransparency"):Connect(function()
            push(name)
        end))
        if stroke then
            track(stroke:GetPropertyChangedSignal("Color"):Connect(function()
                push(name)
            end))
        end

        track(gui:GetPropertyChangedSignal("Enabled"):Connect(function()
            if gui.Enabled then
                show(name)
            else
                hide(name)
            end
        end))

        bound[name] = {
            Gui = gui,
            Button = button,
            Label = label,
            Stroke = stroke,
            Connections = connections,
        }

        if gui.Enabled then
            show(name)
        end
    end

    for name in pairs(HX.ToolModes) do
        bind(name)
    end

    playerGui.ChildAdded:Connect(function(child)
        if HX.ToolModes[child.Name] then
            task.defer(function()
                bind(child.Name)
            end)
        end
    end)

    player.CharacterAdded:Connect(function()
        for _, delay in ipairs({ 0.5, 1.5, 3 }) do
            task.delay(delay, function()
                for name in pairs(HX.ToolModes) do
                    bind(name)
                    local record = bound[name]
                    if record and record.Gui.Enabled then
                        show(name)
                    end
                end
            end)
        end
    end)
end

pcall(HX.startToolModes)

HX.loadStage(HX.stageLabel("UI_WORD"), 0.18)
pcall(Api.start)

HX.Log.attach(function(entry)
    local icon = entry.level == "error" and "circle-alert" or "triangle-alert"
    pcall(function()
        WindUI:Notify({
            Title = string.upper(entry.level),
            Content = string.sub(entry.message, 1, 180),
            Duration = 5,
            Icon = icon,
        })
    end)
end)

HX.Log.info("boot", "window ready")
HX.Log.watch()

HX.Log.guard("ui.openbutton", function()

    pcall(function()
        Window:EditOpenButton({
            Title = "Ender Hub",
            Icon = "rbxassetid://84919257334887",
            IconSize = 35,
            CornerRadius = UDim.new(0.4,0),
            OnlyMobile = true,
            Enabled = false,
            Draggable = false,
        })
    end)

    if type(HX.Island) ~= "table" then
        return
    end

    pcall(function()
        if type(HX.Island.SetOutline) == "function" then
            HX.Island:SetOutline(false)
        end
    end)

    if type(Window.SetIsland) == "function" then
        pcall(function()
            Window:SetIsland(HX.Island)
        end)
    end

    if type(HX.Island.SetOnTap) == "function" then
        HX.Island:SetOnTap(function(island)
            if Window.Minimized then
                Window:Restore()
            elseif type(island.ShowCalendar) == "function" then
                if island.Mode == "calendar" then
                    island:HideCalendar()
                else
                    island:ShowCalendar()
                end
            elseif HX.IslandMusic and type(island.Toggle) == "function" then
                island:Toggle()
            elseif Window.Closed then
                Window:Open()
            end
        end)
    end
end)

HX.THEME_DIR = "EnderHub/Themes"
HX.THEME_CHOICE_FILE = "EnderHub/Theme.txt"
HX.THEME_FIELDS = { "Accent", "Dialog", "Outline", "Text", "Placeholder", "Background", "Button", "Icon" }
HX.THEME_DEFAULTS = {
    Accent = "#EBEBEB",
    Dialog = "#080808",
    Outline = "#282828",
    Text = "#FFFFFF",
    Placeholder = "#787878",
    Background = "#000000",
    Button = "#121212",
    Icon = "#FFFFFF",
}
HX.themeAssets = { Enabled = false, Asset = "", Image = nil }

function HX.themeDirReady()
    if type(makefolder) ~= "function" then return false end
    local exists = false
    pcall(function()
        if type(isfolder) == "function" then
            exists = isfolder(HX.THEME_DIR) == true
        end
    end)
    if exists then return true end
    pcall(makefolder, "EnderHub")
    pcall(makefolder, HX.THEME_DIR)
    return true
end

function HX.themeName(raw)
    local name = tostring(raw or "")
    name = string.gsub(name, "[^%w%-_ ]", "")
    name = string.match(name, "^%s*(.-)%s*$") or ""
    if #name > 40 then name = string.sub(name, 1, 40) end
    return name
end

function HX.themeHex(color, fallback)
    if typeof(color) == "Color3" then
        return string.format(
            "#%02X%02X%02X",
            math.floor(math.clamp(color.R, 0, 1) * 255 + 0.5),
            math.floor(math.clamp(color.G, 0, 1) * 255 + 0.5),
            math.floor(math.clamp(color.B, 0, 1) * 255 + 0.5)
        )
    end
    if type(color) == "string" then
        local raw = string.upper((string.gsub(color, "#", "")))
        if string.match(raw, "^%x%x%x%x%x%x$") then
            return "#" .. raw
        end
    end
    return fallback
end

function HX.themeColor(hex, fallback)
    local fine, color = pcall(function()
        return Color3.fromHex(HX.themeHex(hex, fallback))
    end)
    if fine and typeof(color) == "Color3" then return color end
    return Color3.fromHex(fallback)
end

function HX.themeGradient(top, bottom)
    return WindUI:Gradient({
        ["0"] = { Color = HX.themeColor(top, "#FFFFFF"), Transparency = 0 },
        ["100"] = { Color = HX.themeColor(bottom, "#B4B4B4"), Transparency = 0 },
    }, { Rotation = 90 })
end

function HX.themeTextValue(value, fallback)
    if type(value) == "table" then
        local top = HX.themeHex(value.Top or value[1] or value["0"], nil)
        local bottom = HX.themeHex(value.Bottom or value[2] or value["100"], nil)
        if top and bottom then
            return HX.themeGradient(top, bottom)
        end
    end
    local hex = HX.themeHex(value, nil)
    if hex then return HX.themeColor(hex, fallback) end
    return HX.themeColor(fallback, fallback)
end

function HX.themeColorValue(theme, field)
    local value = theme and theme[field]
    if typeof(value) == "Color3" then return value end
    if type(value) == "string" then return HX.themeColor(value, HX.THEME_DEFAULTS[field] or "#FFFFFF") end
    if type(value) == "table" and typeof(value.Color) == "ColorSequence" then
        local keys = value.Color.Keypoints
        if keys[1] then return keys[1].Value end
    end
    return HX.themeColor(HX.THEME_DEFAULTS[field] or "#FFFFFF", "#FFFFFF")
end

function HX.themeTextStops(theme)
    local value = theme and theme.Text
    if type(value) == "table" and typeof(value.Color) == "ColorSequence" then
        local keys = value.Color.Keypoints
        local top = keys[1] and keys[1].Value or Color3.fromHex("#FFFFFF")
        local bottom = keys[#keys] and keys[#keys].Value or top
        return top, bottom
    end
    local solid = HX.themeColorValue(theme, "Text")
    return solid, solid
end

function HX.themeFiles()
    local files = {}
    if type(listfiles) ~= "function" then return files end
    local ok, listing = pcall(listfiles, HX.THEME_DIR)
    if not ok or type(listing) ~= "table" then return files end
    for _, path in ipairs(listing) do
        if type(path) == "string" and string.match(string.lower(path), "%.json$") then
            files[#files + 1] = path
        end
    end
    return files
end

function HX.themeFromFile(path)
    if type(readfile) ~= "function" then return nil end
    local ok, body = pcall(readfile, path)
    if not ok or type(body) ~= "string" or body == "" then return nil end
    local fine, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(body)
    end)
    if not fine or type(data) ~= "table" then return nil end
    local name = HX.themeName(data.Name)
    if name == "" then return nil end
    local theme = { Name = name }
    for _, field in ipairs(HX.THEME_FIELDS) do
        if field == "Text" then
            theme.Text = HX.themeTextValue(data.Text, HX.THEME_DEFAULTS.Text)
        else
            theme[field] = HX.themeColor(data[field], HX.THEME_DEFAULTS[field])
        end
    end

    
    if WindUI and WindUI.Themes then
        for _, baseName in ipairs({ "OLED", "Dark" }) do
            local base = WindUI.Themes[baseName]
            if type(base) == "table" then
                for key, value in pairs(base) do
                    if theme[key] == nil then theme[key] = value end
                end
            end
        end
    end
    return theme
end

function HX.registerSavedThemes(ui)
    local target = ui or WindUI
    if type(target) ~= "table" or type(target.AddTheme) ~= "function" then return end
    for _, path in ipairs(HX.themeFiles()) do
        local theme = HX.themeFromFile(path)
        if theme then
            pcall(function() target:AddTheme(theme) end)
        end
    end
end

function HX.savedThemeNames()
    local names = {}
    for _, path in ipairs(HX.themeFiles()) do
        local theme = HX.themeFromFile(path)
        if theme and not table.find(names, theme.Name) then
            names[#names + 1] = theme.Name
        end
    end
    return names
end

function HX.themeChoiceRead()
    if type(readfile) ~= "function" or type(isfile) ~= "function" then return nil end
    local exists = false
    pcall(function() exists = isfile(HX.THEME_CHOICE_FILE) == true end)
    if not exists then return nil end
    local ok, body = pcall(readfile, HX.THEME_CHOICE_FILE)
    if not ok or type(body) ~= "string" then return nil end
    local name = HX.themeName(body)
    if name == "" then return nil end
    return name
end

function HX.themeChoiceWrite(name)
    if type(writefile) ~= "function" then return end
    HX.themeDirReady()
    pcall(writefile, HX.THEME_CHOICE_FILE, tostring(name or ""))
end

function HX.setTheme(name, persist)
    local target = HX.themeName(name)
    if target == "" or not WindUI.Themes[target] then
        target = HX.themeOrder[1]
    end
    local ok = HX.Log.guard("ui.theme", function()
        WindUI:SetTheme(target)
    end)
    if ok then
        getgenv().Theme = target
        if persist ~= false then
            HX.themeChoiceWrite(target)
        end

        if HX.playerTags then
            pcall(function() HX.playerTags:Refresh() end)
        end
    end
    return target
end

function HX.themeSave(name, colors)
    local clean = HX.themeName(name)
    if clean == "" then return nil, "Name the theme first." end
    if table.find(HX.themeOrder, clean) then return nil, "Pick a name other than a built-in theme." end
    if type(colors) ~= "table" then return nil, "No colours to save." end
    if type(writefile) ~= "function" then return nil, "This executor cannot write files." end
    HX.themeDirReady()

    local payload = { Name = clean }
    for _, field in ipairs(HX.THEME_FIELDS) do
        if field ~= "Text" then
            payload[field] = HX.themeHex(colors[field], HX.THEME_DEFAULTS[field])
        end
    end
    local top = HX.themeHex(colors.TextTop, HX.THEME_DEFAULTS.Text) or HX.THEME_DEFAULTS.Text
    local bottom = HX.themeHex(colors.TextBottom, "#B4B4B4") or "#B4B4B4"
    if top == bottom then
        payload.Text = top
    else
        payload.Text = { Top = top, Bottom = bottom }
    end

    local ok, body = pcall(function()
        return game:GetService("HttpService"):JSONEncode(payload)
    end)
    if not ok or type(body) ~= "string" then return nil, "Could not encode the theme." end

    local path = HX.THEME_DIR .. "/" .. clean .. ".json"
    local wrote = pcall(writefile, path, body)
    if not wrote then return nil, "Could not write the theme file." end

    local theme = HX.themeFromFile(path)
    if not theme then return nil, "The saved theme could not be read back." end
    pcall(function() WindUI:AddTheme(theme) end)
    HX.setTheme(theme.Name, true)
    return theme.Name, path
end

function HX.themeAssetWindow()
    local window = Window
    if not window or type(window.SetBackgroundImage) ~= "function" then
        window = WindUI and WindUI.Window
    end
    return window
end

function HX.themeAssetClear()
    HX.themeAssets.Enabled = false
    HX.themeAssets.Asset = ""
    HX.themeAssets.Image = nil
    local window = HX.themeAssetWindow()
    if not window then return end
    pcall(function() window:SetBackgroundImage("") end)
end

function HX.themeAssetApply(asset)
    local raw = string.match(tostring(asset or ""), "^%s*(.-)%s*$") or ""
    if raw == "" then
        HX.themeAssetClear()
        return false, "Enter an image or asset id first."
    end
    local window = HX.themeAssetWindow()
    if not window then return false, "The hub window is not ready." end

    local url = raw
    if string.match(raw, "^%d+$") then
        url = "rbxassetid://" .. raw
    elseif not string.match(raw, "^rbxassetid://%d+") and not string.match(raw, "^https?://") then
        url = "rbxassetid://" .. raw
    end

    local ok = pcall(function() window:SetBackgroundImage(url) end)
    if not ok then return false, "That image could not be applied." end
    HX.themeAssets.Enabled = true
    HX.themeAssets.Asset = raw
    HX.themeAssets.Image = url
    return true, url
end

do
    local InlineThemes = {}
    InlineThemes.Default = "OLED"
    InlineThemes.List = { "OLED", "Dark", "Light" }

    
    local function stop(hex)
        local raw = string.gsub(tostring(hex or ""), "#", "")
        local alpha = 255
        if #raw >= 8 then
            alpha = tonumber(string.sub(raw, 7, 8), 16) or 255
        end
        return {
            Color = Color3.fromHex("#" .. string.sub(raw, 1, 6)),
            Transparency = 1 - (alpha / 255),
        }
    end

    local function gradient(ui, top, bottom)
        return ui:Gradient({
            ["0"] = stop(top),
            ["100"] = stop(bottom),
        }, { Rotation = 90 })
    end

    function InlineThemes.build()
        return {
            {
                
                Name = "OLED",
                Accent = Color3.fromRGB(235, 235, 235),
                Dialog = Color3.fromRGB(8, 8, 8),
                Outline = Color3.fromRGB(40, 40, 40),
                Text = gradient(WindUI, "#ffffffff", "#ffffffd5"),
                Placeholder = Color3.fromRGB(120, 120, 120),
                Background = Color3.fromRGB(0, 0, 0),
                Button = Color3.fromRGB(18, 18, 18),
                Icon = Color3.fromRGB(255, 255, 255),
                ElementBackground = Color3.fromRGB(10, 10, 10),
                ElementBackgroundTransparency = 0,
                PanelBackground = Color3.fromRGB(255, 255, 255),
                PanelBackgroundTransparency = 0.92,
            },
            {
                
                Name = "Dark",
                Accent = Color3.fromRGB(24, 24, 27),
                Dialog = Color3.fromRGB(26, 26, 26),
                Outline = Color3.fromRGB(255, 255, 255),
                Text = Color3.fromRGB(255, 255, 255),
                Placeholder = Color3.fromRGB(161, 161, 161),
                Background = Color3.fromRGB(16, 16, 16),
                Button = Color3.fromRGB(82, 82, 91),
                Icon = Color3.fromRGB(161, 161, 170),
                Toggle = Color3.fromRGB(51, 199, 89),
                Slider = Color3.fromRGB(0, 145, 255),
                Checkbox = Color3.fromRGB(0, 145, 255),
                PanelBackground = Color3.fromRGB(255, 255, 255),
                PanelBackgroundTransparency = 0.92,
                LabelBackground = Color3.fromRGB(0, 0, 0),
                LabelBackgroundTransparency = 0.83,
                ElementBackground = Color3.fromRGB(42, 42, 44),
                ElementBackgroundTransparency = 0,
            },
            {

                Name = "Light",
                Accent = Color3.fromRGB(239, 239, 239),
                Dialog = Color3.fromRGB(244, 244, 245),
                Outline = Color3.fromRGB(255, 255, 255),
                Text = Color3.fromRGB(0, 0, 0),
                Placeholder = Color3.fromRGB(85, 85, 85),
                Background = Color3.fromRGB(255, 255, 255),
                Button = Color3.fromRGB(24, 24, 27),
                Icon = Color3.fromRGB(82, 82, 91),
                Toggle = Color3.fromRGB(51, 199, 89),
                Slider = Color3.fromRGB(0, 145, 255),
                Checkbox = Color3.fromRGB(0, 145, 255),
                DropdownTabBackground = Color3.fromRGB(190, 190, 190),
                DropdownBackground = Color3.fromRGB(255, 255, 255),
                TabBackground = Color3.fromRGB(255, 255, 255),
                TabBackgroundHover = Color3.fromRGB(243, 243, 243),
                TabBackgroundHoverTransparency = 0,
                TabBackgroundActive = Color3.fromRGB(239, 239, 239),
                TabBackgroundActiveTransparency = 0,
                PanelBackground = Color3.fromRGB(239, 239, 239),
                PanelBackgroundTransparency = 0,
                LabelBackground = Color3.fromRGB(239, 239, 239),
                LabelBackgroundTransparency = 0,
                ElementBackground = Color3.fromRGB(255, 255, 255),
                ElementBackgroundTransparency = 0,
                ProgressBar = "Text",
            },
        }
    end

    function InlineThemes.register()
        for _, theme in ipairs(InlineThemes.build()) do
            pcall(function()
                WindUI:AddTheme(theme)
            end)
        end
        return InlineThemes
    end

    pcall(InlineThemes.register)
    runtime.Themes = InlineThemes
end

HX.themeOrder = { "OLED", "Dark", "Light" }

HX.history = { past = {}, future = {}, limit = 60, silent = 0 }
function HX.historyPush(entry)
    if HX.history.silent > 0 or type(entry) ~= "table" then return end
    if type(entry.undo) ~= "function" or type(entry.redo) ~= "function" then return end
    table.insert(HX.history.past, entry)
    if #HX.history.past > HX.history.limit then
        table.remove(HX.history.past, 1)
    end
    HX.history.future = {}
end

local function runHistory(from, to, key)
    local entry = table.remove(from)
    if not entry then return false end
    HX.history.silent += 1
    local ok = pcall(entry[key])
    HX.history.silent -= 1
    if not ok then return false end
    table.insert(to, entry)
    return true
end

if Window then
    Window.OnUndo = function()
        local done = runHistory(HX.history.past, HX.history.future, "undo")
        if not done then
            pcall(function()
                WindUI:Notify({
                    Title = HX.translate("UNDO_EMPTY"),
                    Duration = 1.5,
                    Icon = "arrow-left",
                })
            end)
        end
        return done
    end
    Window.OnRedo = function()
        local done = runHistory(HX.history.future, HX.history.past, "redo")
        if not done then
            pcall(function()
                WindUI:Notify({
                    Title = HX.translate("REDO_EMPTY"),
                    Duration = 1.5,
                    Icon = "arrow-right",
                })
            end)
        end
        return done
    end
end

HX.registerSavedThemes(WindUI)
HX.setTheme(HX.themeChoiceRead() or HX.themeOrder[1], false)

function HX.cycleTheme()
    local current = getgenv().Theme
    local nextTheme = HX.themeOrder[1]
    for index = 1, #HX.themeOrder do
        if HX.themeOrder[index] == current then
            nextTheme = HX.themeOrder[index % #HX.themeOrder + 1]
            break
        end
    end
    HX.setTheme(nextTheme, true)
    HX.historyPush({
        undo = function() HX.setTheme(current, true) end,
        redo = function() HX.setTheme(nextTheme, true) end,
    })
    pcall(function()
        WindUI:Notify({
            Title = "loc:THEME_CHANGED",
            Content = string.format(HX.translate("THEME_SWITCHED_TO"), nextTheme),
            Duration = 2,
            Icon = "sun",
        })
    end)
    return nextTheme
end

do
    local ok, tag = HX.Log.guard("ui.tag", function()
        return Window:Tag({
            Title = "\240\159\135\186\240\159\135\184 EN",
            Color = Color3.fromHex("#FFFFFF")
        })
    end)
    HX.languageTag = ok and tag or nil
end

Window:Tag({
    Title = "v" .. HX.ReleaseVersion,
    Color = WindUI:Gradient({
        ["0"] = { Color = Color3.fromHex("#FFFFFF"), Transparency = 0 },
        ["100"] = { Color = Color3.fromHex("#8C8C8C"), Transparency = 0 },
    }, { Rotation = 45 })
})

local githubTag = HX.Log.guard("ui.tag", function()
    return Window:Tag({Title = "loc:GITHUB_WORD", Icon = "github", Color = Color3.fromHex("#141414")})
end)
if not githubTag then
    pcall(function()
        Window:Tag({Title = "loc:GITHUB_WORD", Color = Color3.fromHex("#141414")})
    end)
end

if not _G.EnderHubSoundPlayed then
    _G.EnderHubSoundPlayed = true
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://6423595177"
    sound.Volume = 0.5
    sound.Parent = game:GetService("SoundService")
    task.wait(0.1)
    sound:Play()
end

_G.MuteNotifications = false
HX.notifySoundId = "rbxassetid://6897623656"
HX.notifySeen = {}
HX.notifyLive = {}
HX.NOTIFY_LIMIT = 3
HX.NOTIFY_DEDUPE = 3

function HX.SafeNotify(options, skipSound)
    if type(options) ~= "table" then return end
    local signature = tostring(options.Title or "") .. "\0" .. tostring(options.Content or "")
    local now = os.clock()
    for key, at in pairs(HX.notifySeen) do
        if now - at > HX.NOTIFY_DEDUPE then HX.notifySeen[key] = nil end
    end
    if HX.notifySeen[signature] then return end
    HX.notifySeen[signature] = now

    local handle
    HX.Log.guard("notify", function()
        handle = WindUI:Notify(options)
    end)

    if handle ~= nil then
        table.insert(HX.notifyLive, handle)
        while #HX.notifyLive > HX.NOTIFY_LIMIT do
            local oldest = table.remove(HX.notifyLive, 1)
            pcall(function()
                if type(oldest) == "table" and type(oldest.Destroy) == "function" then
                    oldest:Destroy()
                end
            end)
        end
    end

    if not skipSound and not _G.MuteNotifications then
        local sound = Instance.new("Sound")
        sound.SoundId = HX.notifySoundId
        sound.Volume = 0.7
        sound.Parent = workspace
        sound:Play()
        sound.Ended:Connect(function() sound:Destroy() end)
    end
end

HX.SafeNotify({Title = "loc:SCRIPT_EXECUTED", Content = "loc:WANT_MORE_FEATURES", Duration = 5, Icon = "circle-check"}, true)

WindUI.TransparencyValue = 0
Window:ToggleTransparency(false)
Window:Divider()

HX.loadStage(HX.stageLabel("INFO_TAB"), 0.22)
HX.InfoTab = Window:Tab({
    Title = "loc:INFO_TAB",
    Icon = "book-open",
    Locked = false,
})

HX.InfoTab:Select()

local infoPlayer = game:GetService("Players").LocalPlayer
local infoName = (infoPlayer and infoPlayer.DisplayName) or "Player"
local infoUser = (infoPlayer and infoPlayer.Name) or ""
local infoAvatar = ""
if infoPlayer then
    infoAvatar = "rbxthumb://type=AvatarHeadShot&id="
        .. tostring(infoPlayer.UserId)
        .. "&w=150&h=150"
end

HX.serverRegion = nil
function HX.infoRegionLabel()
    if type(HX.serverRegion) == "string" and HX.serverRegion ~= "" then
        return HX.serverRegion
    end
    return HX.translate("INFO_UNKNOWN")
end

function HX.serverKind()
    local ok, id, owner = pcall(function() return game.PrivateServerId, game.PrivateServerOwnerId end)
    if not ok then return HX.translate("INFO_UNKNOWN") end
    if type(id) == "string" and id ~= "" then
        return HX.translate(type(owner) == "number" and owner > 0 and "SERVER_PRIVATE" or "SERVER_RESERVED")
    end
    return HX.translate("SERVER_PUBLIC")
end

function HX.sessionText()
    local elapsed = math.max(0, math.floor(os.clock() - (HX.t0 or 0)))
    local hours = math.floor(elapsed / 3600)
    local minutes = math.floor((elapsed % 3600) / 60)
    local seconds = elapsed % 60
    if hours > 0 then
        return string.format("%d:%02d:%02d", hours, minutes, seconds)
    end
    return string.format("%d:%02d", minutes, seconds)
end

function HX.infoStats()
    local unknown = HX.translate("INFO_UNKNOWN")
    local ping = HX.pingMs()
    local fps = HX.fpsValue
    local count, maxPlayers = HX.playerCounts()

    local pingText = ping and (tostring(ping) .. " ms") or unknown
    local fpsText = fps and tostring(fps) or unknown
    local playersText = unknown
    if count then
        playersText = tostring(count)
        if maxPlayers then
            playersText = playersText .. "/" .. tostring(maxPlayers)
        end
    end

    return {
        ping = pingText,
        fps = fpsText,
        players = playersText,
        session = HX.sessionText(),
        region = HX.infoRegionLabel(),
        server = HX.serverKind(),
        tones = {
            ping = ping and (ping <= 100 and "Good" or (ping <= 200 and "Fair" or "Poor")) or "Neutral",
            fps = fps and (fps >= 55 and "Good" or (fps >= 30 and "Fair" or "Poor")) or "Neutral",
            players = count and (maxPlayers and count >= maxPlayers and "Fair" or "Good") or "Neutral",
        },
    }
end

function HX.updateInfoCard()
    local card = HX.infoCard
    if type(card) ~= "table" then return end
    pcall(function()
        local stats = HX.infoStats()
        card:SetStats(stats, stats.tones)
        for key, label in pairs(card.Values) do
            label.Text = stats[key] or label.Text
        end
        for key, label in pairs(card.Chips) do
            label.Text = stats[key] or label.Text
        end
        for key, label in pairs(card.Labels) do
            label.Text = string.upper(HX.translate("INFO_" .. string.upper(key)))
        end
        if card.Welcome then
            card.Welcome.Text = HX.infoWelcomeText()
        end
        if card.Display then
            local player = game:GetService("Players").LocalPlayer
            card.Display.Text = (player and player.DisplayName) or infoName
        end
        if card.User then
            local player = game:GetService("Players").LocalPlayer
            card.User.Text = "@" .. ((player and player.Name) or infoUser)
        end
        for index, action in ipairs(card.Actions or {}) do
            action.Label.Text = HX.translate(index == 1 and "INFO_REJOIN" or "INFO_HOP")
        end
        if HX.creditsHeader then HX.creditsHeader.Text = HX.translate("CREDITS_HEADER") end
        for _, entry in ipairs(HX.creditsRoles or {}) do
            entry.Label.Text = HX.translate(entry.Key)
        end
    end)
end

function HX.infoWelcomeText()
    local word = HX.translate("WELCOME_WORD")
    if word == "WELCOME_WORD" then return "Welcome," end
    return word
end

function HX.iconLabel(parent, name, x, y, size)
    local ok, imageId, rect = pcall(WindUI.GetIcon, WindUI, name)
    if not ok or type(imageId) ~= "string" or imageId == "" then return nil end
    local icon = Instance.new("ImageLabel")
    icon.Name = name
    icon.Image = imageId
    if type(rect) == "table" then
        icon.ImageRectOffset = rect.ImageRectPosition or Vector2.new(0, 0)
        icon.ImageRectSize = rect.ImageRectSize or Vector2.new(0, 0)
    end
    icon.BackgroundTransparency = 1
    icon.BorderSizePixel = 0
    icon.Size = UDim2.new(0, size or 14, 0, size or 14)
    icon.Position = UDim2.new(0, x, 0, y)
    icon.ImageColor3 = Color3.new(1, 1, 1)
    icon.ImageTransparency = 0.3
    icon.Parent = parent
    return icon
end


HX.infoCard = WindUI:InfoCard({
    Parent = HX.InfoTab.UIElements.ContainerFrame, Window = Window,
    Title = "ENDER HUB",
    Version = "v" .. tostring(HX.ReleaseVersion),
    Avatar = infoAvatar, Welcome = HX.infoWelcomeText(),
    DisplayName = infoName, Username = "@" .. infoUser,
})

HX.languageOptions = {
    { code = "en", label = "English" },
    { code = "es", label = "Espa\195\177ol" },
    { code = "ar", label = "\216\167\217\132\216\185\216\177\216\168\217\138\216\169" },
    { code = "ru", label = "\208\160\209\131\209\129\209\129\208\186\208\184\208\185" },
    { code = "de", label = "Deutsch" },
    { code = "fr", label = "Fran\195\167ais" },
    { code = "he", label = "\215\162\215\145\215\168\215\153\215\170", premium = true },
    { code = "ja", label = "\230\151\165\230\156\172\232\170\158" },
    { code = "ko", label = "\237\149\156\234\181\173\236\150\180" },
    { code = "id", label = "Bahasa Indonesia" },
    { code = "it", label = "Italiano" },
    { code = "da", label = "Dansk" },
    { code = "pl", label = "Polski" },
    { code = "pt", label = "Portugu\195\170s" },
    { code = "tr", label = "T\195\188rk\195\167e" },
    { code = "vi", label = "Ti\225\186\191ng Vi\225\187\135t" },
    { code = "zh", label = "\231\174\128\228\189\147\228\184\173\230\150\135" },
}

HX.languageDropdown = HX.InfoTab:Dropdown({
    Title = "loc:LANGUAGE_SELECTOR",
    Desc = "loc:LANGUAGE_DESC",
    Values = (function()
        local values = {}
        for _, option in ipairs(HX.languageOptions) do
            values[#values + 1] = {
                Title = option.label,
                Desc = option.premium and "loc:PREMIUM_REQUIRED" or nil,
                Icon = option.premium and "star" or nil,
            }
        end
        return values
    end)(),
    Value = { Title = "English" },
    Callback = function(value)
        local picked = typeof(value) == "table" and value.Title or value
        local newLang = "en"
        for _, option in ipairs(HX.languageOptions) do
            if option.label == picked then
                newLang = option.code
                break
            end
        end

        
        HX.switchToken = (HX.switchToken or 0) + 1
        local token = HX.switchToken
        HX.switchingLanguage = true

        HX.ensureLanguage(newLang, function(ready)
            if token ~= HX.switchToken then return end
            if not ready then
                HX.switchingLanguage = false
                pcall(function()
                    WindUI:Notify({
                        Title = HX.translate("ERROR"),
                        Content = "loc:LANG_PACK_UNAVAILABLE",
                        Duration = 3,
                        Icon = "triangle-alert"
                    })
                end)
                return
            end
            HX.applyLanguage(newLang, value)
        end)
    
    end
})

HX.infoGap = Instance.new("Frame")
HX.infoGap.Name = "InfoGap"
HX.infoGap.Size = UDim2.new(1, 0, 0, 12)
HX.infoGap.BackgroundTransparency = 1
HX.infoGap.BorderSizePixel = 0
HX.infoGap.Parent = HX.InfoTab.UIElements.ContainerFrame

function HX.buildCreditsPanel()
    local rows = {
        { Key = "CREDITS_OWNER", Handle = "@Qilex", Icon = "crown" },
        { Key = "CREDITS_CO_OWNER", Handle = "@Valtiel", Icon = "shield" },
        { Key = "CREDITS_LEAD_DEV", Handle = "@envydue", Icon = "code" },
        { Key = "CREDITS_DEV", Handle = "@A3", Icon = "wrench" },
        { Key = "CREDITS_DEV", Handle = "@2areyoumental", Icon = "wrench" },
    }
    for _, row in ipairs(rows) do row.Role = HX.translate(row.Key) end
    local view = WindUI:InfoCredits({
        Parent = HX.InfoTab.UIElements.ContainerFrame, Window = Window,
        Title = HX.translate("CREDITS_HEADER"), Rows = rows,
    })
    HX.creditsView, HX.creditsHeader, HX.creditsRoles = view, view.Header, {}
    for index, row in ipairs(rows) do
        HX.creditsRoles[index] = { Key = row.Key, Label = view.Roles[index] }
    end
    return view.Frame
end

HX.creditsPanel = HX.buildCreditsPanel()
HX.updateInfoCard()

task.spawn(function()
    local frame = HX.InfoTab.UIElements.ContainerFrame
    while HX.infoCard and not HX.infoCard.Destroyed and frame.Parent and not Api.closed do
        task.wait(1)
        if HX.infoCard and not HX.infoCard.Destroyed and frame.Parent and frame.Visible and HX.InfoTab.Selected ~= false and frame.AbsoluteSize.X > 0 then
            HX.updateInfoCard()
        end
    end
end)

task.spawn(function()
    task.wait(4)
    for _ = 1, 6 do
        if Api.closed or not HX.infoCard then return end
        local ok, result = pcall(HX.send, "region", "/api/region", HX.basePayload())
        if ok and type(result) == "table" and result.ok == true then
            local region = tostring(result.region or "")
            if region ~= "" then
                HX.serverRegion = region
                HX.updateInfoCard()
                return
            end
        end
        task.wait(20)
    end
end)

function HX.applyLanguage(code, label, quiet)
    if type(code) ~= "string" or code == "" then return end

    local flags = {
        en = "\240\159\135\186\240\159\135\184", es = "\240\159\135\170\240\159\135\184", ar = "\240\159\135\184\240\159\135\166", ru = "\240\159\135\183\240\159\135\186", de = "\240\159\135\169\240\159\135\170",
        fr = "\240\159\135\171\240\159\135\183", he = "\240\159\135\174\240\159\135\177", id = "\240\159\135\174\240\159\135\169", it = "\240\159\135\174\240\159\135\185", da = "\240\159\135\169\240\159\135\176",
        pl = "\240\159\135\181\240\159\135\177", pt = "\240\159\135\181\240\159\135\185", tr = "\240\159\135\185\240\159\135\183", vi = "\240\159\135\187\240\159\135\179", zh = "\240\159\135\168\240\159\135\179",
    }
    local codes = {
        en = "EN", es = "ES", ar = "AR", ru = "RU", de = "DE",
        fr = "FR", he = "HE", id = "ID", it = "IT", da = "DA",
        pl = "PL", pt = "PT", tr = "TR", vi = "VI", zh = "ZH",
    }
    local names = {
        en = "English", es = "Espa\195\177ol", ar = "\216\167\217\132\216\185\216\177\216\168\217\138\216\169", ru = "\208\160\209\131\209\129\209\129\208\186\208\184\208\185",
        de = "Deutsch", fr = "Fran\195\167ais", he = "\215\162\215\145\215\168\215\153\215\170", id = "Bahasa Indonesia",
        it = "Italiano", da = "Dansk", pl = "Polski", pt = "Portugu\195\170s",
        tr = "T\195\188rk\195\167e", vi = "Ti\225\186\191ng Vi\225\187\135t", zh = "\231\174\128\228\189\147\228\184\173\230\150\135",
    }

    local sourceCode = HX.language
    HX.language = code

    
    pcall(HX.retranslateTree, sourceCode)
    pcall(function()
        WindUI:Localization(HX.localization)
        WindUI:SetLanguage(code)
    end)
    pcall(HX.langWrite, code)

    if HX.languageTag then
        pcall(HX.languageTag.SetTitle, HX.languageTag, (flags[code] or "") .. " " .. (codes[code] or string.upper(code)))
    end

    if HX.languageDropdown then
        pcall(function()
            HX.languageDropdown.Value = names[code] or label or code
            if type(HX.languageDropdown.Display) == "function" then
                HX.languageDropdown:Display()
            end
        end)
    end

    pcall(HX.updateInfoCard)

    if not quiet and sourceCode ~= code then
        HX.historyPush({
            undo = function() HX.applyLanguage(sourceCode, nil, true) end,
            redo = function() HX.applyLanguage(code, nil, true) end,
        })
    end

    HX.switchingLanguage = false
    if quiet then return end

    local template = HX.translate("LANGUAGE_SWITCHED")
    local ok, formatted = pcall(string.format, template, names[code] or label or code)
    local line = (ok and formatted) or template

    pcall(function()
        WindUI:Notify({
            Title = HX.translate("LANGUAGE_WORD"),
            Content = line,
            Duration = 2,
            Icon = "globe"
        })
    end)
end

do
    local saved = HX.langRead()
    if saved and saved ~= "en" then
        local label = saved
        for _, option in ipairs(HX.languageOptions) do
            if option.code == saved then
                label = option.label
                break
            end
        end
        HX.ensureLanguage(saved, function(ready)
            if ready and HX.language ~= saved then
                HX.applyLanguage(saved, label, true)
            end
        end)
    end
end

task.defer(function()
    HX.prefetchLanguages()
end)

HX.InfoTab:Space({ Columns = 2 })

HX.keybindToggle = HX.InfoTab:Keybind({
    Title = "loc:UI_KEYBIND",
    Desc = "loc:UI_KEYBIND_DESC",
    Value = "RightControl",
    Callback = function(key)
        local code = Enum.KeyCode[key]
        if not code then return end
        HX.Log.guard("ui.togglekey", function()
            Window:SetToggleKey(code)
        end)
        WindUI:Notify({Title = "loc:KEYBIND_SET", Content = string.format(HX.translate("KEYBIND_UPDATED"), key), Duration = 2, Icon = "keyboard"})
    end
})

HX.Log.guard("ui.togglekey", function()
    local value = HX.keybindToggle and HX.keybindToggle.Value
    local name = type(value) == "string" and value or "RightControl"
    local code = Enum.KeyCode[name] or Enum.KeyCode.RightControl
    if code then
        Window:SetToggleKey(code)
    end
end)

HX.buildFeedbackUi = function()
    local tab = HX.InfoTab
    local scroll = tab.UIElements.ContainerFrame
    local stage = tab.UIElements.ContainerFrameCanvas
    local TweenService = game:GetService("TweenService")
    local RunService = game:GetService("RunService")

    HX.feedbackInput = tab:Input({
        Title = "loc:FEEDBACK_TITLE",
        Desc = "loc:FEEDBACK_DESC",
        Type = "Textarea",
        Placeholder = "loc:FEEDBACK_PLACEHOLDER",
        Callback = function() end,
    })

    local feedbackTarget = HX.feedbackInput.InputFrame.UIElements.Main

    local function feedbackText()
        local ok, value = pcall(function()
            return HX.feedbackInput and HX.feedbackInput.Value
        end)
        if not ok or type(value) ~= "string" then return "" end
        value = string.gsub(value, "^%s+", "")
        value = string.gsub(value, "%s+$", "")
        if #value > 2000 then
            local ok, boundary = pcall(utf8.offset, value, 0, 2001)
            value = string.sub(value, 1, ok and boundary and (boundary - 1) or 2000)
        end
        return value
    end

    HX.feedbackSend = tab:Button({
        Title = "loc:FEEDBACK_SEND",
        Desc = "loc:FEEDBACK_SEND_DESC",
        Icon = "send",
        Callback = function()
            local text = feedbackText()
            if text == "" then
                WindUI:Notify({Title = "loc:FEEDBACK_TITLE", Content = "loc:FEEDBACK_EMPTY", Duration = 2, Icon = "triangle-alert"})
                return
            end
            if HX.feedbackBusy then return end
            HX.feedbackBusy = true

            task.spawn(function()
                local payload = HX.basePayload()
                payload.kind = "feedback"
                payload.message = text
                local ok, result = pcall(HX.send, "feedback", "/api/feedback", payload)
                local sent = ok and type(result) == "table" and result.ok == true
                HX.feedbackBusy = false
                if Api.closed then return end
                if sent then
                    pcall(function() HX.feedbackInput:Set("") end)
                end
                WindUI:Notify({
                    Title = "loc:FEEDBACK_TITLE",
                    Content = sent and "loc:FEEDBACK_SENT" or "loc:FEEDBACK_FAILED",
                    Duration = 3,
                    Icon = sent and "circle-check" or "triangle-alert",
                })
            end)
        end,
    })

    
    
    local float = WindUI:InfoFeedback({ Parent = stage, Window = Window, Icon = "message-square" })

    float.Activated:Connect(function()
        local offset = feedbackTarget.AbsolutePosition.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y - 16
        local limit = math.max(0, scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteWindowSize.Y)
        local goal = math.clamp(offset, 0, limit)
        TweenService:Create(scroll, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            CanvasPosition = Vector2.new(scroll.CanvasPosition.X, goal),
        }):Play()
    end)

    local function boxReached()
        local bottom = feedbackTarget.AbsolutePosition.Y + feedbackTarget.AbsoluteSize.Y
        local edge = scroll.AbsolutePosition.Y + scroll.AbsoluteSize.Y - 10
        return bottom <= edge
    end
    local waited = 0
    local feedbackHeartbeat
    feedbackHeartbeat = RunService.Heartbeat:Connect(function(dt)
        waited = waited + dt
        if waited < 0.12 then return end
        waited = 0
        local show = stage.Visible and not boxReached()
        if float.Visible ~= show then
            float.Visible = show
        end
    end)
    Window:OnDestroy(function()
        if feedbackHeartbeat then feedbackHeartbeat:Disconnect() end
        if float.Parent then float:Destroy() end
    end)
end

HX.buildFeedbackUi()

HX.buildInfoActions = function()
    local card = HX.infoCard
    if not card then return end

    local function confirm(titleKey, contentKey, icon, run)
        HX.dialog({
            Title = "loc:" .. titleKey,
            Content = "loc:" .. contentKey,
            Icon = icon,
            Buttons = {
                { Title = "loc:CONFIRM_CANCEL", Icon = "xmark", Variant = "Secondary", Callback = function() end },
                { Title = "loc:CONFIRM_YES", Icon = "check", Variant = "Primary", Callback = run },
            },
        })
    end

    local function currentPlayer()
        return game:GetService("Players").LocalPlayer
    end

    local function rejoin()
        task.spawn(function()
            local ok = pcall(function()
                game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, currentPlayer())
            end)
            if not ok then
                WindUI:Notify({Title = "loc:INFO_REJOIN", Content = "loc:INFO_REJOIN_FAILED", Duration = 3, Icon = "triangle-alert"})
            end
        end)
    end

    local function hop()
        task.spawn(function()
            local ok, servers = pcall(HX.getServers, game.PlaceId)
            if not ok or type(servers) ~= "table" then servers = {} end

            local options = {}
            for _, server in ipairs(servers) do
                if type(server) == "table" and server.id and server.id ~= game.JobId then
                    options[#options + 1] = server.id
                end
            end

            if #options == 0 then
                WindUI:Notify({Title = "loc:INFO_HOP", Content = "loc:INFO_HOP_EMPTY", Duration = 3, Icon = "triangle-alert"})
                return
            end

            local pick = options[math.random(1, #options)]
            local teleported = pcall(function()
                game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, pick, currentPlayer())
            end)
            if not teleported then
                WindUI:Notify({Title = "loc:INFO_HOP", Content = "loc:INFO_HOP_FAILED", Duration = 3, Icon = "triangle-alert"})
            end
        end)
    end

    
    card:SetActions({
        { Id = "Rejoin", Title = HX.translate("INFO_REJOIN"), Callback = function()
            confirm("INFO_REJOIN", "INFO_REJOIN_CONFIRM", "rotate-cw", rejoin)
        end },
        { Id = "Hop", Title = HX.translate("INFO_HOP"), Callback = function()
            confirm("INFO_HOP", "INFO_HOP_CONFIRM", "refresh-cw", hop)
        end },
    })
end

HX.buildInfoActions()
Window:OnDestroy(function()
    if HX.infoCard then HX.infoCard:Destroy() end
    if HX.creditsView then HX.creditsView:Destroy() end
    HX.infoCard = nil
end)

Window:Divider()
HX.loadStage(HX.stageLabel("MAIN_TAB"), 0.28)
HX.MainTab = Window:Tab({Title = "loc:MAIN_TAB", Icon = "house", Locked = false})
do
    local function buildMain()
    local tab = HX.MainTab
    local players = game:GetService("Players")
    local player = players.LocalPlayer
    local input = game:GetService("UserInputService")
    local Creator = WindUI.Creator
    local RunService = game:GetService("RunService")
    local connections, objects = {}, {}
    local stopped, restoreFPS = false, nil
    local function own(connection) connections[#connections + 1] = connection; return connection end
    local function copy(value) if value and value ~= "" then HX.setclipboard(tostring(value)) end end
    local function escape(value)
        return tostring(value or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
    end
    local function clock(seconds)
        seconds = math.max(0, math.floor(tonumber(seconds) or 0))
        return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
    end
    local function keep(object) objects[#objects + 1] = object; return object end
    local function card(parent) return parent:VStack({Card = true, CardPadding = 10, CardRadius = 16}) end
    local GLASS_IMAGE = "rbxassetid://84819521201001"
    local GLASS_SLICE = Rect.new(512, 325, 512, 325)
    local GLASS_RADIUS = 325
    local GLASS_TRANSPARENCY = 0.55
    local SEGMENT_WASH = 0.9
    local function glass(parent, title, callback, size, order, config)
        config = config or {}
        local segment = config.Mode == "Segment"
        local radius = config.Radius or 10
        local button = keep(Creator.New("TextButton", {
            Name = config.Name or "MainAction", Parent = parent, Size = size, LayoutOrder = order or 1,
            Position = config.Position, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
            AutoButtonColor = false, Text = "", ZIndex = 2,
        }))
        Creator.New("UICorner", {CornerRadius = UDim.new(0, radius), Parent = button})
        local glassImage = Creator.New("ImageLabel", {
            Name = "Glass", Parent = button, Image = GLASS_IMAGE, ScaleType = Enum.ScaleType.Slice,
            SliceCenter = GLASS_SLICE, SliceScale = radius / GLASS_RADIUS, BackgroundTransparency = 1,
            BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0), ZIndex = 1, Visible = false,
            ImageTransparency = 1,
        })
        Creator.New("UIGradient", {
            Rotation = 90, Parent = glassImage, Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(0.6, 0.15),
                NumberSequenceKeypoint.new(1, 0.6),
            }),
        })
        local label = keep(Creator.New("TextLabel", {
            Name = "Title", Parent = button, Text = title or "", TextSize = config.TextSize or 12,
            BackgroundTransparency = 1, BorderSizePixel = 0, TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 0.5,
            FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
            TextColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 1, 0), ZIndex = 3,
        }))
        local state = {Button = button, Label = label}
        function state:SetSelected(value)
            local on = value == true
            local active = segment and on or not segment
            button.BackgroundTransparency = active and SEGMENT_WASH or 1
            glassImage.Visible = active
            glassImage.ImageTransparency = active and GLASS_TRANSPARENCY or 1
            label.TextTransparency = active and 0 or 0.5
        end
        state:SetSelected(segment and config.Selected or false)
        if callback then own(button.Activated:Connect(callback)) end
        return state
    end
    local function actions(parent, items)
        local row = keep(Creator.New("Frame", {
            Name = "MainActions", Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1,
            Parent = parent.ElementFrame,
        }))
        keep(Creator.New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder, Parent = row,
        }))
        local buttons = {}
        local count = #items
        for index, item in ipairs(items) do
            buttons[index] = glass(row, item[1], item[2], UDim2.new(1 / count, -6 * (count - 1) / count, 1, 0), index, {Icon = item[3]}).Button
        end
        return buttons
    end
    local function switcher(parent, titles, panels)
        local strip = keep(Creator.New("Frame", {Name = "InspectorSegments", Parent = parent.ElementFrame,
            Size = UDim2.new(1, 20, 0, 40), BackgroundTransparency = 1, LayoutOrder = -1}, {
            Creator.New("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4)}),
            Creator.New("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}),
        }))
        local buttons, selected = {}, nil
        local count = #titles
        local function select(index)
            if not panels[index] or selected == index then return end
            selected = index
            for i, panel in ipairs(panels) do
                panel.ElementFrame.Visible = i == index
                buttons[i]:SetSelected(i == index)
            end
        end
        for index, title in ipairs(titles) do
            buttons[index] = glass(strip, title, function() select(index) end,
                UDim2.new(1 / count, -4, 1, 0), index, {Name = "Inspector" .. title, Mode = "Segment", Radius = 16, TextSize = 13})
        end
        local list = parent.ElementFrame:FindFirstChildOfClass("UIListLayout")
        if list then list.SortOrder = Enum.SortOrder.LayoutOrder end
        select(1)
        return select
    end
    tab:Section({Title = "Main", Icon = "house", Desc = "Performance, inspectors and local tools.", TextSize = 22})
    tab:Section({Title = "Performance", Icon = "gauge"})
    do
        local fps = card(tab)
        local cap = type(setfpscap) == "function" and setfpscap or nil
        local previous = 60
        if type(getfpscap) == "function" then
            local ok, value = pcall(getfpscap)
            if ok and type(value) == "number" then previous = value end
        end
        local unlimited, limited, limit = true, false, 144
        local status = fps:Paragraph({Title = "Frame rate", Desc = cap and "Unlimited" or "Not supported by this executor"})
        local limitToggle, unlimitedToggle
        local function apply()
            if stopped or not cap then return end
            local value = unlimited and 0 or limited and limit or previous
            local ok = pcall(cap, value)
            status:SetDesc(ok and (unlimited and "Unlimited" or limited and tostring(limit) .. " FPS" or "Previous cap restored") or "Executor rejected the FPS cap")
        end
        limitToggle = fps:Toggle({Title = "Use FPS limit", Value = false, Callback = function(value)
            limited = value
            if value then unlimited = false; if unlimitedToggle then unlimitedToggle:Set(false, false) end end
            apply()
        end})
        fps:Input({Title = "FPS limit", Value = "144", Placeholder = "1-4000", Callback = function(value)
            local n = tonumber(value)
            if n and n == n and math.abs(n) < math.huge then limit = math.clamp(math.floor(n), 1, 4000); apply() end
        end})
        unlimitedToggle = fps:Toggle({Title = "Remove FPS cap", Value = true, Callback = function(value)
            unlimited = value
            if value then limited = false; if limitToggle then limitToggle:Set(false, false) end end
            apply()
        end})
        restoreFPS = function() if cap then pcall(cap, previous) end end
        apply()
    end
    tab:Section({Title = "Inspectors", Icon = "scan"})
    do
        local group = card(tab)
        local blockRows, boxRows = group:VStack({}), group:VStack({})
        local showInspector = switcher(group, {"Block", "Boombox"}, {blockRows, boxRows})
        local selected, selectedBox, selectedOwner = nil, nil, nil
        local blockOutline, boxOutline = false, false
        local soundID, previewID = "", ""
        local known, left, pending = {}, {}, {}
        local function remember(who) known[who.Name] = {Name = who.Name, DisplayName = who.DisplayName} end
        for _, who in ipairs(players:GetPlayers()) do remember(who) end
        local function highlight(name)
            local item = Instance.new("Highlight")
            item.Name, item.FillTransparency, item.OutlineTransparency = name, 1, 0
            item.OutlineColor = Color3.fromRGB(107, 189, 255)
            item.DepthMode = Enum.HighlightDepthMode.Occluded
            item.Enabled, item.Parent = false, workspace
            objects[#objects + 1] = item
            return item
        end
        local blockGlow, boxGlow = highlight("EnderSelectedBlock"), highlight("EnderSelectedBoombox")
        local ownerCard = blockRows:Paragraph({Title = "Block owner", Desc = "No block selected"})
        actions(blockRows, {{"Copy username", function() copy(selectedOwner and selectedOwner.Name) end},
            {"Copy display name", function() copy(selectedOwner and selectedOwner.DisplayName) end}})
        blockRows:Toggle({Title = "Outline selected block", Value = false, Callback = function(v)
            blockOutline = v; blockGlow.Enabled = v and selected ~= nil
        end})
        local boxCard = boxRows:Paragraph({Title = "Boombox", Desc = "No boombox selected"})
        actions(boxRows, {{"Copy audio ID", function() copy(soundID) end}})
        boxRows:Toggle({Title = "Outline selected boombox", Value = false, Callback = function(v)
            boxOutline = v; boxGlow.Enabled = v and selectedBox ~= nil
        end})
        local preview = Instance.new("Sound")
        preview.Name, preview.Volume, preview.Parent = "EnderBoomboxPreview", 0.35, game:GetService("SoundService")
        objects[#objects + 1] = preview
        local previewState = "idle"
        local function text(parent, props)
            local config = {
                BackgroundTransparency = 1, BorderSizePixel = 0, TextSize = 11, TextColor3 = Color3.new(1, 1, 1),
                TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
                FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium), ZIndex = 2, Parent = parent,
            }
            for key, value in pairs(props) do config[key] = value end
            return keep(Creator.New("TextLabel", config))
        end
        local panel = keep(Creator.New("Frame", {
            Name = "AudioPlayer", Size = UDim2.new(1, 0, 0, 124), BackgroundTransparency = 1,
            Parent = boxRows.ElementFrame,
        }))
        text(panel, {Name = "Head", Text = "AUDIO PREVIEW", TextSize = 10, TextTransparency = 0.34,
            Position = UDim2.new(0, 2, 0, 0), Size = UDim2.new(0.5, 0, 0, 16)})
        local status = text(panel, {Name = "Status", Text = "Nothing loaded", TextSize = 10, TextTransparency = 0.34,
            TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0.5, -2, 0, 0), Size = UDim2.new(0.5, 0, 0, 16)})
        local field = keep(Creator.New("TextBox", {
            Name = "AudioId", Text = "", PlaceholderText = "Audio ID or rbxassetid://", ClearTextOnFocus = false,
            Size = UDim2.new(1, -92, 0, 32), Position = UDim2.new(0, 0, 0, 22), TextSize = 13,
            TextColor3 = Color3.new(1, 1, 1), TextTransparency = 0.06, PlaceholderColor3 = Color3.fromRGB(148, 148, 160),
            TextXAlignment = Enum.TextXAlignment.Left, BackgroundColor3 = Color3.fromRGB(9, 9, 13),
            BackgroundTransparency = 0.52, BorderSizePixel = 0, FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
            ZIndex = 2, Parent = panel,
        }, {
            Creator.New("UICorner", {CornerRadius = UDim.new(0, 10)}),
            Creator.New("UIStroke", {Color = Color3.new(1, 1, 1), Thickness = 1, Transparency = 0.86}),
            Creator.New("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}),
        }))
        local loadButton = glass(panel, "Load", nil, UDim2.new(0, 86, 0, 32), 1, {Icon = "download"})
        loadButton.Button.Position = UDim2.new(1, -86, 0, 22)
        local track = keep(Creator.New("TextButton", {
            Name = "Seek", Text = "", Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 0, 60),
            BackgroundTransparency = 1, AutoButtonColor = false, ZIndex = 2, Parent = panel,
        }))
        local bar = keep(Creator.New("Frame", {
            Name = "Bar", Size = UDim2.new(1, 0, 0, 5), Position = UDim2.new(0, 0, 0.5, -3),
            BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.82, BorderSizePixel = 0,
            ZIndex = 2, Parent = track,
        }, {
            Creator.New("UICorner", {CornerRadius = UDim.new(1, 0)}),
        }))
        local fill = keep(Creator.New("Frame", {
            Name = "Fill", Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(122, 196, 255),
            BackgroundTransparency = 0.15, BorderSizePixel = 0, ZIndex = 3, Parent = bar,
        }, {
            Creator.New("UICorner", {CornerRadius = UDim.new(1, 0)}),
        }))
        keep(Creator.New("Frame", {
            Name = "Knob", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.new(0, 9, 0, 9), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
            ZIndex = 4, Parent = fill,
        }, {
            Creator.New("UICorner", {CornerRadius = UDim.new(1, 0)}),
        }))
        local elapsed = text(panel, {Name = "Elapsed", Text = "0:00", TextSize = 10, TextTransparency = 0.4,
            Position = UDim2.new(0, 2, 0, 74), Size = UDim2.new(0.5, 0, 0, 14)})
        local total = text(panel, {Name = "Total", Text = "0:00", TextSize = 10, TextTransparency = 0.4,
            TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0.5, -2, 0, 74), Size = UDim2.new(0.5, 0, 0, 14)})
        local transport = keep(Creator.New("Frame", {
            Name = "Transport", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0, 92),
            BackgroundTransparency = 1, Parent = panel,
        }, {
            Creator.New("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
                SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center}),
        }))
        local playButton = glass(transport, "Play", nil, UDim2.new(0.36, -4, 1, 0), 1, {Icon = "play"})
        local stopButton = glass(transport, "Stop", nil, UDim2.new(0.22, -4, 1, 0), 2, {Icon = "square"})
        glass(transport, "Copy ID", function() copy(previewID) end, UDim2.new(0.42, -4, 1, 0), 3, {Icon = "clipboard"})
        local function parseId(value)
            local source = tostring(value or "")
            return source:match("[?&]id=(%d+)") or source:match("rbxassetid://(%d+)") or source:match("^%s*(%d+)%s*$") or ""
        end
        local function stopAudio()
            preview:Stop()
            preview.TimePosition = 0
            previewState = "stopped"
        end
        local function paint()
            local length = preview.TimeLength
            local position = preview.TimePosition
            if length and length > 0 and length == length then
                fill.Size = UDim2.new(math.clamp(position / length, 0, 1), 0, 1, 0)
                elapsed.Text = clock(position)
                total.Text = clock(length)
            else
                fill.Size = UDim2.new(0, 0, 1, 0)
                elapsed.Text = "0:00"
                total.Text = "0:00"
            end
            if preview.IsPlaying then
                previewState = "playing"
                playButton.Label.Text = "Pause"
                status.Text = "Playing"
            elseif previewState == "paused" then
                playButton.Label.Text = "Play"
                status.Text = "Paused"
            else
                playButton.Label.Text = "Play"
            end
        end
        local function load()
            local id = parseId(field.Text)
            if id == "" then
                status.Text = "Numeric audio ID required"
                return
            end
            stopAudio()
            previewID = id
            preview.SoundId = "rbxassetid://" .. id
            previewState = "ready"
            status.Text = "Ready"
            field.Text = id
            paint()
        end
        local function toggle()
            if stopped then return end
            if previewID == "" then
                load()
                if previewID == "" then return end
            end
            if preview.IsPlaying then
                preview:Pause()
                previewState = "paused"
            elseif preview.TimePosition > 0 and preview.TimePosition < preview.TimeLength then
                preview:Resume()
                previewState = "playing"
            else
                preview:Play()
                previewState = "playing"
            end
            paint()
        end
        local function stop()
            stopAudio()
            paint()
            status.Text = previewID ~= "" and "Stopped" or "Nothing loaded"
        end
        own(loadButton.Button.Activated:Connect(load))
        own(playButton.Button.Activated:Connect(toggle))
        own(stopButton.Button.Activated:Connect(stop))
        own(field.FocusLost:Connect(function() if previewID == "" then load() end end))
        own(track.InputBegan:Connect(function(object)
            if preview.TimeLength <= 0 then return end
            if object.UserInputType ~= Enum.UserInputType.MouseButton1 and object.UserInputType ~= Enum.UserInputType.Touch then return end
            local ratio = math.clamp((object.Position.X - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
            preview.TimePosition = preview.TimeLength * ratio
            paint()
        end))
        own(RunService.Heartbeat:Connect(function()
            if stopped or previewState == "idle" then return end
            paint()
        end))
        own(preview.Ended:Connect(function()
            if stopped then return end
            previewState = "ready"
            paint()
            status.Text = "Finished"
        end))
        local names = {SuperFlyGoldBoombox=true, BoomboxGearThree=true, DualGoldenSuperFlyBoombox=true, DubstepBoombox=true, BeatUpBoombox=true}
        local function drawOwner()
            if not selectedOwner then ownerCard:SetDesc(selected and "Server build - owner unavailable" or "No block selected"); return end
            local record = selectedOwner
            local online = players:FindFirstChild(record.Name) and not left[record.Name]
            ownerCard:SetDesc("Display name - " .. escape(record.DisplayName or "Unavailable") .. "\nUsername - @" .. escape(record.Name) .. "\nStatus - " .. (online and "In server" or left[record.Name] and "Left server" or "Not in server"))
        end
        local function resolveOwner(name)
            if known[name] or (pending[name] and os.clock() < pending[name]) or not name:match("^[%w_]+$") or #name > 20 then return end
            pending[name] = math.huge
            task.spawn(function()
                local ok, info = pcall(function()
                    local id = players:GetUserIdFromNameAsync(name)
                    return game:GetService("UserService"):GetUserInfosByUserIdsAsync({id})[1]
                end)
                pending[name] = nil
                if not ok or type(info) ~= "table" or type(info.DisplayName) ~= "string" then pending[name] = os.clock() + 15 end
                if stopped or not ok or type(info) ~= "table" or type(info.DisplayName) ~= "string" then return end
                known[name] = {Name = info.Username or name, DisplayName = info.DisplayName}
                if selectedOwner and selectedOwner.Name == name then selectedOwner = known[name]; drawOwner() end
            end)
        end
        local function inspect(target)
            if stopped then return end
            selected, selectedBox, selectedOwner, soundID = nil, nil, nil, ""
            blockGlow.Adornee, boxGlow.Adornee = nil, nil
            local bricks = workspace:FindFirstChild("Bricks")
            if target and target:IsA("BasePart") and bricks and target:IsDescendantOf(bricks) then
                selected = target
                local folder = target
                while folder.Parent and folder.Parent ~= bricks do folder = folder.Parent end
                if folder ~= target then selectedOwner = known[folder.Name] or {Name = folder.Name}; resolveOwner(folder.Name) end
                blockGlow.Adornee = target
            end
            drawOwner()
            if selected then showInspector(1) end
            local current = target
            while current and current ~= workspace do
                if names[current.Name] then selectedBox = current; break end
                current = current.Parent
            end
            if selectedBox then
                local sound = selectedBox:FindFirstChildWhichIsA("Sound", true)
                local asset = sound and sound.SoundId or ""
                soundID = asset:match("[?&]id=(%d+)") or asset:match("rbxassetid://(%d+)") or asset:match("^(%d+)$") or ""
                boxCard:SetDesc(escape(selectedBox.Name) .. "\nAudio ID - " .. (soundID ~= "" and soundID or "Unavailable"))
                boxGlow.Adornee = selectedBox:IsA("Model") and selectedBox or selectedBox:FindFirstChild("Handle")
                if soundID ~= "" then field.Text = soundID; load() end
                showInspector(2)
            else boxCard:SetDesc("No boombox selected") end
            blockGlow.Enabled = blockOutline and selected ~= nil
            boxGlow.Enabled = boxOutline and boxGlow.Adornee ~= nil
        end
        own(players.PlayerAdded:Connect(function(who) remember(who); left[who.Name] = nil; if selectedOwner and selectedOwner.Name == who.Name then selectedOwner = known[who.Name]; drawOwner() end end))
        own(players.PlayerRemoving:Connect(function(who) remember(who); left[who.Name] = true; drawOwner() end))
        own(input.InputBegan:Connect(function(key, processed)
            if not processed and key.UserInputType == Enum.UserInputType.MouseButton1 then inspect(player:GetMouse().Target) end
        end))
        own(input.TouchTapInWorld:Connect(function(position, processed)
            if processed then return end
            local camera = workspace.CurrentCamera
            if not camera then return end
            local ray = camera:ScreenPointToRay(position.X, position.Y)
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = player.Character and {player.Character} or {}
            local hit = workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
            inspect(hit and hit.Instance)
        end))
        own(workspace.DescendantRemoving:Connect(function(item) if item == selected or item == selectedBox then inspect(nil) end end))
    end
    tab:Section({Title = "Local identity", Icon = "user-round"})
    local identityCard = card(tab)
    local alias, masking = "Player", false
    local labels = {}
    local added
    local function restoreNames()
        if added then added:Disconnect(); added = nil end
        for object, state in pairs(labels) do
            state.Connection:Disconnect()
            if state.DestroyConnection then state.DestroyConnection:Disconnect() end
            if object.Parent and object.Text == state.Last then object.Text = state.Original end
        end
        labels = {}
    end
    local function watch(object)
        if not (object:IsA("TextLabel") or object:IsA("TextButton")) or labels[object] then return end
        local state = {Original = object.Text}
        labels[object] = state
        local function update()
            if stopped or not masking or object.Text == state.Last then return end
            state.Original = object.Text
            local text = state.Original
            local names = {player.Name, player.DisplayName}
            table.sort(names, function(a, b) return #a > #b end)
            local parts, start = {}, 1
            while start <= #text do
                local first, last
                for _, name in ipairs(names) do
                    local a, b = string.find(text, name, start, true)
                    if a and (not first or a < first) then first, last = a, b end
                end
                if not first then parts[#parts + 1] = text:sub(start); break end
                parts[#parts + 1] = text:sub(start, first - 1); parts[#parts + 1] = alias; start = last + 1
            end
            state.Last = table.concat(parts)
            if object.Text ~= state.Last then object.Text = state.Last end
        end
        state.Connection = object:GetPropertyChangedSignal("Text"):Connect(update)
        if object.Destroying then
            state.DestroyConnection = object.Destroying:Connect(function()
                state.Connection:Disconnect()
                state.DestroyConnection:Disconnect()
                labels[object] = nil
            end)
        end
        update()
    end
    local function applyNames()
        restoreNames()
        if not masking or stopped then return end
        for _, object in ipairs(game:GetDescendants()) do watch(object) end
        added = game.DescendantAdded:Connect(watch)
    end
    local savedDisplay, savedUser = "", ""
    do
        if type(readfile) == "function" and type(isfile) == "function" then
            local ok, body = pcall(function()
                if isfile("EnderHub/Profile.txt") then return readfile("EnderHub/Profile.txt") end
            end)
            if ok and type(body) == "string" then
                local first, second = body:match("^([^\r\n]*)[\r\n]+([^\r\n]*)")
                savedDisplay = tostring(first or ""):sub(1, 48)
                savedUser = tostring(second or ""):sub(1, 32)
            end
        end
    end
    HX.localDisplay = savedDisplay ~= "" and savedDisplay or nil
    HX.localUser = savedUser ~= "" and savedUser or nil
    alias = HX.localDisplay or "Player"
    local displayInput = identityCard:Input({Title = "Display name", Value = savedDisplay ~= "" and savedDisplay or (player and player.DisplayName or ""), Placeholder = "Name shown inside the hub", Callback = function() end})
    local userInput = identityCard:Input({Title = "Username", Value = savedUser ~= "" and savedUser or (player and player.Name or ""), Placeholder = "Handle shown inside the hub", Callback = function() end})
    identityCard:Toggle({Title = "Mask my name locally", Value = false, Callback = function(value) masking = value; applyNames() end})
    local identityActions = keep(Creator.New("Frame", {
        Name = "IdentityActions", Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1,
        Parent = identityCard.ElementFrame,
    }, {
        Creator.New("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center}),
    }))
    local applyButton = glass(identityActions, "Apply", nil, UDim2.new(0.5, -3, 1, 0), 1, {Icon = "check"})
    local resetButton = glass(identityActions, "Reset", nil, UDim2.new(0.5, -3, 1, 0), 2, {Icon = "rotate-ccw"})
    local function saveProfile()
        if type(writefile) ~= "function" then return end
        if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder("EnderHub") then pcall(makefolder, "EnderHub") end
        pcall(writefile, "EnderHub/Profile.txt", (HX.localDisplay or "") .. "\n" .. (HX.localUser or ""))
    end
    local function readField(field, limit)
        local value = tostring(field.Value or ""):gsub("[<>%c]", ""):gsub("^%s+", ""):gsub("%s+$", "")
        return value:sub(1, limit)
    end
    own(applyButton.Button.Activated:Connect(function()
        local display = readField(displayInput, 48)
        local username = readField(userInput, 32)
        HX.localDisplay = display ~= "" and display or nil
        HX.localUser = username ~= "" and username or nil
        alias = HX.localDisplay or "Player"
        saveProfile()
        applyNames()
        pcall(HX.updateInfoCard)
        WindUI:Notify({Title = "Local identity", Content = "Name and username updated on this device", Duration = 2, Icon = "user-round"})
    end))
    own(resetButton.Button.Activated:Connect(function()
        HX.localDisplay, HX.localUser = nil, nil
        alias = "Player"
        pcall(function() displayInput:Set(player and player.DisplayName or "") end)
        pcall(function() userInput:Set(player and player.Name or "") end)
        saveProfile()
        applyNames()
        pcall(HX.updateInfoCard)
        WindUI:Notify({Title = "Local identity", Content = "Hub shows your real name again", Duration = 2, Icon = "user-round"})
    end))
    local function cleanup()
        if stopped then return end
        stopped, masking = true, false
        restoreNames()
        for _, connection in ipairs(connections) do connection:Disconnect() end
        for _, object in ipairs(objects) do object:Destroy() end
        if restoreFPS then restoreFPS() end
    end
    HX.cleanupBoombox = cleanup
    HX.Session.onStop(cleanup)
    end
    buildMain()
end
HX.loadStage(HX.stageLabel("LOCALPLAYER_TAB"), 0.34)
LocalPlayerTab = Window:Tab({Title = "loc:LOCALPLAYER_TAB", Icon = "circle-user", Locked = false})
LocalPlayerTab:Section({
    Title = "loc:LOCALPLAYER_TAB", 
    Icon = "user-round-pen",
    Desc = "loc:LOCALPLAYER_LONG_DESC"
})
LocalPlayerTab:Section({
    Title = "loc:SPEED_SECTION", 
    Icon = "gauge",
    Description = "Control your movement speed and teleportation"
})

Players = game:GetService("Players")
RunService = game:GetService("RunService")
lp = Players.LocalPlayer

cleanupConnections = {}
cleanupObjects = {}

function AddCleanupConnection(connection)
    table.insert(cleanupConnections, connection)
end

function AddCleanupObject(object)
    table.insert(cleanupObjects, object)
end

WalkspeedEnabled = false
WalkspeedValue = 16
WalkTPEnabled = false
WalkTPValue = 50

function ApplyWalkspeed()
    character = lp.Character
    if character and character:FindFirstChildOfClass("Humanoid") then
        character.Humanoid.WalkSpeed = WalkspeedEnabled and WalkspeedValue or 16
    end
end

speedGroup = LocalPlayerTab:HStack({})
speedGroup:Toggle({
    Title = "loc:SPEED_GROUP",
    Value = false,
    Callback = function(state)
        WalkspeedEnabled = state
        ApplyWalkspeed()
        HX.SafeNotify({
            Title ="loc:WALKSPEED",
            Content = state and "ON" or "OFF",
            Duration = 1,
            Icon = state and "toggle-right" or "toggle-left"
        })
    end
})

speedGroup:Space({ Columns = 0.5 })

speedGroup:Toggle({
    Title = "loc:WALKTP",
    Value = false,
    Callback = function(state)
        WalkTPEnabled = state
        HX.SafeNotify({
            Title = "loc:WALKTP",
            Content = state and "ON" or "OFF",
            Duration = 1,
            Icon = state and "toggle-right" or "toggle-left"
        })
    end
})

LocalPlayerTab:Space({ Columns = 0.5 })

LocalPlayerTab:Section({
    Title = "loc:WALKSPEED_AMOUNT",
    TextSize = 20
})

LocalPlayerTab:Slider({
    IsTooltip = true,
    Step = 1,
    Value = {
        Min = 16,
        Max = 100,
        Default = 16,
    },
    Icons = {
        From = "turtle",
        To = "rabbit",
    },
    Callback = function(value)
        WalkspeedValue = value
        ApplyWalkspeed()
    end
})

LocalPlayerTab:Section({
    Title = "loc:WALKTP_SPEED",
    TextSize = 20
})

LocalPlayerTab:Slider({
    IsTooltip = true,
    Step = 1,
    Value = {
        Min = 10,
        Max = 200,
        Default = 50,
    },
    Icons = {
        From = "walk",
        To = "rocket",
    },
    Callback = function(value)
        WalkTPValue = value
    end
})

charAddedConnection = lp.CharacterAdded:Connect(function()
    task.wait(0.1)
    ApplyWalkspeed()
end)
AddCleanupConnection(charAddedConnection)

LocalPlayerTab:Space({ Columns = 0.5 })

LocalPlayerTab:Section({
    Title = "loc:FLY_SECTION", 
    Icon = "bird",
    Description = "Flight mechanics and controls"
})

GameFlyRunning = false

function GameFly()
    GameFlyRunning = true
    while task.wait(0.01) and GameFlyRunning and _G.Fly do
        if _G.Fly == true then
            if lp:GetAttribute("Flying") == false then
                lp:SetAttribute("Flying", true)
            end
        else
            lp:SetAttribute("Flying", false)
            break
        end
    end
    GameFlyRunning = false
end

flyGroup = LocalPlayerTab:HStack({})
flyGroup:Toggle({
    Title = "loc:GAME_FLY",
    Value = false,
    Callback = function(state)
        _G.Fly = state
        if _G.Fly and not GameFlyRunning then 
            GameFly() 
        end
        HX.SafeNotify({
            Title = "loc:ENABLE_FLY",
            Content = state and "ON" or "OFF",
            Duration = 1,
            Icon = "toggle-right"
        })
    end
})

flyGroup:Space({ Columns = 1 })

flyGroup:Toggle({
    Title = "loc:CUSTOM_FLY",
    Value = false,
    Callback = function(state)
        customFlyEnabled = state
        
        if customFlyEnabled then
            character = lp.Character
            if character then
                humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
                if humanoidRootPart then
                    flyBodyVelocity = Instance.new("BodyVelocity")
                    flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
                    flyBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                    flyBodyVelocity.P = 10000
                    flyBodyVelocity.Parent = humanoidRootPart
                    AddCleanupObject(flyBodyVelocity)
                end
            end
        elseif flyBodyVelocity then
            flyBodyVelocity:Destroy()
            flyBodyVelocity = nil
        end
        
        HX.SafeNotify({
            Title = "loc:CUSTOM_FLY",
            Content = state and "ON" or "OFF",
            Duration = 1,
            Icon = state and "toggle-right" or "toggle-left"
        })
    end
})

LocalPlayerTab:Space({ Columns = 0.5 })

LocalPlayerTab:Section({
    Title = "loc:FLY_SPEED",
    TextSize = 20
})

LocalPlayerTab:Slider({
    IsTooltip = true,
    Step = 1,
    Value = {
        Min = 1,
        Max = 200,
        Default = 50,
    },
    Icons = {
        From = "feather",
        To = "plane",
    },
    Callback = function(value)
        flySpeed = value
    end
})

flyHeartbeatConnection = RunService.Heartbeat:Connect(function()
    if customFlyEnabled and flyBodyVelocity then
        camera = workspace.CurrentCamera
        moveDirection = Vector3.new(0, 0, 0)
        
        if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.W) then
            moveDirection = moveDirection + camera.CFrame.LookVector
        end
        if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.S) then
            moveDirection = moveDirection - camera.CFrame.LookVector
        end
        if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.A) then
            moveDirection = moveDirection - camera.CFrame.RightVector
        end
        if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.D) then
            moveDirection = moveDirection + camera.CFrame.RightVector
        end
        if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.Space) then
            moveDirection = moveDirection + Vector3.new(0, 1, 0)
        end
        if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.LeftShift) then
            moveDirection = moveDirection - Vector3.new(0, 1, 0)
        end
        
        if moveDirection.Magnitude > 0 then
            flyBodyVelocity.Velocity = moveDirection.Unit * flySpeed
        else
            flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
        end
    end
end)
AddCleanupConnection(flyHeartbeatConnection)

LocalPlayerTab:Space({ Columns = 0.5 })

LocalPlayerTab:Section({
    Title = "loc:OTHERS_SECTION", 
    Icon = "more-horizontal",
    Description = "Additional character abilities and features"
})

othersGroup = LocalPlayerTab:HStack({})
othersGroup:Toggle({
    Title = "loc:NOCLIP",
    Value = false,
    Callback = function(state)
        noclipEnabled = state
        HX.SafeNotify({
            Title = "loc:NOCLIP",
            Content = state and "ON" or "OFF",
            Duration = 1,
            Icon = state and "toggle-right" or "toggle-left"
        })
    end
})

othersGroup:Space({ Columns = 1 })

othersGroup:Toggle({
    Title = "loc:INFINITE_JUMP",
    Value = false,
    Callback = function(state)
        InfiniteJumpEnabled = state
        HX.SafeNotify({
            Title = "loc:INFINITE_JUMP",
            Content = state and "ON" or "OFF",
            Duration = 1,
            Icon = "toggle-right"
        })
    end
})

LocalPlayerTab:Space({ Columns = 1 })

local function isUsableCFrame(cf)
    if typeof(cf) ~= "CFrame" then return false end
    local p = cf.Position
    if p.X ~= p.X or p.Y ~= p.Y or p.Z ~= p.Z then return false end
    if math.abs(p.X) > 1e6 or math.abs(p.Y) > 1e6 or math.abs(p.Z) > 1e6 then return false end
    if p.Y < -500 then return false end
    return true
end

LocalPlayerTab:Toggle({
    Title = "loc:RESPAWN_SAME_LOCATION",
    Value = true,
    Callback = function(value)
        RespawnOnDeathEnabled = value
        HX.SafeNotify({
            Title = "loc:RESPAWN_SAME_LOCATION",
            Content = value and "ON" or "OFF",
            Duration = 1,
            Icon = value and "toggle-right" or "toggle-left"
        })
    end
})

character = lp.Character or lp.CharacterAdded:Wait()
characterAddedConnection = lp.CharacterAdded:Connect(function(newChar)
    character = newChar
end)
AddCleanupConnection(characterAddedConnection)

RespawnOnDeathEnabled = true
deathPosition = nil
respawnConnections = {}

lastGoodCF = nil
lastGoodSaveConnection = RunService.Heartbeat:Connect(function()
    if not RespawnOnDeathEnabled then return end
    local char = lp.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health <= 0 then return end
    if hum.FloorMaterial == Enum.Material.Air then return end
    if isUsableCFrame(root.CFrame) then
        lastGoodCF = root.CFrame
    end
end)
AddCleanupConnection(lastGoodSaveConnection)

function OnCharacterDeath(character)
    humanoid = character:WaitForChild("Humanoid")
    hrp = character:WaitForChild("HumanoidRootPart")
    
    diedConnection = humanoid.Died:Connect(function()
        if RespawnOnDeathEnabled then

            local atDeath = hrp.CFrame
            deathPosition = (isUsableCFrame(atDeath) and atDeath) or lastGoodCF
            if deathPosition then
                HX.SafeNotify({
                    Title = "loc:RESPAWN_SAVED",
                    Content = "loc:RESPAWN_SAVED_DESC",
                    Duration = 2,
                    Icon = "save"
                })
            end
        end
    end)
    table.insert(respawnConnections, diedConnection)
end

function OnCharacterAdded(character)
    local target = deathPosition or lastGoodCF
    if RespawnOnDeathEnabled and target and isUsableCFrame(target) then
        task.spawn(function()
            local root = character:WaitForChild("HumanoidRootPart", 5)
            if not root then return end
            task.wait()
            character:PivotTo(target)
            root.CFrame = target
        end)
        HX.SafeNotify({
            Title = "loc:RESPAWNED_AT",
            Content = "loc:TELEPORTED_BACK",
            Duration = 2,
            Icon = "refresh-cw"
        })
    end
    deathPosition = nil
    OnCharacterDeath(character)
end

if lp.Character then OnCharacterDeath(lp.Character) end

respawnCharAddedConnection = lp.CharacterAdded:Connect(OnCharacterAdded)
AddCleanupConnection(respawnCharAddedConnection)

InfiniteJumpEnabled = false
UserInputService = game:GetService("UserInputService")

infiniteJumpConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and InfiniteJumpEnabled then
        if input.KeyCode == Enum.KeyCode.Space or input.UserInputType == Enum.UserInputType.Touch then
            character = lp.Character
            if character then
                humanoid = character:FindFirstChild("Humanoid")
                if humanoid then
                    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end
        end
    end
end)
AddCleanupConnection(infiniteJumpConnection)

noclipSteppedConnection = RunService.Stepped:Connect(function()
    if noclipEnabled and character then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end)
AddCleanupConnection(noclipSteppedConnection)

function CleanupLocalPlayer()
    GameFlyRunning = false
    _G.Fly = false
    if lp:GetAttribute("Flying") then
        lp:SetAttribute("Flying", false)
    end
    
    customFlyEnabled = false
    if flyBodyVelocity then
        flyBodyVelocity:Destroy()
        flyBodyVelocity = nil
    end
    
    WalkspeedEnabled = false
    WalkTPEnabled = false
    character = lp.Character
    if character and character:FindFirstChildOfClass("Humanoid") then
        character.Humanoid.WalkSpeed = 16
    end
    
    noclipEnabled = false
    
    RespawnOnDeathEnabled = false
    deathPosition = nil
    
    InfiniteJumpEnabled = false
    
    for _, connection in ipairs(cleanupConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    
    for _, connection in ipairs(respawnConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    
    for _, object in ipairs(cleanupObjects) do
        if object and object.Parent then
            object:Destroy()
        end
    end
    
    cleanupConnections = {}
    cleanupObjects = {}
    respawnConnections = {}
    
    HX.SafeNotify({
        Title = "loc:LOCAL_PLAYER_HEADER",
        Content = "loc:ALL_FEATURES_TURNED_OFF",
        Duration = 2,
        Icon = "power"
    }, true)
end

Window:OnDestroy(function()
    CleanupLocalPlayer()
    if type(HX.VisualsCleanup) == "function" then
        pcall(HX.VisualsCleanup)
    end
end)
HX.loadStage(HX.stageLabel("ESP_TAB"), 0.40)
HX.EnlightenTab = Window:Tab({
    Title = "loc:ENLIGHTEN_TAB", 
    Icon = "sparkle", 
    Locked = false
})

HX.enlightenConnections = {}
function HX.UpdateEnlightenConnection(name, conn)
    if HX.enlightenConnections[name] then
        if type(HX.enlightenConnections[name]) == "table" then
            for _, c in ipairs(HX.enlightenConnections[name]) do
                pcall(function() c:Disconnect() end)
            end
        else
            pcall(function() HX.enlightenConnections[name]:Disconnect() end)
        end
        HX.enlightenConnections[name] = nil
    end
    if conn then
        HX.enlightenConnections[name] = conn
    end
end

function HX.isEnlightenTool(tool)
    if not tool or not tool:IsA("Tool") then return false end
    local name = string.lower(tool.Name)
    return name == "the arkenstone" or name == "enlighten" or string.find(name, "arkenstone") ~= nil
end

function HX.getEnlightenTool()
    if lp.Character then
        for _, v in ipairs(lp.Character:GetChildren()) do
            if HX.isEnlightenTool(v) then
                return v
            end
        end
    end
    local bp = lp:FindFirstChildOfClass("Backpack")
    if bp then
        for _, v in ipairs(bp:GetChildren()) do
            if HX.isEnlightenTool(v) then
                return v
            end
        end
    end
    return nil
end

function HX.getOtherEquippedTool(char)
    if not char then return nil end
    for _, item in ipairs(char:GetChildren()) do
        if item:IsA("Tool") and not HX.isEnlightenTool(item) then
            return item
        end
    end
    return nil
end

function HX.playerHasEnlighten(plr)
    if not plr then return false end
    if plr.Character then
        for _, v in ipairs(plr.Character:GetChildren()) do
            if HX.isEnlightenTool(v) then
                return true
            end
        end
    end
    local bp = plr:FindFirstChildOfClass("Backpack")
    if bp then
        for _, v in ipairs(bp:GetChildren()) do
            if HX.isEnlightenTool(v) then
                return true
            end
        end
    end
    return false
end

function HX.stripPrefix(str)
    return (string.gsub(str or "", "^[;/]+", ""))
end

function HX.getTextChatCommandList()
    local list = {}
    for _, inst in ipairs(HX.TextChatService:GetChildren()) do
        if inst:IsA("TextChatCommand") then
            table.insert(list, inst)
        end
    end
    for _, inst in ipairs(HX.TextChatService:GetDescendants()) do
        if inst:IsA("TextChatCommand") and inst.Parent ~= HX.TextChatService then
            table.insert(list, inst)
        end
    end
    return list
end

function HX.isTextChatCommandMessage(msg, allowPrefixMatch)
    if type(msg) ~= "string" then return false end
    local trimmed = string.match(msg, "^%s*(.-)%s*$") or ""
    if trimmed == "" then return false end

    local lowerMsg = string.lower(trimmed)
    local firstWord = string.match(lowerMsg, "^(%S+)") or lowerMsg
    local prefixChar = string.sub(firstWord, 1, 1)
    local hasCommandPrefix = (prefixChar == "/" or prefixChar == ";")
    local bareWord = HX.stripPrefix(firstWord)

    if bareWord == "" then
        return false
    end

    for _, cmd in ipairs(HX.getTextChatCommandList()) do
        local cName = string.lower(cmd.Name or "")
        local pAlias = string.lower(cmd.PrimaryAlias or "")
        local sAlias = string.lower(cmd.SecondaryAlias or "")

        local cBare = HX.stripPrefix((string.gsub(cName, "^rbx", "")))
        local pBare = HX.stripPrefix(pAlias)
        local sBare = HX.stripPrefix(sAlias)

        if (cName ~= "" and (firstWord == cName or bareWord == cName or bareWord == cBare))
            or (pAlias ~= "" and (firstWord == pAlias or bareWord == pBare))
            or (sAlias ~= "" and (firstWord == sAlias or bareWord == sBare)) then
            return true
        end

        if allowPrefixMatch and hasCommandPrefix and #bareWord >= 1 then
            if (cBare ~= "" and string.sub(cBare, 1, #bareWord) == bareWord)
                or (pBare ~= "" and string.sub(pBare, 1, #bareWord) == bareWord)
                or (sBare ~= "" and string.sub(sBare, 1, #bareWord) == bareWord) then
                return true
            end
        end
    end

    if hasCommandPrefix and #bareWord >= 1 then
        return true
    end

    return false
end

HX.noHoldActive = false
HX.originalArkenGrip = nil
HX.FE_HIDDEN_GRIP = CFrame.new(5000, 0, 0)
HX.commandHoldUntil = 0
HX.arkenEquippedSince = 0
HX.typingCommandInChat = false
HX.switchingTools = false
HX.lastToolSwitchTime = 0
HX.modifiedGuiBorders = {}

function HX.restoreEnlightenUIBorders()
    for obj, propData in pairs(HX.modifiedGuiBorders) do
        pcall(function()
            if obj and obj.Parent then
                obj[propData.prop] = propData.val
            end
        end)
    end
    table.clear(HX.modifiedGuiBorders)
end

function HX.unhighlightEnlightenUI(tool)
    if not tool then return end
    local tName = string.lower(tool.Name)
    local function scanGui(rootGui)
        if not rootGui then return end
        for _, guiObj in ipairs(rootGui:GetDescendants()) do
            if (guiObj:IsA("TextLabel") or guiObj:IsA("TextButton")) and guiObj.Visible then
                local txt = string.lower(guiObj.Text or "")
                if txt == tName or string.find(txt, "arkenstone") or string.find(txt, "enlighten") then
                    local slot = guiObj.Parent
                    if slot then
                        for _, border in ipairs(slot:GetDescendants()) do
                            if border:IsA("UIStroke") and border.Enabled then
                                if not HX.modifiedGuiBorders[border] then
                                    HX.modifiedGuiBorders[border] = { prop = "Enabled", val = true }
                                end
                                border.Enabled = false
                            elseif (border:IsA("ImageLabel") or border:IsA("Frame")) and border.Visible then
                                local bName = string.lower(border.Name)
                                if string.find(bName, "selection") or string.find(bName, "equip") or string.find(bName, "border") or string.find(bName, "outline") then
                                    if not HX.modifiedGuiBorders[border] then
                                        HX.modifiedGuiBorders[border] = { prop = "Visible", val = true }
                                    end
                                    border.Visible = false
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    pcall(function() scanGui(lp:FindFirstChild("PlayerGui")) end)
    pcall(function() scanGui(CoreGui:FindFirstChild("RobloxGui")) end)
end

function HX.applyFEGrip(tool)
    if not tool or not HX.isEnlightenTool(tool) then return end
    if not HX.originalArkenGrip and tool.Grip ~= HX.FE_HIDDEN_GRIP then
        HX.originalArkenGrip = tool.Grip
    end
    tool.CanBeDropped = false
    tool.ManualActivationOnly = true
    if tool.Grip ~= HX.FE_HIDDEN_GRIP then
        tool.Grip = HX.FE_HIDDEN_GRIP
    end
    for _, v in ipairs(tool:GetDescendants()) do
        if v:IsA("BasePart") then
            v.Massless = true
            v.CanCollide = false
            v.CanTouch = false
            v.CanQuery = false
            v.LocalTransparencyModifier = 1
        elseif v:IsA("Decal") or v:IsA("Texture") then
            v.LocalTransparencyModifier = 1
        elseif v:IsA("ParticleEmitter") or v:IsA("PointLight") or v:IsA("SurfaceLight") or v:IsA("SpotLight") or v:IsA("Beam") or v:IsA("Trail") or v:IsA("Sparkles") or v:IsA("Fire") or v:IsA("Smoke") then
            v.Enabled = false
        end
    end
end

function HX.restoreFEGrip(tool)
    if not tool or not HX.isEnlightenTool(tool) then return end
    tool.CanBeDropped = true
    tool.ManualActivationOnly = false
    if HX.originalArkenGrip then
        tool.Grip = HX.originalArkenGrip
    end
    for _, v in ipairs(tool:GetDescendants()) do
        if v:IsA("BasePart") or v:IsA("Decal") or v:IsA("Texture") then
            v.LocalTransparencyModifier = 0
        elseif v:IsA("ParticleEmitter") or v:IsA("PointLight") or v:IsA("SurfaceLight") or v:IsA("SpotLight") or v:IsA("Beam") or v:IsA("Trail") or v:IsA("Sparkles") or v:IsA("Fire") or v:IsA("Smoke") then
            v.Enabled = true
        end
    end
end

function HX.isDefaultToolHoldTrack(track)
    if not track then return false end
    local tname = string.lower(tostring(track.Name))
    local id = track.Animation and string.lower(tostring(track.Animation.AnimationId)) or ""
    return tname == "toolnone" or tname == "toolnoneanim" or string.find(id, "182393478") ~= nil or string.find(id, "507768375") ~= nil
end

function HX.suppressArkenHoldAnim(char)
    if not char or HX.getOtherEquippedTool(char) ~= nil then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator") or hum
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        if HX.isDefaultToolHoldTrack(track) then
            pcall(function()
                track:AdjustWeight(0.0001, 0)
            end)
        end
    end
end

function HX.playSmoothToolEquipAnim(char, otherTool)
    if not char or not otherTool then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator") or hum

    local foundHoldTrack = false
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        if HX.isDefaultToolHoldTrack(track) then
            foundHoldTrack = true
            pcall(function()
                track:Stop(0)
                track:Play(0.15, 1, 1)
            end)
        end
    end

    if not foundHoldTrack and otherTool.RequiresHandle ~= false then
        pcall(function()
            local animate = char:FindFirstChild("Animate")
            local toolNone = animate and animate:FindFirstChild("toolnone")
            local anim = toolNone and toolNone:FindFirstChildOfClass("Animation")
            if anim then
                local tr = animator:LoadAnimation(anim)
                tr.Priority = Enum.AnimationPriority.Idle
                tr:Play(0.15, 1, 1)
            end
        end)
    end
end

function HX.equipEnlightenWithCurrentTool(duration)
    local holdTime = duration or 1.0
    local char = lp.Character
    local bp = lp:FindFirstChildOfClass("Backpack")
    local arken = HX.getEnlightenTool()
    if not char or not bp or not arken then return false end

    local alreadyReadyOnServer = (arken.Parent == char) and ((os.clock() - HX.arkenEquippedSince) >= 0.08)
    HX.commandHoldUntil = math.max(HX.commandHoldUntil, os.clock() + holdTime)

    HX.switchingTools = true
    if HX.noHoldActive then
        HX.applyFEGrip(arken)
    end
    if arken.Parent ~= char then
        arken.Parent = char
        HX.arkenEquippedSince = os.clock()
    end
    if HX.noHoldActive then
        HX.unhighlightEnlightenUI(arken)
        HX.suppressArkenHoldAnim(char)
    end
    HX.switchingTools = false

    task.delay(holdTime, function()
        if not HX.typingCommandInChat and os.clock() >= HX.commandHoldUntil - 0.02 then
            local c = lp.Character
            local b = lp:FindFirstChildOfClass("Backpack")
            local currentArken = HX.getEnlightenTool()
            if c and b and currentArken and currentArken.Parent == c then
                local otherTool = HX.getOtherEquippedTool(c)
                if otherTool or not HX.noHoldActive then
                    HX.switchingTools = true
                    currentArken.Parent = b
                    HX.switchingTools = false
                    HX.restoreEnlightenUIBorders()
                end
            end
        end
    end)

    return not alreadyReadyOnServer
end

function HX.rawSendChat(msg)

    local sent = false
    pcall(function()
        if HX.TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            local channels = HX.TextChatService:FindFirstChild("TextChannels")
            local rbxGeneral = channels and (channels:FindFirstChild("RBXGeneral") or channels:FindFirstChild("General") or channels:GetChildren()[1])
            if rbxGeneral then
                rbxGeneral:SendAsync(msg)
                sent = true
            end
        end
    end)
    if sent then return true end

    pcall(function()
        local chatEvents = HX.ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
        local sayMsg = chatEvents and chatEvents:FindFirstChild("SayMessageRequest")
        if sayMsg then
            sayMsg:FireServer(msg, "All")
            sent = true
        end
    end)
    if sent then return true end

    pcall(function()
        Players:Chat(msg)
        sent = true
    end)
    return sent
end

function HX.sendChatCommand(msg)
    if HX.isTextChatCommandMessage(msg, false) then
        local neededEquip = HX.equipEnlightenWithCurrentTool(1.0)
        if neededEquip then
            task.wait(0.1)
        end
    end
    HX.rawSendChat(msg)
end

HX.selectedRigType = "Auto"

HX.EnlightenTab:Section({
    Title = "loc:SAVE_ENLIGHTEN_SECTION", 
    Icon = "shield-alert",
})

HX.EnlightenTab:Space({ Columns = 0.5 })

local enlightenSavePill = HX.EnlightenTab:VStack({})

enlightenSavePill:Dropdown({
    Title = "loc:AUTO_SAVE_RIG_TYPE_TITLE",
    Multi = false,
    Value = "Auto",
    Values = {
        {
            Title = "loc:AUTO_RIG_OPTION",
            Desc = "loc:AUTO_RIG_OPTION_DESC",
            Icon = "cpu"
        },
        {
            Type = "Divider",
        },
        {
            Title = "R6",
            Desc = "loc:R6_OPTION_DESC",
            Icon = "user"
        },
        {
            Title = "R15",
            Desc = "loc:R15_OPTION_DESC",
            Icon = "user-check"
        }
    },
    Callback = function(value)
        local newVal
        if type(value) == "table" and value.Title then
            newVal = value.Title
        elseif type(value) == "string" then
            newVal = value
        else
            return
        end

        local changed = (newVal ~= HX.selectedRigType)
        HX.selectedRigType = newVal
        if not changed then return end

        local content
        if HX.selectedRigType == "Auto" then
            content = "Auto Save will now use your current rig type"
        else
            content = "Auto Save will now use ;" .. string.lower(tostring(HX.selectedRigType)) .. " me"
        end

        WindUI:Notify({
            Title = "loc:RIG_SAVE_SET",
            Content = content,
            Icon = "refresh-cw",
            Duration = 2
        })
    end
})

enlightenSavePill:Toggle({
    Title = "loc:AUTO_SAVE_ENLIGHTEN_TITLE",
    Value = false,
    Callback = function(value)
        HX.autoSaveActive = value
        WindUI:Notify({
            Title = "loc:AUTO_SAVE_ENLIGHTEN_TITLE",
            Content = value and "loc:AUTOSAVE_ARMED" or "loc:AUTOSAVE_DISABLED",
            Icon = value and "sparkles" or "x-circle",
            Duration = 3
        })
        if value then
            local conns = {}
            local savedOnCurrentLife = false
            local lifeConns = nil

            local function detectRig(char)
                if not char then return "r6" end
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    if hum.RigType == Enum.HumanoidRigType.R15 then
                        return "r15"
                    end
                    return "r6"
                end
                if char:FindFirstChild("UpperTorso") or char:FindFirstChild("LowerTorso") then
                    return "r15"
                end
                return "r6"
            end

            local function triggerSave(char, capturedRig)
                if not HX.autoSaveActive then return end
                if savedOnCurrentLife then return end

                local tool = HX.getEnlightenTool()
                if not tool then

                    return
                end
                savedOnCurrentLife = true

                if char and tool.Parent ~= char then
                    pcall(function()
                        tool.Parent = char
                    end)
                end

                local rig
                if HX.selectedRigType == "Auto" then
                    rig = capturedRig or detectRig(char)
                else
                    rig = string.lower(tostring(HX.selectedRigType or "R6"))
                end

                HX.rawSendChat(";" .. rig .. " me")
            end

            local function hookCharacter(char)
                if not char then return end
                savedOnCurrentLife = false

                local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
                if not hum then return end

                local capturedRig = (hum.RigType == Enum.HumanoidRigType.R15) and "r15" or "r6"

                
                if lifeConns then
                    for _, connection in ipairs(lifeConns) do
                        pcall(function() connection:Disconnect() end)
                    end
                end
                lifeConns = {}

                table.insert(lifeConns, hum.HealthChanged:Connect(function(hp)
                    if hp <= 0 then
                        triggerSave(char, capturedRig)
                    end
                end))

                table.insert(lifeConns, hum.StateChanged:Connect(function(_, newState)
                    if newState == Enum.HumanoidStateType.Dead then
                        triggerSave(char, capturedRig)
                    end
                end))

                table.insert(lifeConns, hum.Died:Connect(function()
                    triggerSave(char, capturedRig)
                end))
            end

            if lp.Character then
                hookCharacter(lp.Character)
            end
            table.insert(conns, lp.CharacterAdded:Connect(hookCharacter))
            HX.UpdateEnlightenConnection("AutoSave", conns)
        else
            HX.UpdateEnlightenConnection("AutoSave", nil)
        end
    end
})

enlightenSavePill:Toggle({
    Title = "loc:AUTO_PICKUP_TITLE",
    Value = false,
    Callback = function(value)
        WindUI:Notify({
            Title = "loc:AUTO_PICKUP_TITLE",
            Content = value and "loc:AUTOPICKUP_ON" or "loc:AUTOPICKUP_OFF",
            Icon = value and "pickaxe" or "x-circle",
            Duration = 3
        })
        if value then
            local conns = {}
            local function grabArkenstone(tool)
                if not HX.isEnlightenTool(tool) then return end
                local char = lp.Character
                if not char then return end
                local hum = char:FindFirstChildOfClass("Humanoid")
                local root = char:FindFirstChild("HumanoidRootPart")
                local handle = tool:FindFirstChild("Handle")
                if hum and hum.Health > 0 and handle then
                    if HX.firetouchinterest and root then
                        pcall(function()
                            HX.firetouchinterest(root, handle, 0)
                            HX.firetouchinterest(root, handle, 1)
                        end)
                    end
                    pcall(function()
                        hum:EquipTool(tool)
                    end)
                end
            end

            table.insert(conns, HX.Workspace.ChildAdded:Connect(function(child)
                if HX.isEnlightenTool(child) then
                    task.wait()
                    grabArkenstone(child)
                end
            end))

            table.insert(conns, RunService.Stepped:Connect(function()
                local char = lp.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        for _, tool in ipairs(HX.Workspace:GetChildren()) do
                            if HX.isEnlightenTool(tool) and tool:FindFirstChild("Handle") then
                                grabArkenstone(tool)
                            end
                        end
                    end
                end
            end))
            HX.UpdateEnlightenConnection("AutoPickup", conns)
        else
            HX.UpdateEnlightenConnection("AutoPickup", nil)
        end
    end
})

HX.EnlightenTab:Section({
    Title = "loc:ENLIGHTEN_UTILITIES_SECTION", 
    Icon = "wand-sparkles",
})

HX.EnlightenTab:Space({ Columns = 0.5 })

local enlightenUtilPill = HX.EnlightenTab:VStack({})

enlightenUtilPill:Toggle({
    Title = "loc:USE_WITHOUT_HOLDING_TITLE",
    Value = false,
    Callback = function(value)
        HX.noHoldActive = value
        WindUI:Notify({
            Title = "loc:USE_WITHOUT_HOLDING_TITLE",
            Content = value and "loc:NOHOLD_ON" or "loc:NOHOLD_OFF",
            Icon = value and "wand-sparkles" or "x-circle",
            Duration = 3
        })
        if value then
            local conns = {}
            local hookedTextBoxes = {}
            local hookedCommands = {}
            local lastTypedCommandText = ""
            local resendingCommand = false

            local function equipArkenFE(arken, char, bp)
                if not arken or not char then return end
                HX.switchingTools = true
                HX.applyFEGrip(arken)
                if arken.Parent == char and bp then
                    arken.Parent = bp
                end
                arken.Parent = char
                HX.arkenEquippedSince = os.clock()
                HX.suppressArkenHoldAnim(char)
                HX.unhighlightEnlightenUI(arken)
                HX.switchingTools = false
            end

            local function hookChatBox(tb)
                if not tb or not tb:IsA("TextBox") or hookedTextBoxes[tb] then return end
                hookedTextBoxes[tb] = true

                table.insert(conns, tb:GetPropertyChangedSignal("Text"):Connect(function()
                    if not tb:IsFocused() then return end
                    local txt = tb.Text or ""
                    if HX.isTextChatCommandMessage(txt, true) then
                        HX.typingCommandInChat = true
                        lastTypedCommandText = txt
                        local char = lp.Character
                        local arken = HX.getEnlightenTool()
                        if char and arken and arken.Parent ~= char then
                            HX.switchingTools = true
                            HX.applyFEGrip(arken)
                            arken.Parent = char
                            HX.arkenEquippedSince = os.clock()
                            HX.unhighlightEnlightenUI(arken)
                            HX.switchingTools = false
                        end
                    else
                        HX.typingCommandInChat = false
                    end
                end))

                table.insert(conns, tb.FocusLost:Connect(function(enterPressed)
                    local msg = (tb.Text ~= "" and tb.Text) or lastTypedCommandText
                    HX.typingCommandInChat = false
                    lastTypedCommandText = ""
                    if enterPressed and HX.isTextChatCommandMessage(msg, true) then
                        HX.equipEnlightenWithCurrentTool(1.0)
                    end
                end))
            end

            table.insert(conns, UserInputService.TextBoxFocused:Connect(function(tb)
                hookChatBox(tb)
            end))

            local initialTb = UserInputService:GetFocusedTextBox()
            if initialTb then
                hookChatBox(initialTb)
            end

            local function hookTextChatCommand(cmd)
                if not cmd or not cmd:IsA("TextChatCommand") or hookedCommands[cmd] then return end
                hookedCommands[cmd] = true

                table.insert(conns, cmd.Triggered:Connect(function(_, unfilteredText)
                    if resendingCommand then return end
                    local neededEquip = HX.equipEnlightenWithCurrentTool(1.0)
                    if neededEquip then
                        local raw = (type(unfilteredText) == "string" and unfilteredText ~= "") and unfilteredText or (";" .. cmd.Name)
                        local resendStr = string.gsub(raw, "^/", ";")
                        resendingCommand = true
                        task.delay(0.1, function()
                            HX.rawSendChat(resendStr)
                            task.wait(0.05)
                            resendingCommand = false
                        end)
                    end
                end))
            end

            for _, cmd in ipairs(HX.getTextChatCommandList()) do
                hookTextChatCommand(cmd)
            end
            table.insert(conns, HX.TextChatService.ChildAdded:Connect(function(inst)
                if inst:IsA("TextChatCommand") then
                    hookTextChatCommand(inst)
                end
            end))
            table.insert(conns, HX.TextChatService.DescendantAdded:Connect(function(inst)
                if inst:IsA("TextChatCommand") then
                    hookTextChatCommand(inst)
                end
            end))

            pcall(function()
                table.insert(conns, HX.TextChatService.SendingMessage:Connect(function(textChatMessage)
                    if resendingCommand then return end
                    local txt = textChatMessage and textChatMessage.Text or ""
                    if HX.isTextChatCommandMessage(txt, false) then
                        local neededEquip = HX.equipEnlightenWithCurrentTool(1.0)
                        if neededEquip then
                            local resendStr = string.gsub(txt, "^/", ";")
                            resendingCommand = true
                            task.delay(0.1, function()
                                HX.rawSendChat(resendStr)
                                task.wait(0.05)
                                resendingCommand = false
                            end)
                        end
                    end
                end))
            end)

            local function hookCharTools(char)
                if not char then return end

                local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
                if hum then
                    local animator = hum:FindFirstChildOfClass("Animator") or hum
                    table.insert(conns, animator.AnimationPlayed:Connect(function(track)
                        if HX.isDefaultToolHoldTrack(track) then
                            if HX.getOtherEquippedTool(char) == nil then
                                local arken = HX.getEnlightenTool()
                                if arken and arken.Parent == char then
                                    pcall(function()
                                        track:AdjustWeight(0.0001, 0)
                                    end)
                                end
                            end
                        end
                    end))
                end

                table.insert(conns, char.ChildAdded:Connect(function(child)
                    if HX.switchingTools then return end
                    if child:IsA("Tool") then
                        if not HX.isEnlightenTool(child) then
                            HX.lastToolSwitchTime = os.clock()
                            local arken = HX.getEnlightenTool()
                            local bp = lp:FindFirstChildOfClass("Backpack")
                            if arken and bp and arken.Parent == char and not HX.typingCommandInChat and os.clock() >= HX.commandHoldUntil then
                                HX.switchingTools = true
                                arken.Parent = bp
                                HX.switchingTools = false
                                HX.restoreEnlightenUIBorders()
                            end
                            task.defer(function()
                                if child.Parent == char then
                                    HX.playSmoothToolEquipAnim(char, child)
                                end
                            end)
                        else
                            HX.arkenEquippedSince = os.clock()
                            HX.applyFEGrip(child)
                            if HX.getOtherEquippedTool(char) == nil then
                                HX.suppressArkenHoldAnim(char)
                            end
                        end
                    end
                end))

                table.insert(conns, char.ChildRemoved:Connect(function(child)
                    if HX.switchingTools then return end
                    if child:IsA("Tool") and not HX.isEnlightenTool(child) then
                        HX.lastToolSwitchTime = os.clock()
                    end
                end))

                local arken = HX.getEnlightenTool()
                local bp = lp:FindFirstChildOfClass("Backpack")
                if arken and HX.getOtherEquippedTool(char) == nil then
                    equipArkenFE(arken, char, bp)
                end
            end

            if lp.Character then
                hookCharTools(lp.Character)
            end
            table.insert(conns, lp.CharacterAdded:Connect(hookCharTools))

            table.insert(conns, RunService.Stepped:Connect(function()
                local char = lp.Character
                if not char then return end
                local hum = char:FindFirstChildOfClass("Humanoid")
                if not hum or hum.Health <= 0 then return end

                local focusedTb = UserInputService:GetFocusedTextBox()
                if focusedTb then
                    hookChatBox(focusedTb)
                    local txt = focusedTb.Text or ""
                    if HX.isTextChatCommandMessage(txt, true) then
                        HX.typingCommandInChat = true
                        lastTypedCommandText = txt
                    else
                        HX.typingCommandInChat = false
                    end
                else
                    HX.typingCommandInChat = false
                end

                local arken = HX.getEnlightenTool()
                if not arken then return end

                HX.applyFEGrip(arken)

                local otherTool = HX.getOtherEquippedTool(char)
                local shouldEquipWithTool = HX.typingCommandInChat or (os.clock() < HX.commandHoldUntil)

                if otherTool then
                    if shouldEquipWithTool then
                        if arken.Parent ~= char then
                            HX.switchingTools = true
                            arken.Parent = char
                            HX.arkenEquippedSince = os.clock()
                            HX.switchingTools = false
                        end
                        HX.unhighlightEnlightenUI(arken)
                    else
                        local bp = lp:FindFirstChildOfClass("Backpack")
                        if bp and arken.Parent == char then
                            HX.switchingTools = true
                            arken.Parent = bp
                            HX.switchingTools = false
                            HX.restoreEnlightenUIBorders()
                        end
                    end
                else
                    if (os.clock() - HX.lastToolSwitchTime) < 0.08 then
                        return
                    end
                    if arken.Parent ~= char then
                        local bp = lp:FindFirstChildOfClass("Backpack")
                        equipArkenFE(arken, char, bp)
                    end
                    HX.unhighlightEnlightenUI(arken)
                    HX.suppressArkenHoldAnim(char)
                end
            end))

            HX.UpdateEnlightenConnection("NoHoldEnlighten", conns)
        else
            HX.typingCommandInChat = false
            HX.commandHoldUntil = 0
            HX.UpdateEnlightenConnection("NoHoldEnlighten", nil)
            HX.restoreEnlightenUIBorders()

            local tool = HX.getEnlightenTool()
            if tool then
                HX.restoreFEGrip(tool)
                local bp = lp:FindFirstChildOfClass("Backpack")
                local char = lp.Character
                if bp and char and tool.Parent == char then
                    tool.Parent = bp
                end
            end
        end
    end
})

enlightenUtilPill:Toggle({
    Title = "loc:NOTIFY_HOLDER_TITLE",
    Value = false,
    Callback = function(value)
        WindUI:Notify({
            Title = "loc:ENLIGHTEN_DETECTOR",
            Content = value and "loc:DETECTOR_ON" or "loc:DETECTOR_OFF",
            Icon = value and "bell" or "x-circle",
            Duration = 3
        })
        if value then
            local conns = {}
            local trackedHolders = {}

            table.insert(conns, RunService.Heartbeat:Connect(function()
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= lp then
                        local hasIt = HX.playerHasEnlighten(plr)
                        if hasIt and not trackedHolders[plr] then
                            trackedHolders[plr] = true
                            WindUI:Notify({
                                Title = "loc:ENLIGHTEN_DETECTED",
                                Content = string.format(HX.translate("GOT_ARKENSTONE"), tostring(plr.DisplayName)),
                                Icon = "sparkle",
                                Duration = 4
                            })
                        elseif not hasIt and trackedHolders[plr] then
                            trackedHolders[plr] = nil
                        end
                    end
                end
            end))

            table.insert(conns, Players.PlayerRemoving:Connect(function(plr)
                trackedHolders[plr] = nil
            end))

            HX.UpdateEnlightenConnection("NotifyHolder", conns)
        else
            HX.UpdateEnlightenConnection("NotifyHolder", nil)
        end
    end
})

HX.selectedClearTargets = { ["Everyone"] = true }
HX.everyoneWasSelected = true
HX.updatingClearDropdown = false
HX.ClearInvTargetDropdown = nil

function HX.buildClearInvDropdownValues()
    local values = {
        {
            Title = "loc:EVERYONE",
            Desc = "loc:ARKENSTONE_TARGET_DESC",
            Icon = "users"
        },
        {
            Type = "Divider"
        }
    }
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp then
            table.insert(values, {
                Title = plr.Name,
                Desc = plr.DisplayName .. " (@" .. plr.Name .. ")",
                Icon = "user"
            })
        end
    end
    return values
end

function HX.setDropdownUIValue(dropdownObj, list)
    if not dropdownObj then return end
    HX.updatingClearDropdown = true
    pcall(function()
        if dropdownObj.Select then
            dropdownObj:Select(list)
        elseif dropdownObj.SetValue then
            dropdownObj:SetValue(list)
        elseif dropdownObj.Set then
            dropdownObj:Set(list)
        end
    end)
    HX.updatingClearDropdown = false
end

HX.ClearInvTargetDropdown = HX.EnlightenTab:Dropdown({
    Title = "loc:AUTO_CLEARINV_TARGETS_TITLE",
    Desc = "loc:AUTO_CLEARINV_TARGETS_DESC",
    Multi = true,
    Value = { "Everyone" },
    Values = HX.buildClearInvDropdownValues(),
    Callback = function(value)
        if HX.updatingClearDropdown then return end

        local hasEveryone = false
        local chosenPlayers = {}

        if type(value) == "table" then
            for k, v in pairs(value) do
                local title = nil
                if type(v) == "table" and v.Title then
                    title = v.Title
                elseif type(v) == "string" then
                    title = v
                elseif type(k) == "string" and v == true then
                    title = k
                end
                if title then
                    if title == "Everyone" then
                        hasEveryone = true
                    else
                        table.insert(chosenPlayers, title)
                    end
                end
            end
        elseif type(value) == "string" then
            if value == "Everyone" then
                hasEveryone = true
            else
                table.insert(chosenPlayers, value)
            end
        end

        local finalSelection = {}
        local newTargetMap = {}

        if hasEveryone and #chosenPlayers > 0 then
            if HX.everyoneWasSelected then
                HX.everyoneWasSelected = false
                for _, pName in ipairs(chosenPlayers) do
                    newTargetMap[pName] = true
                    table.insert(finalSelection, pName)
                end
                HX.setDropdownUIValue(HX.ClearInvTargetDropdown, finalSelection)
            else
                HX.everyoneWasSelected = true
                newTargetMap["Everyone"] = true
                finalSelection = { "Everyone" }
                HX.setDropdownUIValue(HX.ClearInvTargetDropdown, finalSelection)
            end
        elseif hasEveryone then
            HX.everyoneWasSelected = true
            newTargetMap["Everyone"] = true
        elseif #chosenPlayers > 0 then
            HX.everyoneWasSelected = false
            for _, pName in ipairs(chosenPlayers) do
                newTargetMap[pName] = true
            end
        else
            HX.everyoneWasSelected = true
            newTargetMap["Everyone"] = true
            HX.setDropdownUIValue(HX.ClearInvTargetDropdown, { "Everyone" })
        end

        HX.selectedClearTargets = newTargetMap
    end
})

function HX.refreshClearInvDropdown()
    if not HX.ClearInvTargetDropdown then return end
    local newVals = HX.buildClearInvDropdownValues()
    HX.updatingClearDropdown = true
    pcall(function()
        if HX.ClearInvTargetDropdown.Refresh then
            HX.ClearInvTargetDropdown:Refresh(newVals)
        elseif HX.ClearInvTargetDropdown.SetValues then
            HX.ClearInvTargetDropdown:SetValues(newVals)
        end
    end)
    HX.updatingClearDropdown = false
end

Players.PlayerAdded:Connect(function()
    task.wait(0.2)
    HX.refreshClearInvDropdown()
end)

Players.PlayerRemoving:Connect(function(plr)
    HX.selectedClearTargets[plr.Name] = nil
    task.wait(0.1)
    HX.refreshClearInvDropdown()
end)

function HX.isPlayerTargetedForClear(plr)
    if not plr or plr == lp then return false end
    if HX.selectedClearTargets["Everyone"] then
        return true
    end
    return HX.selectedClearTargets[plr.Name] == true or HX.selectedClearTargets[plr.DisplayName] == true
end

enlightenUtilPill:Toggle({
    Title = "loc:AUTO_CLEARINV_TITLE",
    Value = false,
    Callback = function(value)
        WindUI:Notify({
            Title = "loc:AUTO_CLEARINV_TITLE",
            Content = value and "loc:CLEARINV_ON" or "loc:CLEARINV_OFF",
            Icon = value and "trash-2" or "x-circle",
            Duration = 3
        })
        if value then
            local conns = {}
            local clearCooldowns = {}

            local function clearPlayerEnlighten(plr)
                if not HX.isPlayerTargetedForClear(plr) then return end
                local now = os.clock()
                if clearCooldowns[plr] and (now - clearCooldowns[plr]) < 1.5 then
                    return
                end
                clearCooldowns[plr] = now

                task.spawn(function()
                    HX.sendChatCommand(";clearinv " .. tostring(plr.Name))
                end)
            end

            table.insert(conns, RunService.Heartbeat:Connect(function()
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= lp then
                        if HX.playerHasEnlighten(plr) and HX.isPlayerTargetedForClear(plr) then
                            clearPlayerEnlighten(plr)
                        else
                            clearCooldowns[plr] = nil
                        end
                    end
                end
            end))

            table.insert(conns, Players.PlayerRemoving:Connect(function(plr)
                clearCooldowns[plr] = nil
            end))

            HX.UpdateEnlightenConnection("AutoClearInv", conns)
        else
            HX.UpdateEnlightenConnection("AutoClearInv", nil)
        end
    end
})
HX.loadStage(HX.stageLabel("TOOLS_TAB"), 0.47)
HX.ToolsTab = Window:Tab({Title = "loc:TOOLS_TAB", Icon = "wrench", Locked = false})
HX.ToolsTab:Section({
    Title = "loc:TOOLS_TAB", 
    Icon = "tool-case",
    Desc = "loc:SAVE_TOOLS_DESC"
})

HX.ToolsTab:Section({Title = "loc:TOOL_SELECTOR_SECTION", Icon = "aperture"})

HX.selectedTools = {}
local localplr = game.Players.LocalPlayer

function HX.getPlayerTools()
    local tools = {}
    local backpack = localplr:FindFirstChild("Backpack")
    local character = localplr.Character
    
    if backpack then
        for _, tool in pairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                table.insert(tools, tool.Name)
            end
        end
    end
    
    if character then
        for _, tool in pairs(character:GetChildren()) do
            if tool:IsA("Tool") then
                table.insert(tools, tool.Name)
            end
        end
    end
    
    if #tools == 0 then
        table.insert(tools, "None")
    end
    
    return tools
end

HX.toolDropdown = HX.ToolsTab:Dropdown({
    Title = "loc:SELECT_TOOLS",
    Desc = "loc:SELECT_TOOLS_DESC",
    Values = HX.getPlayerTools(),
    Value = {},
    Multi = true,
    AllowNone = true,
    Callback = function(option)
        HX.selectedTools = option
        if #option > 0 then
            HX.SafeNotify({
                Title = "loc:TOOLS_SELECTED",
                Content = string.format(HX.translate("TOOLS_COUNT"), #option),
                Duration = 2,
                Icon = "tool"
            })
        end
    end
})

HX.ToolsTab:Button({
    Title = "loc:REFRESH_TOOL_LIST",
    Icon = "refresh-cw",
    Callback = function()
        HX.toolDropdown.Values = HX.getPlayerTools()
        HX.toolDropdown:Refresh(HX.toolDropdown.Values)
        HX.SafeNotify({
            Title = "loc:TOOL_LIST_REFRESHED",
            Content = "loc:TOOL_INVENTORY_UPDATED",
            Duration = 2,
            Icon = "check"
        })
    end
})

HX.ToolsTab:Button({
    Title = "loc:EQUIP_SELECTED_TOOLS",
    Icon = "check",
    Callback = function()
        if #HX.selectedTools == 0 then
            HX.SafeNotify({
                Title = "loc:NO_TOOLS_SELECTED",
                Content = "loc:PLEASE_SELECT_TOOLS_FIRST",
                Duration = 3,
                Icon = "alert-circle"
            })
            return
        end
        
        local equipped = 0
        for _, toolName in pairs(HX.selectedTools) do
            local backpack = localplr:FindFirstChild("Backpack")
            if backpack then
                for _, tool in pairs(backpack:GetChildren()) do
                    if tool:IsA("Tool") and tool.Name == toolName and localplr.Character then
                        tool.Parent = localplr.Character
                        equipped = equipped + 1
                        break
                    end
                end
            end
        end
        
        HX.SafeNotify({
            Title = "loc:TOOLS_EQUIPPED",
            Content = string.format(HX.translate("TOOLS_EQUIPPED_COUNT"), equipped),
            Duration = 3,
            Icon = "check"
        })
    end
})

HX.ToolsTab:Section({Title = "loc:TOOLS_ABUSE_SECTION", Icon = "zap"})

HX.ToolsTab:Button({
    Title = "loc:EQUIP_ALL_TOOLS",
    Icon = "package",
    Callback = function()
        local backpack = localplr:FindFirstChild("Backpack")
        local character = localplr.Character
        
        if not character then
            HX.SafeNotify({
                Title = "loc:ERROR",
                Content = "loc:CHARACTER_NOT_FOUND",
                Duration = 3,
                Icon = "alert-circle"
            })
            return
        end
        
        local equipped = 0
        
        if backpack then
            for _, tool in pairs(backpack:GetChildren()) do
                if tool:IsA("Tool") then
                    tool.Parent = character
                    equipped = equipped + 1
                end
            end
        end
        
        HX.SafeNotify({
            Title = "loc:ALL_TOOLS_EQUIPPED",
            Content = string.format(HX.translate("TOOLS_EQUIPPED_COUNT"), equipped),
            Duration = 3,
            Icon = "check"
        })
    end
})

HX.ToolsTab:Button({
    Title = "loc:DROP_ALL_TOOLS",
    Icon = "package-minus",
    Callback = function()
        local character = localplr.Character
        
        if not character then
            HX.SafeNotify({
                Title = "loc:ERROR",
                Content = "loc:CHARACTER_NOT_FOUND",
                Duration = 3,
                Icon = "alert-circle"
            })
            return
        end
        
        local backpack = localplr:FindFirstChild("Backpack")
        local dropped = 0
        
        if backpack then
            for _, tool in pairs(backpack:GetChildren()) do
                if tool:IsA("Tool") then
                    tool.Parent = character
                end
            end
        end
        
        task.wait(0.1)
        
        for _, tool in pairs(character:GetChildren()) do
            if tool:IsA("Tool") then
                tool.Parent = workspace
                dropped = dropped + 1
            end
        end
        
        HX.SafeNotify({
            Title = "loc:TOOLS_DROPPED",
            Content = string.format(HX.translate("TOOLS_DROPPED_COUNT"), dropped),
            Duration = 3,
            Icon = "check"
        })
    end
})

HX.spamEquippedEnabled = false
HX.spamming = false
local spamConnection

HX.ToolsTab:Toggle({
    Title = "loc:SPAM_EQUIPPED_TOOL",
    Value = false,
    Callback = function(state)
        HX.spamEquippedEnabled = state
        
        if state then
            HX.spamming = true
            HX.SafeNotify({
                Title = "loc:SPAM_EQUIPPED_TOOL",
                Content = "loc:SPAM_ON",
                Duration = 2,
                Icon = "zap"
            })
            
            spamConnection = game:GetService("RunService").Heartbeat:Connect(function()
                if HX.spamming and localplr.Character then
                    for _, tool in pairs(localplr.Character:GetChildren()) do
                        if tool:IsA("Tool") then
                            tool:Activate()
                        end
                    end
                end
            end)
        else
            HX.spamming = false
            if spamConnection then
                spamConnection:Disconnect()
            end
            HX.SafeNotify({
                Title = "loc:SPAM_EQUIPPED_TOOL",
                Content = "loc:SPAM_OFF",
                Duration = 2,
                Icon = "zap"
            })
        end
    end
})

HX.ToolsTab:Section({Title = "loc:TOOLS_SAVE_SECTION", Icon = "save"})

HX.autoPickupEnabled = false
HX.autoDropEnabled = false
local pickupConnection
local dropConnection

HX.ToolsTab:Toggle({
    Title = "loc:AUTO_PICKUP_DROPPED_TOOLS",
    Value = false,
    Callback = function(state)
        HX.autoPickupEnabled = state
        
        if pickupConnection then
            pickupConnection:Disconnect()
            pickupConnection = nil
        end
        
        if state then
            HX.SafeNotify({
                Title = "loc:AUTO_PICKUP_TOOLS",
                Content = "loc:AUTO_COLLECTING_ON",
                Duration = 2,
                Icon = "pickaxe"
            })
            
            pickupConnection = game:GetService("RunService").Heartbeat:Connect(function()
                if HX.autoPickupEnabled and localplr.Character and localplr.Character:FindFirstChild("Humanoid") and localplr.Character.Humanoid.Health > 0 then
                    for _, tool in pairs(workspace:GetChildren()) do
                        if tool:IsA("Tool") and tool:FindFirstChild("Handle") then
                            localplr.Character.Humanoid:EquipTool(tool)
                        end
                    end
                end
            end)
        else
            HX.SafeNotify({
                Title = "loc:AUTO_PICKUP_TOOLS",
                Content = "loc:AUTO_COLLECTING_OFF",
                Duration = 2,
                Icon = "pickaxe"
            })
        end
    end
})

HX.ToolsTab:Toggle({
    Title = "loc:AUTO_DROP_ALL_TOOLS_IF_DIED",
    Value = false,
    Callback = function(state)
        HX.autoDropEnabled = state
        
        if dropConnection then
            dropConnection:Disconnect()
            dropConnection = nil
        end
        
        if state then
            HX.SafeNotify({
                Title = "loc:AUTO_DROP_ON_DEATH",
                Content = "loc:AUTO_DROP_ON",
                Duration = 2,
                Icon = "skull"
            })
            
            dropConnection = game:GetService("RunService").Heartbeat:Connect(function()
                if HX.autoDropEnabled and localplr.Character and localplr.Character:FindFirstChild("Humanoid") then
                    local humanoid = localplr.Character.Humanoid
                    if humanoid.Health <= 0 then
                        local backpack = localplr:FindFirstChild("Backpack")
                        local character = localplr.Character
                        
                        if backpack and character then
                            for _, tool in pairs(backpack:GetChildren()) do
                                if tool:IsA("Tool") then
                                    tool.Parent = character
                                end
                            end
                            
                            task.wait(0.1)
                            
                            for _, tool in pairs(character:GetChildren()) do
                                if tool:IsA("Tool") then
                                    tool.Parent = workspace
                                end
                            end
                        end
                    end
                end
            end)
        else
            HX.SafeNotify({
                Title = "loc:AUTO_DROP_ON_DEATH",
                Content = "loc:AUTO_DROP_OFF",
                Duration = 2,
                Icon = "skull"
            })
        end
    end
})

function HX.CleanupTools()
    HX.spamEquippedEnabled = false
    HX.spamming = false
    HX.autoPickupEnabled = false
    HX.autoDropEnabled = false
    
    if spamConnection then
        spamConnection:Disconnect()
    end
    
    if pickupConnection then
        pickupConnection:Disconnect()
    end
    
    if dropConnection then
        dropConnection:Disconnect()
    end
    
    HX.selectedTools = {}
    HX.toolDropdown:Select({})
    
    HX.SafeNotify({
        Title = "loc:TOOLS_FEATURES",
        Content = "loc:ALL_FEATURES_TURNED_OFF",
        Duration = 2,
        Icon = "power"
    }, true)
end

Window:OnDestroy(function()
    HX.CleanupTools()
end)
HX.loadStage(HX.stageLabel("BUILD_TAB"), 0.54)
BulidTab = Window:Tab({Title = "loc:BUILD_TAB", Icon = "hard-hat", Locked = false})

BulidTab:Section({
    Title = "loc:AUTO_BUILD_TITLE", 
    Icon = "circle-fading-plus",
    Desc = "loc:GRIEF_STEAL_DESC"
})

BuildProgressSection = BulidTab:Section({
    Title = "loc:BUILD_PROGRESS_NONE",
    Icon = "loader"
})

mult = 4
built = false
stopped = false
skipblock = false
highlight = Instance.new("Highlight")
highlight.Parent = game.CoreGui
highlight.FillColor = Color3.fromRGB(255,255,255)
highlight.FillTransparency = .9
childcube = nil
childcube2 = nil
oldprt = nil
tp = true
blocks = {}
cubehistory = {}
historynum = 0
historymax = 400
pinghistory = {}
historynum2 = 0
cubechild = nil
toxifybrick = nil
buildload = false
buildingtoxify = false
http = game:GetService("HttpService")
conn = {}
ors = true
resizewait = 0.4
lastwbs = resizewait
ping = -100

currentBuildProgress = 0
totalBuildBlocks = 0
currentBlockIndex = 0

local localplr = game.Players.LocalPlayer
HX.lte = nil

function checktool(t)
    if HX.lte ~= t.Name then
        if localplr.Character and t.Parent then
            t.Parent = localplr.Character
            task.wait()
            t.Parent = localplr.Backpack
            HX.lte = t.Name
        end
    end
end

getbuild = function()
    if SavedBuildDropdown and SavedBuildDropdown.Value ~= "" then
        return http:JSONDecode(readfile("TheChosenOneBuilds/"..SavedBuildDropdown.Value..".json"))
    end
    return nil
end

listfilesfixed = function(directory)
    local s, lf = pcall(function()
        return listfiles(directory)
    end)
    if s then
        for i,v in pairs(lf) do
            if string.sub(v,1,2) == "./" then
                lf[i] = string.sub(v,3)
            end
        end
    end
    return lf
end

prttable = nil
plrbuilds = {ServerBuilds = workspace.Bricks}
plrnames = {"ServerBuilds"}
buildhighlight = Instance.new("Highlight")
buildhighlight.Parent = game.CoreGui
buildhighlight.FillColor = Color3.fromRGB(0,255,0)
buildhighlight.FillTransparency = .9

getfn = function(js,first)
    local fn = listfilesfixed("TheChosenOneBuilds/") or listfilesfixed("TheChosenOneBuilds")
    if not fn or #fn == 0 then
        return {}
    end
    if not js then
        for i,v in pairs(fn) do
            fn[i] = v:gsub(".json","")
        end
    end
    if not first then
        for i,v in pairs(fn) do
            fn[i] = v:gsub("TheChosenOneBuilds/","")
        end
    end
    return fn
end

snap = function(pos,m)
    if m == nil then
        m = mult
    end
    local x = math.round(pos.X/m)+2
    return pos
end

if workspace.Bricks:FindFirstChild(game.Players.LocalPlayer.Name) then
    cubechild = workspace.Bricks[game.Players.LocalPlayer.Name].ChildAdded:Connect(function(child)
        childcube = child
        historynum = historynum + 1
        if historynum > historymax then
            historynum = 1
        end
        if buildingtoxify then
            toxifybrick = child
        end
        cubehistory[historynum] = child
        built = true
    end)
    for i,child in pairs(workspace.Bricks[game.Players.LocalPlayer.Name]:GetChildren()) do
    end
else
    cubechild = workspace.Bricks.ChildAdded:Connect(function()
    end)
end

defaultcolor = Color3.fromRGB(192,192,192)
buildingexec = nil
novel = false
normalids = {}
normalids[Enum.NormalId.Right] = {Vector3.new(1,0,0),"X"}
normalids[Enum.NormalId.Top] = {Vector3.new(0,1,0),"Y"}
normalids[Enum.NormalId.Back] = {Vector3.new(0,0,1),"Z"}
normalids[Enum.NormalId.Left] = {Vector3.new(-1,0,0),"X"}
normalids[Enum.NormalId.Bottom] = {Vector3.new(0,-1,0),"Y"}
normalids[Enum.NormalId.Front] = {Vector3.new(0,0,-1),"Z"}

roundnum = function(num,m)
    return math.round((num - 2) / m) * m + 2
end

round = function(pos,m)
    return Vector3.new(roundnum(pos.X,m or mult),roundnum(pos.Y,m or mult),roundnum(pos.Z,m or mult))
end

wbs = false

materials = {}
materials[Enum.Material.SmoothPlastic] = "smooth"
materials[Enum.Material.Plastic] = "plastic"
materials[Enum.Material.CeramicTiles] = "tiles"
materials[Enum.Material.Brick] = "bricks"
materials[Enum.Material.WoodPlanks] = "planks"
materials[Enum.Material.Ice] = "ice"
materials[Enum.Material.Grass] = "grass"
materials[Enum.Material.Sand] = "sand"
materials[Enum.Material.Snow] = "snow"
materials[Enum.Material.Glass] = "glass"
materials[Enum.Material.Wood] = "wood"
materials[Enum.Material.Slate] = "stone"
materials[Enum.Material.Pebble] = "pebble"
materials[Enum.Material.Marble] = "marble"
materials[Enum.Material.Granite] = "granite"
materials[Enum.Material.DiamondPlate] = "steel"
materials[Enum.Material.Metal] = "metal"
materials[Enum.Material.Asphalt] = "asphalt"
materials[Enum.Material.Concrete] = "concrete"
materials[Enum.Material.Pavement] = "pavement"
materials[Enum.Material.Neon] = "neon"

swappedmaterials = {}
for i,v in pairs(materials) do
    swappedmaterials[v] = i
end

starterui = game:GetService("StarterGui")
savebuildnames = {}
builds = {}

updatedropdown = function()
    local names = getfn()
    table.sort(names,function(a,b)
        return a:lower() < b:lower()
    end)
    if SavedBuildDropdown then
        SavedBuildDropdown:Refresh(names)
    end
    writefile("thechosenonenames.txt",http:JSONEncode(savebuildnames))
end

bindfunc = Instance.new("BindableFunction")
bindfunc.OnInvoke = function(prompt)
    if prompt == "Yes" and SavedBuildDropdown.Value ~= "" then
        delfile("TheChosenOneBuilds/"..SavedBuildDropdown.Value..".json")
        SavedBuildDropdown.Value = ""
        updatedropdown()
    end
end

bannedsymbols = {}
bannedsymbols["\""] = "''"
bannedsymbols["*"] = "ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã¢â‚¬Â¹Ãƒâ€¦Ã¢â‚¬Å“ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¦"
bannedsymbols[":"] = ";"
bannedsymbols["<"] = "ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â°ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¤"
bannedsymbols[">"] = "ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â°ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¥"
bannedsymbols["?"] = "ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¿"
bannedsymbols["\\"] = ""
bannedsymbols["|"] = "I"
bannedsymbols["/"] = "ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã¢â‚¬Â¹ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¢"

validate = function(name)
    for i,v in pairs(bannedsymbols) do
        name = name:gsub(i,v)
    end
    local s = string.find(name,"%.txt") or string.find(name,"%.json")
    if s then
        local addafter = string.sub(name,s)
        name = string.sub(name,1,s-1)
        name = name:gsub("%.","ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â·")
        name = name..addafter
    else
        name = name:gsub("%.","ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â·")
    end
    return name
end

files = listfilesfixed("")
if not files then
    files = {}
end

local s,e = pcall(function()
    if not table.find(files,"TheChosenOneBuilds/") and not table.find(files,"TheChosenOneBuilds") then
        task.wait(1)
        builds = {}
        if isfile("thechosenonebuilds.txt") then
            builds = http:JSONDecode(readfile("thechosenonebuilds.txt"))
        end
        makefolder("TheChosenOneBuilds")
        i2 = 0
        for i,v in pairs(builds) do
            i = validate(i)
            s,e = pcall(function()
                writefile("TheChosenOneBuilds/"..i..".json",http:JSONEncode(v))
            end)
            if not s then
                i2 = i2 + 1
                writefile("TheChosenOneBuilds/CheckFile_Named_'TCO"..tostring(i2).."'.json",http:JSONEncode(v))
                writefile("'TCO"..tostring(i2).."'.txt","If you came here from the CheckFile file, your build name had an error ("..i..") DO NOT change the file name to that name, it's best just to rename the file to something else.")
            end
            task.wait()
        end
    end
end)

s,e = pcall(function()
    if isfile("thechosenonenames.txt") then
        savebuildnames = http:JSONDecode(readfile("thechosenonenames.txt"))
    end
end)

if savebuildnames == nil then
    savebuildnames = {}
end

createpartpos = function(pos,col)
    if typeof(pos) == "CFrame" then
        pos = pos.Position
    end
    local p = Instance.new("Part")
    p.Shape = Enum.PartType.Ball
    p.Anchored = true
    p.CanCollide = false
    p.CastShadow = false
    p.CanQuery = false
    p.Color = col
    p.Transparency = .5
    p.Size = Vector3.new(3,3,3)
    p.CFrame = CFrame.new(pos)
    p.Parent = workspace
end

createpartrepl = function(pos,bsize,col,mat,transp,anch,collide,sprays)
    if typeof(pos) == "CFrame" then
        pos = pos.Position
    end
    local p = Instance.new("Part")
    oldprt = p
    p.Anchored = anch or true
    p.CanCollide = collide or false
    p.CastShadow = false
    p.CanQuery = false
    p.Color = col
    p.Transparency = transp or .5
    p.Material = mat
    if bsize ~= nil then
        pos = Vector3.new((pos.X + (bsize.X/2))-.5,(pos.Y + (bsize.Y/2))-.5,(pos.Z + (bsize.Z/2))-.5)
    end
    p.Size = bsize or Vector3.new(mult,mult,mult)
    p.CFrame = CFrame.new(pos)
    if sprays then
        for i,v in pairs(sprays) do
            local face = Enum.NormalId[v[1]]
            local image = v[2]
            local txt = v[3]
            local surfaceui = Instance.new("SurfaceGui")
            surfaceui.Face = face
            surfaceui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
            surfaceui.PixelsPerStud = 50
            local out,count = string.gsub(txt,"#","l")
            if count == string.len(txt) then
                local img = Instance.new("ImageLabel")
                img.Image = image
                img.BackgroundTransparency = 1
                img.Size = UDim2.new(1,0,1,0)
                img.Parent = surfaceui
            else
                local textlabel = Instance.new("TextLabel")
                textlabel.Text = txt
                textlabel.BackgroundTransparency = 1
                textlabel.TextScaled = true
                textlabel.TextColor3 = Color3.fromRGB(255,255,255)
                textlabel.Font = Enum.Font.FredokaOne
                textlabel.Size = UDim2.new(1,0,1,0)
                textlabel.Parent = surfaceui
            end
            surfaceui.Parent = p
        end
    end
    p.Parent = workspace
    return p
end

saveblock = function(bl)
    local blockdata = {}
    if bl:IsA("BasePart") then
        local p = bl.Position
        blockdata.p = {bl.Position.X,bl.Position.Y,bl.Position.Z}
        blockdata.c = {math.round(bl.Color.R*255),math.round(bl.Color.G*255),math.round(bl.Color.B*255)}
        blockdata.a = bl.Anchored
        blockdata.cc = bl.CanCollide
        if bl.Size.X ~= mult or bl.Size.Y ~= mult or bl.Size.Z ~= mult then
            blockdata.p[1] = (blockdata.p[1] - (bl.Size.X/2))+.5
            blockdata.p[2] = (blockdata.p[2] - (bl.Size.Y/2))+.5
            blockdata.p[3] = (blockdata.p[3] - (bl.Size.Z/2))+.5
            blockdata.s = {bl.Size.X,bl.Size.Y,bl.Size.Z}
        end
        blockdata.m = materials[bl.Material]
        blockdata.o = bl.Material.Name
    end
    return blockdata
end

updateBuildProgress = function()
    if totalBuildBlocks > 0 then
        currentBuildProgress = math.floor((currentBlockIndex / totalBuildBlocks) * 100)
        BuildProgressSection:SetTitle(string.format(
            HX.translate("BUILD_PROGRESS"),
            currentBuildProgress,
            currentBlockIndex,
            totalBuildBlocks
        ))
    else
        BuildProgressSection:SetTitle(HX.translate("BUILD_PROGRESS_NONE"))
    end
end

getSpawnPosition = function()
    local spawnLocations = workspace:FindFirstChild("SpawnLocation") or workspace:FindFirstChild("Spawn")
    if spawnLocations then
        if spawnLocations:IsA("Model") then
            local humanoidRootPart = spawnLocations:FindFirstChild("HumanoidRootPart")
            if humanoidRootPart then
                return humanoidRootPart.Position
            end
        elseif spawnLocations:IsA("BasePart") then
            return spawnLocations.Position
        end
    end
    
    local players = game.Players:GetPlayers()
    for _, player in ipairs(players) do
        if player.Character then
            local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
            if humanoidRootPart then
                return humanoidRootPart.Position
            end
        end
    end
    
    return Vector3.new(0, 100, 0)
end

sortBlocksByDistanceFromSpawn = function(buildData)
    local spawnPos = getSpawnPosition()
    
    for i, block in ipairs(buildData) do
        local blockPos = Vector3.new(block.p[1], block.p[2], block.p[3])
        if block.s then
            blockPos = Vector3.new(
                blockPos.X + (block.s[1]/2) - 0.5,
                blockPos.Y + (block.s[2]/2) - 0.5,
                blockPos.Z + (block.s[3]/2) - 0.5
            )
        end
        block.distance = (blockPos - spawnPos).Magnitude
        block.originalIndex = i
    end
    
    table.sort(buildData, function(a, b)
        return a.distance < b.distance
    end)
    
    return buildData
end

buildblock = function(pos,texture,color,bsize,bsizev3,premadebuild,origmaterial,sprays,anchored,collide)
    task.wait(0.001)
    if anchored == nil then
        anchored = true
    end
    if collide == nil then
        collide = true
    end
    needsresize = false
    s,e = pcall(function()
    s,e = pcall(function()
        game.Players.LocalPlayer.Backpack.Build.Parent = game.Players.LocalPlayer.Character
    end)
oo = false
c = 0
childcube = nil
if #cubehistory > 0 and oldprt then
    allooslol = {}
    for i,childcube2 in pairs(cubehistory) do
        if childcube2 == nil or childcube2.Parent == nil then
            cubehistory[i] = nil
        elseif oldprt.Size == childcube2.Size then
            for idx,v in pairs(normalids) do
                pos = childcube2.Position+(v[1]*childcube2.Size[v[2]])
                if pos == oldprt.Position then
                    oo = {idx,childcube2,childcube2.Position+(v[1]*childcube2.Size[v[2]]/2)}
                    table.insert(allooslol,{idx,childcube2,childcube2.Position+(v[1]*childcube2.Size[v[2]]/2)})
                end
            end
        end
    end
    if #allooslol > 1 and color and oo and oo[2] and oo[2].Color ~= color then
        for i,v in pairs(allooslol) do
            if v[2].Color == color then
                oo = v
            end
        end
    end
    origposs = pos
        if oo and oo[2] ~= nil and oo[2].Parent ~= nil then
            args = {
                [1] = oo[2],
                [2] = oo[1],
                [3] = oo[3] or oldprt.Position,
                [4] = "normal"
            }
            built = false
            childcube = nil
            c = 0
            repeat
                c = c + 1
                if game.Players.LocalPlayer.Character:FindFirstChild("Build") then
                    event = (game.Players.LocalPlayer.Character.Build:FindFirstChild("origevent") and game.Players.LocalPlayer.Character.Build.origevent:Invoke(unpack(args))) or game.Players.LocalPlayer.Character.Build.Script.Event:FireServer(unpack(args))
                else
                    s,e = pcall(function()
                        game.Players.LocalPlayer.Backpack.Build.Parent = game.Players.LocalPlayer.Character
                    end)
                end
                s,e = pcall(function()
                    novel = true
                    pos = oo[3] or pos
                    if tp then
                        game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(pos)
                    end
                end)
                task.wait(.05)
            until (built == true and childcube) or oo[2] == nil or oo[2].Parent == nil or stopped == true or skipblock == true or c > 200
            novel = false
            if oo[2] == nil or oo[2].Parent == nil or c > 200 then
                oo = false
            else
                if oldprt then
                    oldprt:Destroy()
                end
            end
        end
        pos = origposs
    end
    if oo == false then
    if bsize == nil then
        bsize = "normal"
        if game.Players.LocalPlayer.PlayerGui:FindFirstChild("Build") and game.Players.LocalPlayer.PlayerGui.Build:FindFirstChild("Button") then
            bsize = game.Players.LocalPlayer.PlayerGui.Build.Button.Text
        end
        if bsizev3 ~= nil and (bsizev3.X ~= mult or bsizev3.Y ~= mult or bsizev3.Z ~= mult) then
            bsize = "detailed"
        elseif bsizev3 ~= nil and (bsizev3.X == mult and bsizev3.Y == mult and bsizev3.Z == mult) then
            bsize = "normal"
        end
        if bsizev3 == nil and (bsize ~= "detailed") and oldprt and oldprt.Position ~= round(pos) then
            bsize = "detailed"
            needsresize = true
            bsizev3 = Vector3.new(4,4,4)
            pos = Vector3.new((pos.X - (bsizev3.X/2))+.5,(pos.Y - (bsizev3.Y/2))+.5,(pos.Z - (bsizev3.Z/2))+.5)
        end
    end
    oldpos = pos
    pos = snap(pos)
    args = {
        [1] = workspace.Terrain,
        [2] = Enum.NormalId.Top,
        [3] = pos,
        [4] = bsize or "normal"
    }
    built = false
    s,e = pcall(function()
        event = (game.Players.LocalPlayer.Character.Build:FindFirstChild("origevent") and game.Players.LocalPlayer.Character.Build.origevent:Invoke(unpack(args))) or game.Players.LocalPlayer.Character.Build.Script.Event:FireServer(unpack(args))
    end)
    c = 0
    repeat
        c = c + 1
        if game.Players.LocalPlayer.Character and not game.Players.LocalPlayer.Character:FindFirstChild("Build") and game.Players.LocalPlayer.Backpack:FindFirstChild("Build") then
            game.Players.LocalPlayer.Backpack.Build.Parent = game.Players.LocalPlayer.Character
        end
        if game.Players.LocalPlayer.Character:FindFirstChild("Build") then
            event = (game.Players.LocalPlayer.Character.Build:FindFirstChild("origevent") and game.Players.LocalPlayer.Character.Build.origevent:Invoke(unpack(args))) or game.Players.LocalPlayer.Character.Build.Script.Event:FireServer(unpack(args))
        end
        s,e = pcall(function()
            novel = true
            if tp then
                game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(pos + Vector3.new(0,6,0))
            end
        end)
        task.wait(.1)
    until (built == true and childcube) or stopped == true or skipblock == true or c > 200
    novel = false
    built = false
    c = 0
    end
    if childcube and typeof(color) == "Color3" and (color ~= defaultcolor or (childcube.Color ~= color or childcube.Material ~= texture)) and (game.Players.LocalPlayer.Backpack:FindFirstChild("Paint") or game.Players.LocalPlayer.Character:FindFirstChild("Paint")) and ((colorbool and premadebuild ~= nil) or not colorbool) or texture then
        pos = (childcube and childcube.Position + childcube.Size/2) or pos
        args = {
            [1] = childcube,
            [2] = Enum.NormalId.Top,
            [3] = pos,
            [4] = "color",
            [5] = color or nil,
            [6] = "tiles",
            [7] = ""
        }
        task.wait()
        local success,err = pcall(function()
            game.Players.LocalPlayer.Backpack.Paint.Parent = game.Players.LocalPlayer.Character
        end)
        if texture ~= nil then
            if color == nil then
                args[4] = "material"
            else
                args[4] = "both \u{1F91D}"
            end
            args[6] = texture
        end
        if not childcube then
            oldprt:Destroy()
            return
        end
        oldcolor = childcube.Color
        highlight.Adornee = childcube
        c = 0
        s,e = pcall(function()
        repeat
            c = c + 1
            if game.Players.LocalPlayer.Character and not game.Players.LocalPlayer.Character:FindFirstChild("Paint") and game.Players.LocalPlayer.Backpack:FindFirstChild("Paint") then
                game.Players.LocalPlayer.Backpack.Paint.Parent = game.Players.LocalPlayer.Character
            end
            if game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("Paint") then
                event = (game.Players.LocalPlayer.Character.Paint:FindFirstChild("origevent") and game.Players.LocalPlayer.Character.Paint.origevent:Invoke(unpack(args))) or game.Players.LocalPlayer.Character.Paint.Script.Event:FireServer(unpack(args))
            end
            s,e = pcall(function()
                novel = true
                if tp then
                    game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(pos + Vector3.new(0,6,0))
                end
            end)
            task.wait(.2)
        until not childcube or not childcube.Parent or childcube.Color == color or (texture and childcube.Material == Enum.Material[origmaterial]) or stopped == true or skipblock == true or c > 2000
        novel = false
        end)
    end
    if childcube and game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("Paint") and childcube.Anchored ~= anchored then
        pos = (childcube and childcube.Position + childcube.Size/2) or pos
        args = {
            [1] = childcube,
            [2] = Enum.NormalId.Top,
            [3] = pos or childcube.Position+Vector3.new(1,0,0),
            [4] = "material",
            [5] = nil,
            [6] = "anchor",
            [7] = ""
        }
        c = 0
        repeat
            c = c + 1
            if game.Players.LocalPlayer.Character and not game.Players.LocalPlayer.Character:FindFirstChild("Paint") and game.Players.LocalPlayer.Backpack:FindFirstChild("Paint") then
                game.Players.LocalPlayer.Backpack.Paint.Parent = game.Players.LocalPlayer.Character
            end
            if game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("Paint") and childcube and childcube.Anchored ~= anchored then
                event = (game.Players.LocalPlayer.Character.Paint:FindFirstChild("origevent") and game.Players.LocalPlayer.Character.Paint.origevent:Invoke(unpack(args))) or game.Players.LocalPlayer.Character.Paint.Script.Event:FireServer(unpack(args))
            end
            s,e = pcall(function()
                novel = true
                if tp then
                    game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(pos + Vector3.new(0,8,0))
                end
            end)
            task.wait(1)
        until not childcube or not childcube.Parent or childcube.Anchored == anchored or not game.Players.LocalPlayer.Character or (not game.Players.LocalPlayer.Character:FindFirstChild("Paint") and not game.Players.LocalPlayer.Backpack:FindFirstChild("Paint")) or stopped == true or skipblock == true or c > 20
        novel = false
    end
    if childcube and game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("Paint") and childcube.CanCollide ~= collide then
        pos = (childcube and childcube.Position + childcube.Size/2) or pos
        args = {
            [1] = childcube,
            [2] = Enum.NormalId.Top,
            [3] = pos or childcube.Position+Vector3.new(1,0,0),
            [4] = "material",
            [5] = nil,
            [6] = "collide",
            [7] = ""
        }
        c = 0
        repeat
            c = c + 1
            if game.Players.LocalPlayer.Character and not game.Players.LocalPlayer.Character:FindFirstChild("Paint") and game.Players.LocalPlayer.Backpack:FindFirstChild("Paint") then
                game.Players.LocalPlayer.Backpack.Paint.Parent = game.Players.LocalPlayer.Character
            end
            if game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("Paint") and childcube and childcube.CanCollide ~= collide then
                event = (game.Players.LocalPlayer.Character.Paint:FindFirstChild("origevent") and game.Players.LocalPlayer.Character.Paint.origevent:Invoke(unpack(args))) or game.Players.LocalPlayer.Character.Paint.Script.Event:FireServer(unpack(args))
            end
            s,e = pcall(function()
                novel = true
                if tp then
                    game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(pos + Vector3.new(0,8,0))
                end
            end)
            task.wait(1)
        until not childcube or not childcube.Parent or childcube.CanCollide == collide or not game.Players.LocalPlayer.Character or (not game.Players.LocalPlayer.Character:FindFirstChild("Paint") and not game.Players.LocalPlayer.Backpack:FindFirstChild("Paint")) or stopped == true or skipblock == true or c > 20
        novel = false
    end
    highlight.Adornee = nil
    if childcube and (game.Players.LocalPlayer.Backpack:FindFirstChild("Paint") or game.Players.LocalPlayer.Character:FindFirstChild("Paint")) and sprays ~= nil then
        args = {
            [1] = childcube,
            [2] = Enum.NormalId.Front,
            [3] = childcube.Position+Vector3.new(1,0,0),
            [4] = "material",
            [5] = nil,
            [6] = "spray",
            [7] = "ha"
        }
        for i,v in pairs(sprays) do
            args[2] = Enum.NormalId[v[1]]
            args[7] = v[3]
            if childcube and (game.Players.LocalPlayer.Backpack:FindFirstChild("Paint") or game.Players.LocalPlayer.Character:FindFirstChild("Paint")) and stopped == false and skipblock == false then
                local success,err = pcall(function()
                    game.Players.LocalPlayer.Backpack.Paint.Parent = game.Players.LocalPlayer.Character
                end)
                success,err = pcall(function()
                    task.wait(.5)
                    event = (game.Players.LocalPlayer.Character.Paint:FindFirstChild("origevent") and game.Players.LocalPlayer.Character.Paint.origevent:Invoke(unpack(args))) or game.Players.LocalPlayer.Character.Paint.Script.Event:FireServer(unpack(args))
                end)
            end
        end
    end
    if childcube and ((bsizev3 ~= nil and (bsizev3.X ~= mult or bsizev3.Y ~= mult or bsizev3.Z ~= mult)) or needsresize == true) and (game.Players.LocalPlayer.Character:FindFirstChild("Shape") or game.Players.LocalPlayer.Backpack:FindFirstChild("Shape")) then
        if not game.Players.LocalPlayer.Character:FindFirstChild("Shape") and game.Players.LocalPlayer.Backpack:FindFirstChild("Shape") then
            game.Players.LocalPlayer.Backpack.Shape.Parent = game.Players.LocalPlayer.Character
        end
        args = {
            [1] = childcube,
            [2] = Enum.NormalId.Right,
            [3] = "",
            [4] = ""
        }
        if childcube and childcube.Size.X ~= bsizev3.X then
            c = 0
            repeat
                c = c + 1
                pos = (childcube and childcube.Position + childcube.Size/2) or pos
                args[4] = nil
                if childcube then
                    args[3] = pos
                    if childcube.Size.X > bsizev3.X then
                        args[4] = "decrease"
                    elseif childcube.Size.X < bsizev3.X then
                        args[4] = "increase"
                    end
                end
                if not game.Players.LocalPlayer.Character:FindFirstChild("Shape") and game.Players.LocalPlayer.Backpack:FindFirstChild("Shape") then
                    game.Players.LocalPlayer.Backpack.Shape.Parent = game.Players.LocalPlayer.Character
                end
                if game.Players.LocalPlayer.Character:FindFirstChild("Shape") then
                    event = (game.Players.LocalPlayer.Character.Shape:FindFirstChild("origevent") and game.Players.LocalPlayer.Character.Shape.origevent:Invoke(unpack(args))) or game.Players.LocalPlayer.Character.Shape.Script.Event:FireServer(unpack(args))
                end
                s,e = pcall(function()
                    novel = true
                    if tp then
                        game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(pos + Vector3.new(0,6,0))
                    end
                end)
                task.wait(resizewait)
            until args[4] == nil or (args[4] == "decrease" and childcube and childcube.Size.X <= 1) or (childcube and childcube.Size.X == bsizev3.X) or stopped == true or skipblock == true or not childcube or not childcube.Parent or c > (bsizev3.X*3)/resizewait
            novel = false
        end
        args[2] = Enum.NormalId.Top
        c = 0
        if childcube and childcube.Size.Y ~= bsizev3.Y then
            repeat
                c = c + 1
                pos = (childcube and childcube.Position + childcube.Size/2) or pos
                args[4] = nil
                if childcube then
                    args[3] = pos
                    if childcube.Size.Y > bsizev3.Y then
                        args[4] = "decrease"
                    elseif childcube.Size.Y < bsizev3.Y then
                        args[4] = "increase"
                    end
                end
                if not game.Players.LocalPlayer.Character:FindFirstChild("Shape") and game.Players.LocalPlayer.Backpack:FindFirstChild("Shape") then
                    game.Players.LocalPlayer.Backpack.Shape.Parent = game.Players.LocalPlayer.Character
                end
                if game.Players.LocalPlayer.Character:FindFirstChild("Shape") then
                    event = (game.Players.LocalPlayer.Character.Shape:FindFirstChild("origevent") and game.Players.LocalPlayer.Character.Shape.origevent:Invoke(unpack(args))) or game.Players.LocalPlayer.Character.Shape.Script.Event:FireServer(unpack(args))
                end
                s,e = pcall(function()
                    novel = true
                    if tp then
                        game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(pos + Vector3.new(0,6,0))
                    end
                end)
                task.wait(resizewait)
            until args[4] == nil or (args[4] == "decrease" and childcube and childcube.Size.Y <= 1) or (childcube and childcube.Size.Y == bsizev3.Y) or stopped == true or skipblock == true or not childcube or not childcube.Parent or c > (bsizev3.Y*3)/resizewait
            novel = false
        end
        args[2] = Enum.NormalId.Back
        c = 0
        if childcube and childcube.Size.Z ~= bsizev3.Z then
            repeat
                c = c + 1
                pos = (childcube and childcube.Position + childcube.Size/2) or pos
                args[4] = nil
                if childcube then
                    args[3] = pos
                    if childcube.Size.Z > bsizev3.Z then
                        args[4] = "decrease"
                    elseif childcube.Size.Z < bsizev3.Z then
                        args[4] = "increase"
                    end
                end
                if not game.Players.LocalPlayer.Character:FindFirstChild("Shape") and game.Players.LocalPlayer.Backpack:FindFirstChild("Shape") then
                    game.Players.LocalPlayer.Backpack.Shape.Parent = game.Players.LocalPlayer.Character
                end
                if game.Players.LocalPlayer.Character:FindFirstChild("Shape") then
                    event = (game.Players.LocalPlayer.Character.Shape:FindFirstChild("origevent") and game.Players.LocalPlayer.Character.Shape.origevent:Invoke(unpack(args))) or game.Players.LocalPlayer.Character.Shape.Script.Event:FireServer(unpack(args))
                end
                s,e = pcall(function()
                    novel = true
                    if tp then
                        game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(pos + Vector3.new(0,6,0))
                    end
                end)
                task.wait(resizewait)
            until args[4] == nil or (args[4] == "decrease" and childcube and childcube.Size.Z <= 1) or (childcube and childcube.Size.Z == bsizev3.Z) or stopped == true or skipblock == true or not childcube or not childcube.Parent or c > (bsizev3.Z*3)/resizewait
            novel = false
        end
    end
    skipblock = false
    end)
    if oldprt then
        oldprt:Destroy()
    end
    novel = false
    childcube = nil
end

FileNameInput = BulidTab:Input({
    Title = "loc:FILE_NAME_SAVE",
    Value = "Untitled",
    Type = "Input",
    Placeholder = "loc:FILE_NAME_PLACEHOLDER",
    Callback = function(input)
        FileNameInput.Value = validate(input)
    end
})

files = listfilesfixed("")
if not files then files = {} end

if not table.find(files,"TheChosenOneBuilds/") and not table.find(files,"TheChosenOneBuilds") then
    makefolder("TheChosenOneBuilds")
end

buildFiles = getfn()

SavedBuildDropdown = BulidTab:Dropdown({
    Title = "loc:SELECT_SAVED_BUILDS",
    Desc = "loc:SELECT_SAVED_BUILDS_DESC",
    Values = buildFiles,
    Value = "",
    Callback = function(option) 
    end
})

BulidTab:Button({
    Title = "loc:SAVE_SERVER_BUILDS",
    Callback = function()
        if FileNameInput.Value == "" then
            return
        end
        builddata = {}
        for i,v in pairs(workspace.Bricks:GetDescendants()) do
            if v:IsA("BasePart") then
                table.insert(builddata,saveblock(v))
            end
        end
        savebuildname2 = FileNameInput.Value
        if FileNameInput.Value == "Untitled" or table.find(getfn(),FileNameInput.Value) ~= nil then
            if savebuildnames[FileNameInput.Value] == nil then
                savebuildnames[FileNameInput.Value] = 0
            end
            savebuildnames[FileNameInput.Value] = savebuildnames[FileNameInput.Value] + 1
            savebuildamt = savebuildnames[FileNameInput.Value]
            savebuildname2 = FileNameInput.Value..tostring(savebuildamt)
        end
        writefile("TheChosenOneBuilds/"..savebuildname2..".json",http:JSONEncode(builddata))
        updatedropdown()
    end
})

LoadBuildToggle = BulidTab:Toggle({
    Title = "loc:LOAD_BUILD",
    Callback = function(state)
        if state and SavedBuildDropdown and SavedBuildDropdown.Value ~= "" then
            build = getbuild()
            if build then
                buildload = true
                if oldprt then
                    oldprt:Destroy()
                end
                
                build = sortBlocksByDistanceFromSpawn(build)
                
                totalBuildBlocks = #build
                currentBlockIndex = 0
                currentBuildProgress = 0
                updateBuildProgress()
                
                for i,v in pairs(build) do
                    if stopped == true then
                        break
                    end
                    
                    currentBlockIndex = i
                    updateBuildProgress()
                    
                    blocktype = nil
                    args = {}
                    posses = (v.p or v.pos)
                    args[1] = CFrame.new(posses[1],posses[2],posses[3]).Position
                    args[2] = v.m or v.mat
                    args[3] = Color3.fromRGB(table.unpack(v.c or v.color))
                    if v.s or v.size then
                        args[5] = Vector3.new(table.unpack(v.s or v.size))
                    end
                    createpartrepl(args[1],args[5],args[3],swappedmaterials[v.m or v.mat])
                    args[7] = v.o or v.origmat
                    args[8] = v.sp or v.sprayed
                    args[9] = v.a or v.anchored
                    args[10] = v.cc or v.collide
                    buildblock(args[1],args[2],args[3],nil,args[5],nil,args[7],args[8],args[9],args[10])
                end
                
                stopped = false
                buildload = false
                currentBuildProgress = 0
                currentBlockIndex = 0
                totalBuildBlocks = 0
                updateBuildProgress()
                
                LoadBuildToggle:Set(false)
            end
        elseif not state and SavedBuildDropdown and SavedBuildDropdown.Value ~= "" then
            if buildload then
                stopped = true
                currentBuildProgress = 0
                currentBlockIndex = 0
                totalBuildBlocks = 0
                updateBuildProgress()
            end
        end
    end
})

BulidTab:Button({
    Title = "loc:DELETE_BUILD",
    Callback = function()
        if SavedBuildDropdown and SavedBuildDropdown.Value == "" then
            return
        end
        delfile("TheChosenOneBuilds/"..SavedBuildDropdown.Value..".json")
        updatedropdown()
    end
})

DisplayBuildToggle = BulidTab:Toggle({
    Title = "loc:DISPLAY_BUILD",
    Type = "Checkbox",
    Value = false,
    Callback = function(state)
        if state and SavedBuildDropdown and SavedBuildDropdown.Value ~= "" then
            build = getbuild()
            if build then
                if prttable then
                    for i,v in pairs(prttable) do
                        v:Destroy()
                    end
                end
                laggyparttable = {}
                for i,v in pairs(build) do
                    blocktype = nil
                    args = {}
                    posses = (v.pos or v.p)
                    args[1] = CFrame.new(posses[1],posses[2],posses[3]).Position
                    args[2] = v.mat or v.m
                    args[3] = Color3.fromRGB(table.unpack(v.color or v.c))
                    if v.size or v.s then
                        args[5] = Vector3.new(table.unpack(v.size or v.s))
                    end
                    prt = createpartrepl(args[1],args[5],args[3],swappedmaterials[v.mat or v.m],0,v.anchored or v.a,v.collide or v.cc,v.sprayed or v.sp)
                    table.insert(laggyparttable,prt)
                end
                prttable = laggyparttable
            end
        elseif not state and SavedBuildDropdown and SavedBuildDropdown.Value ~= "" then
            if prttable then
                for i,v in pairs(prttable) do
                    v:Destroy()
                end
            end
        end
    end
})

BulidTab:Button({
    Title = "loc:SKIP_BLOCK",
    Callback = function()
        skipblock = true
    end
})

PlayerDropdown = BulidTab:Dropdown({
    Title = "loc:SELECT_PLAYER",
    Desc = "loc:SELECT_PLAYER_DESC",
    Values = {"None"},
    Value = "None",
    Callback = function(option)
        buildhighlight.Adornee = plrbuilds[option]
    end
})

BulidTab:Button({
    Title = "loc:SAVE_PLAYER_BUILD",
    Callback = function()
        if FileNameInput.Value == "" then
            return
        end
        if PlayerDropdown.Value == "None" then
            return
        end
        plrbuild = plrbuilds[PlayerDropdown.Value]
        buildhighlight.Adornee = plrbuild
        builddata = {}
        for i,v in pairs(plrbuild:GetChildren()) do
            if v:IsA("BasePart") then
                table.insert(builddata,saveblock(v))
            end
        end
        savebuildname2 = FileNameInput.Value
        if FileNameInput.Value == "Untitled" or table.find(getfn(),FileNameInput.Value) ~= nil then
            if savebuildnames[FileNameInput.Value] == nil then
                savebuildnames[FileNameInput.Value] = 0
            end
            savebuildnames[FileNameInput.Value] = savebuildnames[FileNameInput.Value] + 1
            savebuildamt = savebuildnames[FileNameInput.Value]
            savebuildname2 = FileNameInput.Value..tostring(savebuildamt)
        end
        writefile("TheChosenOneBuilds/"..savebuildname2..".json",http:JSONEncode(builddata))
        updatedropdown()
    end
})

highlightbuildtoggle = BulidTab:Toggle({
    Title = "loc:HIGHLIGHT_PLAYER_BUILD",
    Type = "Checkbox",
    Value = false,
    Callback = function(state)
        if state then
            buildhighlight.FillTransparency = .9
            buildhighlight.OutlineTransparency = 0
        else
            buildhighlight.FillTransparency = 1
            buildhighlight.OutlineTransparency = 1
        end
    end
})

BulidTab:Section({
    Title = "loc:SETTINGS_TAB",
    Icon = "settings"
})

resizewaitl = BulidTab:Section({
    Title = string.format(HX.translate("RESIZE_WAIT"), "0.4"),
    Icon = "clock"
})

pingl = BulidTab:Section({
    Title = string.format(HX.translate("PING"), "???"),
    Icon = "globe"
})

ResizeTimeInput = BulidTab:Input({
    Title = "loc:RESIZE_TIME",
    Desc = "loc:RESIZE_TIME_DESC",
    Value = "0.4",
    Type = "Input",
    Placeholder = "0.4",
    Callback = function(input)
        if not input or not tonumber(input) then
            input = "0.4"
        end
        resizewait = tonumber(input)
        resizewaitl:SetTitle(string.format(HX.translate("RESIZE_WAIT"), tostring(resizewait)))
    end
})

BulidTab:Toggle({
    Title = "loc:AUTO_RESIZE_WAIT",
    Type = "Checkbox",
    Value = false,
    Callback = function(state)
        wbs = state
        if state then
            lastwbs = resizewait
        else
            resizewait = lastwbs
            resizewaitl:SetTitle(string.format(HX.translate("RESIZE_WAIT"), tostring(resizewait)))
        end
    end
})

BrickHistoryInput = BulidTab:Input({
    Title = "loc:BRICK_HISTORY",
    Desc = "loc:BRICK_HISTORY_DESC",
    Value = "400",
    Type = "Input",
    Placeholder = "400",
    Callback = function(input)
        if input == nil or not tonumber(input) then
            input = "400"
        end
        local historymax = math.abs(tonumber(input) or 0)
        for i,v in pairs(cubehistory) do
            if i > historymax then
                cubehistory[i] = nil
            end
        end
    end
})

BulidTab:Section({
    Title = "loc:RESIZE_PERF_HINT",
    Icon = "info"
})

BulidTab:Section({
    Title = "loc:BUILD_THANKS",
    Icon = "heart"
})

Window:OnDestroy(function()
    stopped = true
    if cubechild then
        cubechild:Disconnect()
    end
    if highlight then
        highlight:Destroy()
    end
    if buildhighlight then
        buildhighlight:Destroy()
    end
    if prttable then
        for i,v in pairs(prttable) do
            v:Destroy()
        end
    end
    if oldprt then
        oldprt:Destroy()
    end
end)
HX.loadStage(HX.stageLabel("GRIEF_TAB"), 0.61)
GriefTab = Window:Tab({Title = "loc:GRIEF_TAB", Icon = "bomb", Locked = false})
GriefTab:Section({Title = "loc:GRIEF_TAB", Icon = "user-round-minus", Desc = "loc:GRIEF_EVIL_DESC"})
GriefTab:Section({Title = "loc:GRIEF_SCROLL_NOTE", TextSize = 20})
GriefTab:Section({Title = "loc:AURA_SETTINGS", Icon = "settings", TextSize = 25})

_G.AuraRange = 15
_G.RangeShape = "Circle"
_G.AuraMethod = "Range"
_G.BlocksTracers = false
_G.BuildType = "normal"
_G.ShovelType = "dig"
_G.MaterialType = "Smooth"
_G.PaintColor = Color3.fromRGB(255, 255, 255)

GriefTab:Slider({
    Title = "loc:AURA_RANGE", Desc = "loc:AURA_RANGE_DESC", Step = 1,
    Value = {Min = 1, Max = 30, Default = 15}, Locked = false, LockedTitle = HX.translate("PREMIUM"),
    Callback = function(v) _G.AuraRange = v; if Funcs and Funcs.rebuildRangeGrid then Funcs.rebuildRangeGrid() end end
})

GriefTab:Dropdown({
    Title = "loc:RANGE_SHAPE", Desc = "loc:RANGE_SHAPE_DESC", Values = {"Circle", "Square"}, Value = "Circle",
    Callback = function(v) _G.RangeShape = v; if Funcs and Funcs.rebuildRangeGrid then Funcs.rebuildRangeGrid() end end
})

GriefTab:Dropdown({
    Title = "loc:AURA_METHOD", Desc = "loc:SELECT_METHOD_DESC", Values = {"Range", "Inf Range", "Freecam"}, Value = "Range",
    Callback = function(v) _G.AuraMethod = v; if v ~= "Freecam" and Funcs and Funcs.stopFreecam then Funcs.stopFreecam() end end
})

GriefTab:Toggle({
    Title = "loc:BLOCKS_TRACERS", Value = false,
    Callback = function(v) _G.BlocksTracers = v; if not v and Funcs and Funcs.clearAllTracers then Funcs.clearAllTracers() end end
})

GriefTab:Colorpicker({
    Title = "loc:PAINT_AURA_COLOR", Default = Color3.fromRGB(255, 255, 255), Transparency = 0, Locked = false,
    Callback = function(color) _G.PaintColor = color end
})

GriefTab:Dropdown({Title = "loc:BUILD_MODE", Desc = "loc:BUILD_MODE_DESC", Values = {"normal", "detailed", "both"}, Value = "normal", Callback = function(v) _G.BuildType = v end})
GriefTab:Dropdown({Title = "loc:SHOVEL_MODE", Desc = "loc:SHOVEL_MODE_DESC", Values = {"dig", "fill"}, Value = "dig", Callback = function(v) _G.ShovelType = v end})
GriefTab:Dropdown({
    Title = "loc:CHOOSE_MATERIAL", Desc = "loc:SELECT_MATERIAL_DESC", Value = "Smooth",
    Values = {"Smooth", "Plastic", "Tiles", "Bricks", "Planks", "Ice", "Snow", "Glass", "Wood", "Stone", "Pebble", "Marble", "Granite", "Steel", "Metal", "Asphalt", "Concrete", "Pavement", "Neon"},
    Callback = function(v) _G.MaterialType = v end
})

GriefTab:Section({Title = "loc:AURAS", Icon = "orbit"})

GriefEnv = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    UserInputService = game:GetService("UserInputService"),
    Stats = game:GetService("Stats"),
    Camera = workspace.CurrentCamera
}
GriefEnv.localplr = GriefEnv.Players.LocalPlayer

State = {
    ws = 0.05, isog = false, lte = nil, InternalUnequip = false,
    FreecamActive = false, FreecamCon = nil, MouseSphere = nil, SavedRootCFrame = nil,
    CamYaw = 0, CamPitch = 0, FreecamSpeed = 70,
    BuiltRange = nil, BuiltShape = nil, PreviewGhost = nil,
    ProcessedBricks = setmetatable({}, {__mode = "k"}), ProcessedVoxels = {},
    HiddenToolParts = setmetatable({}, {__mode = "k"}),
    TracerPool = {}, TracerTargets = {}, GridSegments = {}, DeleteAuraHighlights = {}, auraTasks = {},
    RangeGridFolder = Instance.new("Folder")
}
State.RangeGridFolder.Name = "AuraRangeGridVisual"
State.RangeGridFolder.Parent = workspace

Consts = {
    MAX_TRACERS = 25, MAX_HIGHLIGHTS = 20,
    HasDrawingAPI = (type(Drawing) == "table" and type(Drawing.new) == "function"),
    overlapParams = OverlapParams.new(),
    MaterialLookup = {
        Smooth={Name="SmoothPlastic",Arg="smooth"}, Plastic={Name="Plastic",Arg="plastic"}, Tiles={Name="CeramicTiles",Arg="tiles"},
        Bricks={Name="Brick",Arg="bricks"}, Planks={Name="WoodPlanks",Arg="planks"}, Ice={Name="Ice",Arg="ice"}, Snow={Name="Snow",Arg="snow"},
        Glass={Name="Glass",Arg="glass"}, Wood={Name="Wood",Arg="wood"}, Stone={Name="Slate",Arg="stone"}, Pebble={Name="Pebble",Arg="pebble"},
        Marble={Name="Marble",Arg="marble"}, Granite={Name="Granite",Arg="granite"}, Steel={Name="DiamondPlate",Arg="steel"},
        Metal={Name="Metal",Arg="metal"}, Asphalt={Name="Asphalt",Arg="asphalt"}, Concrete={Name="Concrete",Arg="concrete"},
        Pavement={Name="Pavement",Arg="pavement"}, Neon={Name="Neon",Arg="neon"}
    }
}
Consts.overlapParams.FilterType = Enum.RaycastFilterType.Include

Funcs = {}

Funcs.hideToolVisuals = function(tool)
    if not tool then return end
    for _, desc in ipairs(tool:GetDescendants()) do
        if desc:IsA("BasePart") then
            if not State.HiddenToolParts[desc] then
                State.HiddenToolParts[desc] = {
                    Transparency = desc.Transparency,
                    CanCollide = desc.CanCollide,
                    CanTouch = desc.CanTouch,
                    CanQuery = desc.CanQuery,
                    CastShadow = desc.CastShadow,
                    Massless = desc.Massless
                }
            end
            desc.LocalTransparencyModifier = 1
            desc.Transparency = 1
            desc.CanCollide = false
            desc.CanTouch = false
            desc.CanQuery = false
            desc.CastShadow = false
            desc.Massless = true
        elseif desc:IsA("ParticleEmitter") or desc:IsA("Trail") or desc:IsA("Beam") or desc:IsA("Light") then
            if State.HiddenToolParts[desc] == nil then
                State.HiddenToolParts[desc] = desc.Enabled
            end
            desc.Enabled = false
        end
    end
end

Funcs.restoreAllTools = function()
    local char = GriefEnv.localplr.Character
    local backpack = GriefEnv.localplr:FindFirstChild("Backpack")
    if char and backpack then
        State.InternalUnequip = true
        for _, v in ipairs(char:GetChildren()) do
            if v:IsA("Tool") then pcall(function() v.Parent = backpack end) end
        end
        State.InternalUnequip = false
    end
    for inst, orig in pairs(State.HiddenToolParts) do
        if inst and inst.Parent then
            pcall(function()
                if inst:IsA("BasePart") then
                    inst.LocalTransparencyModifier = 0
                    inst.Transparency = orig.Transparency
                    inst.CanCollide = orig.CanCollide
                    inst.CanTouch = orig.CanTouch
                    inst.CanQuery = orig.CanQuery
                    inst.CastShadow = orig.CastShadow
                    inst.Massless = orig.Massless
                else
                    inst.Enabled = orig
                end
            end)
        end
    end
    table.clear(State.HiddenToolParts)
    State.lte = nil
end

Funcs.trackCharacterTools = function(char)
    if not char then return end
    State.lte = nil
    char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            State.lte = child.Name
            if Funcs.isAnyAuraRunning() then Funcs.hideToolVisuals(child) end
        end
    end)
    char.ChildRemoved:Connect(function(child)
        if child:IsA("Tool") and State.lte == child.Name and not State.InternalUnequip then
            State.lte = nil
        end
    end)
end

if GriefEnv.localplr.Character then Funcs.trackCharacterTools(GriefEnv.localplr.Character) end
GriefEnv.localplr.CharacterAdded:Connect(Funcs.trackCharacterTools)

Funcs.checktool = function(t)
    if not t or not GriefEnv.localplr.Character then return end
    Funcs.hideToolVisuals(t)
    if State.lte ~= t.Name then
        State.InternalUnequip = true
        t.Parent = GriefEnv.localplr.Character
        if not State.isog then t.Parent = GriefEnv.localplr.Backpack end
        State.InternalUnequip = false
        State.lte = t.Name
    end
end

Funcs.gcp = function(p, plr)
    local c = (plr ~= nil and plr.Character) or GriefEnv.localplr.Character
    p = p:lower()
    if p == "hrp" then p = "HumanoidRootPart" elseif p == "hum" then p = "Humanoid" end
    if c and c:FindFirstChild(p) then return c:FindFirstChild(p) else return false end
end

Funcs.findbtools = function(toolName)
    local tools = {}
    local backpack = GriefEnv.localplr:FindFirstChild("Backpack")
    if backpack then
        for _, v in ipairs(backpack:GetChildren()) do
            if v:IsA("Tool") and v.Name == toolName and v:FindFirstChild("Script") and v.Script:FindFirstChild("Event") then
                if Funcs.isAnyAuraRunning() then Funcs.hideToolVisuals(v) end
                table.insert(tools, {bt = v, e = v.Script.Event})
            end
        end
    end
    if GriefEnv.localplr.Character then
        for _, v in ipairs(GriefEnv.localplr.Character:GetChildren()) do
            if v:IsA("Tool") and v.Name == toolName and v:FindFirstChild("Script") and v.Script:FindFirstChild("Event") then
                if Funcs.isAnyAuraRunning() then Funcs.hideToolVisuals(v) end
                table.insert(tools, {bt = v, e = v.Script.Event})
            end
        end
    end
    return tools
end

Funcs.safenotify = function(title, content, duration, icon)
    if HX.SafeNotify then HX.SafeNotify({Title = title, Content = content, Duration = duration or 2, Icon = icon or "info"}, true) end
end

Funcs.isAnyAuraRunning = function() return _G.BlocksAuraRunning or _G.DeleteAuraRunning or _G.SignAuraRunning or _G.UnanchorAuraRunning or _G.ToxicAuraRunning or _G.ShovelAuraRunning or _G.MaterialAuraRunning or _G.PaintAuraRunning end
Funcs.isMethodAuraActive = function() return _G.DeleteAuraRunning or _G.UnanchorAuraRunning or _G.ToxicAuraRunning or _G.MaterialAuraRunning or _G.PaintAuraRunning end

Funcs.getActiveAuraColors = function()
    if _G.DeleteAuraRunning then return Color3.fromRGB(255, 50, 50), Color3.fromRGB(255, 0, 0)
    elseif _G.BlocksAuraRunning then return Color3.fromRGB(50, 255, 50), Color3.fromRGB(0, 255, 0)
    elseif _G.SignAuraRunning then return Color3.fromRGB(210, 180, 140), Color3.fromRGB(139, 69, 19)
    elseif _G.UnanchorAuraRunning then return Color3.fromRGB(255, 255, 0), Color3.fromRGB(255, 215, 0)
    elseif _G.ToxicAuraRunning then return Color3.fromRGB(0, 0, 0), Color3.fromRGB(50, 50, 50)
    elseif _G.ShovelAuraRunning then return Color3.fromRGB(255, 165, 0), Color3.fromRGB(255, 140, 0)
    elseif _G.MaterialAuraRunning then return Color3.fromRGB(173, 216, 230), Color3.fromRGB(135, 206, 235)
    elseif _G.PaintAuraRunning then return _G.PaintColor, Color3.new(math.max(_G.PaintColor.R - 0.2, 0), math.max(_G.PaintColor.G - 0.2, 0), math.max(_G.PaintColor.B - 0.2, 0)) end
    return Color3.fromRGB(255, 50, 50), Color3.fromRGB(255, 0, 0)
end

Funcs.isBrickOnCooldown = function(brick) return State.ProcessedBricks[brick] and tick() < State.ProcessedBricks[brick] end
Funcs.markBrickProcessed = function(brick, cooldown) State.ProcessedBricks[brick] = tick() + (cooldown or 0.05) end

Funcs.getOrCreateTracer = function(idx)
    if State.TracerPool[idx] then return State.TracerPool[idx] end
    if Consts.HasDrawingAPI then
        local ok, line = pcall(function() local l = Drawing.new("Line"); l.Thickness = 1.5; l.Transparency = 0.85; l.Visible = false; return l end)
        if ok and line then State.TracerPool[idx] = line; return line end
    end
    return nil
end

Funcs.clearAllTracers = function()
    table.clear(State.TracerTargets)
    for _, line in pairs(State.TracerPool) do pcall(function() line.Visible = false end) end
end

Funcs.makeGridPart = function(localOffset, size, angleY, isBorder)
    local p = Instance.new("Part"); p.Name = isBorder and "BorderBar" or "GridBar"
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
    p.Material = Enum.Material.SmoothPlastic; p.Transparency = isBorder and 0.12 or 0.52; p.Size = size; p.Parent = State.RangeGridFolder
    table.insert(State.GridSegments, {Part = p, Offset = localOffset, Rot = CFrame.Angles(0, angleY or 0, 0), IsBorder = isBorder})
end

Funcs.rebuildRangeGrid = function()
    for _, seg in ipairs(State.GridSegments) do if seg.Part and seg.Part.Parent then seg.Part:Destroy() end end
    table.clear(State.GridSegments)
    local r = _G.AuraRange; local shape = _G.RangeShape; State.BuiltRange = r; State.BuiltShape = shape
    local bThick = 0.22; local bHeight = 0.08; local gThick = 0.09; local gHeight = 0.05; local step = 4
    if shape == "Square" then
        local fullLen = r * 2
        Funcs.makeGridPart(Vector3.new(0, 0, -r), Vector3.new(fullLen + bThick, bHeight, bThick), 0, true)
        Funcs.makeGridPart(Vector3.new(0, 0,  r), Vector3.new(fullLen + bThick, bHeight, bThick), 0, true)
        Funcs.makeGridPart(Vector3.new(-r, 0, 0), Vector3.new(bThick, bHeight, fullLen - bThick), 0, true)
        Funcs.makeGridPart(Vector3.new( r, 0, 0), Vector3.new(bThick, bHeight, fullLen - bThick), 0, true)
        for d = -r + step, r - 0.5, step do
            Funcs.makeGridPart(Vector3.new(d, 0, 0), Vector3.new(gThick, gHeight, fullLen - bThick), 0, false)
            Funcs.makeGridPart(Vector3.new(0, 0, d), Vector3.new(fullLen - bThick, gHeight, gThick), 0, false)
        end
    else
        local segCount = 48; local segLen = (2 * math.pi * r / segCount) + 0.06
        for i = 1, segCount do local theta = (i / segCount) * math.pi * 2; Funcs.makeGridPart(Vector3.new(math.cos(theta) * r, 0, math.sin(theta) * r), Vector3.new(bThick, bHeight, segLen), -theta, true) end
        for k = -math.floor((r - 0.5) / step), math.floor((r - 0.5) / step) do
            local d = k * step; local chordLen = (math.sqrt(math.max(0, (r * r) - (d * d))) * 2) - bThick
            if chordLen > 0.5 then Funcs.makeGridPart(Vector3.new(d, 0, 0), Vector3.new(gThick, gHeight, chordLen), 0, false); Funcs.makeGridPart(Vector3.new(0, 0, d), Vector3.new(chordLen, gHeight, gThick), 0, false) end
        end
    end
end
Funcs.rebuildRangeGrid()

Funcs.setGridVisible = function(vis) for _, seg in ipairs(State.GridSegments) do if seg.Part then seg.Part.Transparency = vis and (seg.IsBorder and 0.12 or 0.52) or 1 end end end

Funcs.highlightBrick = function(brick, fillColor, outlineColor)
    if not brick or not brick:IsDescendantOf(workspace) then return end
    local existing = State.DeleteAuraHighlights[brick]
    if existing and existing.Parent then existing.FillColor = fillColor; existing.OutlineColor = outlineColor or fillColor; return end
    local count = 0
    for b, hl in pairs(State.DeleteAuraHighlights) do
        if not b or not b:IsDescendantOf(workspace) or not hl or not hl.Parent then if hl then pcall(function() hl:Destroy() end) end; State.DeleteAuraHighlights[b] = nil else count = count + 1 end
    end
    if count >= Consts.MAX_HIGHLIGHTS then return end
    local hl = Instance.new("Highlight"); hl.Name = "RangeHighlight"; hl.Adornee = brick; hl.FillColor = fillColor; hl.OutlineColor = outlineColor or fillColor
    hl.FillTransparency = 0.45; hl.OutlineTransparency = 0; hl.Parent = brick; State.DeleteAuraHighlights[brick] = hl
end

Funcs.clearBrickHighlight = function(brick)
    local hl = State.DeleteAuraHighlights[brick]; if hl then pcall(function() hl:Destroy() end); State.DeleteAuraHighlights[brick] = nil end
    if brick then local stray = brick:FindFirstChild("RangeHighlight"); if stray then pcall(function() stray:Destroy() end) end end
end

Funcs.showSinglePlacementPreview = function(cframe, size, fillColor, outlineColor)
    if not State.PreviewGhost or not State.PreviewGhost.Parent then
        State.PreviewGhost = Instance.new("Part"); State.PreviewGhost.Name = "AuraPlacementPreview"; State.PreviewGhost.Anchored = true; State.PreviewGhost.CanCollide = false
        State.PreviewGhost.CanQuery = false; State.PreviewGhost.CanTouch = false; State.PreviewGhost.CastShadow = false; State.PreviewGhost.Material = Enum.Material.SmoothPlastic
        State.PreviewGhost.Transparency = 0.65
        local hl = Instance.new("Highlight"); hl.Name = "RangeHighlight"; hl.Adornee = State.PreviewGhost; hl.FillTransparency = 0.45; hl.OutlineTransparency = 0; hl.Parent = State.PreviewGhost
    end
    State.PreviewGhost.Size = size; State.PreviewGhost.CFrame = cframe; State.PreviewGhost.Color = fillColor
    local hl = State.PreviewGhost:FindFirstChild("RangeHighlight")
    if hl then hl.FillColor = fillColor; hl.OutlineColor = outlineColor or fillColor end; State.PreviewGhost.Parent = workspace
end

Funcs.hideSinglePlacementPreview = function() if State.PreviewGhost and State.PreviewGhost.Parent then State.PreviewGhost.Parent = nil end end

Funcs.clearHighlights = function()
    for brick, hl in pairs(State.DeleteAuraHighlights) do if hl then pcall(function() hl:Destroy() end) end; if brick then local stray = brick:FindFirstChild("RangeHighlight"); if stray then pcall(function() stray:Destroy() end) end end end
    table.clear(State.DeleteAuraHighlights); Funcs.hideSinglePlacementPreview(); Funcs.clearAllTracers()
end

Funcs.getclosestcubes = function(pos, limit, smallwait, filterFn, respectRange)
    local cubes = {}
    local origin = pos or (Funcs.gcp("hrp") and Funcs.gcp("hrp").Position)
    local cfolder = workspace:FindFirstChild("Bricks")
    if origin and cfolder then
        local range = _G.AuraRange
        local isCircle = (_G.RangeShape == "Circle")
        for _, playerFolder in ipairs(cfolder:GetChildren()) do
            for _, v in ipairs(playerFolder:GetChildren()) do
                if v:IsA("BasePart") and (not filterFn or filterFn(v)) then
                    local bPos = v.Position
                    local half = v.Size * 0.5
                    local dx = math.max(math.abs(bPos.X - origin.X) - half.X, 0)
                    local dy = math.max(math.abs(bPos.Y - origin.Y) - half.Y, 0)
                    local dz = math.max(math.abs(bPos.Z - origin.Z) - half.Z, 0)
                    local dist3D = math.sqrt(dx * dx + dy * dy + dz * dz)
                    local inRange = true
                    if respectRange then
                        if isCircle then
                            local dist2D = math.sqrt(dx * dx + dz * dz)
                            inRange = (dist2D <= range and dy <= range + 4)
                        else
                            inRange = (dx <= range and dz <= range and dy <= range + 4)
                        end
                    end
                    if inRange then
                        cubes[#cubes + 1] = {v, dist3D}
                    end
                end
            end
        end
        table.sort(cubes, function(x, y) return x[2] < y[2] end)
    end
    if limit and #cubes > limit then
        local cubes2 = {}
        table.move(cubes, 1, limit, 1, cubes2)
        cubes = cubes2
    end
    return cubes
end

Funcs.isBlockPlacedAt = function(pos, boxSize)
    local cfolder = workspace:FindFirstChild("Bricks"); if not cfolder then return false end
    Consts.overlapParams.FilterDescendantsInstances = {cfolder}
    local parts = workspace:GetPartBoundsInBox(CFrame.new(pos), boxSize or Vector3.new(3.2, 3.2, 3.2), Consts.overlapParams); return #parts > 0
end

Funcs.snapToGameGrid = function(pos, mode)
    if mode == "detailed" then return Vector3.new(math.floor(pos.X) + 0.5, math.floor(pos.Y) + 0.5, math.floor(pos.Z) + 0.5)
    else return Vector3.new(math.floor(pos.X / 4) * 4 + 2, math.floor(pos.Y / 4) * 4 + 2, math.floor(pos.Z / 4) * 4 + 2) end
end

Funcs.isWithinAuraShape2D = function(pos, center)
    local dx = pos.X - center.X; local dz = pos.Z - center.Z
    if _G.RangeShape == "Circle" then return math.sqrt(dx * dx + dz * dz) <= _G.AuraRange else return math.abs(dx) <= _G.AuraRange and math.abs(dz) <= _G.AuraRange end
end

Funcs.getBuildSignTargets = function(origin, count, mode)
    local results = {}; local seen = {}; local attempts = 0; local checkSize = (mode == "detailed") and Vector3.new(0.8, 0.8, 0.8) or Vector3.new(3.4, 3.4, 3.4)
    while #results < count and attempts < count * 8 do
        attempts = attempts + 1
        local candidate = Funcs.snapToGameGrid(origin + Vector3.new(math.random(-_G.AuraRange, _G.AuraRange), math.random(-math.min(_G.AuraRange, 8), math.min(_G.AuraRange, 8)), math.random(-_G.AuraRange, _G.AuraRange)), mode)
        if Funcs.isWithinAuraShape2D(candidate, origin) and (candidate - origin).Magnitude >= 4 then
            local key = string.format("%.1f_%.1f_%.1f", candidate.X, candidate.Y, candidate.Z)
            if not seen[key] and not Funcs.isBlockPlacedAt(candidate, checkSize) then seen[key] = true; results[#results + 1] = candidate end
        end
    end; return results
end

Funcs.getUnderPlayerTerrainVoxels = function(hrpPos, maxCount)
    local range = math.clamp(_G.AuraRange, 4, 30); local now = tick()
    for k, exp in pairs(State.ProcessedVoxels) do if now >= exp then State.ProcessedVoxels[k] = nil end end
    local minCorner = Vector3.new(hrpPos.X - range, hrpPos.Y - range - 4, hrpPos.Z - range)
    local maxCorner = Vector3.new(hrpPos.X + range, hrpPos.Y + 4, hrpPos.Z + range); local region = Region3.new(minCorner, maxCorner):ExpandToGrid(4)
    local ok, materials, occupancies = pcall(function() return workspace.Terrain:ReadVoxels(region, 4) end)
    if not ok or not materials or not occupancies then return {} end
    local size = materials.Size; local regionStart = region.CFrame.Position - (region.Size * 0.5); local candidates = {}
    for x = 1, size.X do for y = 1, size.Y do for z = 1, size.Z do
        local mat = materials[x][y][z]; local occ = occupancies[x][y][z]; local voxelCenter = regionStart + Vector3.new((x - 0.5) * 4, (y - 0.5) * 4, (z - 0.5) * 4)
        local key = string.format("%d_%d_%d", math.floor(voxelCenter.X), math.floor(voxelCenter.Y), math.floor(voxelCenter.Z))
        if not State.ProcessedVoxels[key] or now >= State.ProcessedVoxels[key] then
            local dx = voxelCenter.X - hrpPos.X; local dy = voxelCenter.Y - hrpPos.Y; local dz = voxelCenter.Z - hrpPos.Z
            local dist2D = math.sqrt(dx * dx + dz * dz); local inShape = false
            if _G.RangeShape == "Circle" then inShape = (dist2D <= range and math.abs(dy) <= range + 4) else inShape = (math.abs(dx) <= range and math.abs(dz) <= range and math.abs(dy) <= range + 4) end
            if inShape then
                if _G.ShovelType == "dig" then if mat ~= Enum.Material.Air and mat ~= Enum.Material.Water and occ > 0 then candidates[#candidates + 1] = {Pos = voxelCenter, Key = key, Score = (dist2D * 1.5) + math.abs(dy + 3)} end
                else if dy <= -2 and (mat == Enum.Material.Air or occ < 0.5) then candidates[#candidates + 1] = {Pos = voxelCenter, Key = key, Score = (dist2D * 1.5) + math.abs(dy + 4)} end end
            end
        end
    end end end
    table.sort(candidates, function(a, b) return a.Score < b.Score end); local out = {}
    for i = 1, math.min(maxCount, #candidates) do out[i] = candidates[i] end; return out
end

Funcs.getMouseTargetPos = function()
    local mPos = GriefEnv.UserInputService:GetMouseLocation(); local ray = GriefEnv.Camera:ViewportPointToRay(mPos.X, mPos.Y)
    local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances = {GriefEnv.localplr.Character, State.MouseSphere, State.PreviewGhost, State.RangeGridFolder}
    local hit = workspace:Raycast(ray.Origin, ray.Direction * 1500, params)
    if hit then return hit.Position end; return ray.Origin + (ray.Direction * 45)
end

Funcs.startFreecam = function()
    if State.FreecamActive then return true end
    if not (GriefEnv.UserInputService.KeyboardEnabled and GriefEnv.UserInputService.MouseEnabled) then Funcs.safenotify("PC Only", "Freecam is only supported on PC!", 3, "alert"); _G.AuraMethod = "Range"; return false end
    local hrp = Funcs.gcp("hrp"); if hrp then State.SavedRootCFrame = hrp.CFrame end
    State.FreecamActive = true; GriefEnv.Camera.CameraType = Enum.CameraType.Scriptable
    local rx, ry, _ = GriefEnv.Camera.CFrame:ToEulerAnglesYXZ(); State.CamPitch = rx; State.CamYaw = ry
    State.MouseSphere = Instance.new("Part"); State.MouseSphere.Name = "FreecamAuraSphere"; State.MouseSphere.Shape = Enum.PartType.Ball; State.MouseSphere.Anchored = true
    State.MouseSphere.CanCollide = false; State.MouseSphere.CanQuery = false; State.MouseSphere.CanTouch = false; State.MouseSphere.CastShadow = false
    State.MouseSphere.Material = Enum.Material.ForceField; State.MouseSphere.Transparency = 0.55; State.MouseSphere.Parent = workspace
    State.FreecamCon = GriefEnv.RunService.RenderStepped:Connect(function(dt)
        if not Funcs.isMethodAuraActive() or _G.AuraMethod ~= "Freecam" then Funcs.stopFreecam(); return end
        if GriefEnv.UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
            GriefEnv.UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition; local delta = GriefEnv.UserInputService:GetMouseDelta(); State.CamYaw = State.CamYaw - delta.X * 0.003; State.CamPitch = math.clamp(State.CamPitch - delta.Y * 0.003, -math.rad(89), math.rad(89))
        else GriefEnv.UserInputService.MouseBehavior = Enum.MouseBehavior.Default end
        local rotCF = CFrame.fromEulerAnglesYXZ(State.CamPitch, State.CamYaw, 0); local move = Vector3.zero
        if GriefEnv.UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + rotCF.LookVector end
        if GriefEnv.UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - rotCF.LookVector end
        if GriefEnv.UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + rotCF.RightVector end
        if GriefEnv.UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - rotCF.RightVector end
        if GriefEnv.UserInputService:IsKeyDown(Enum.KeyCode.E) or GriefEnv.UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
        if GriefEnv.UserInputService:IsKeyDown(Enum.KeyCode.Q) or GriefEnv.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move = move - Vector3.new(0, 1, 0) end
        local mult = GriefEnv.UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 2.5 or 1; if move.Magnitude > 0 then move = move.Unit end
        GriefEnv.Camera.CFrame = CFrame.new(GriefEnv.Camera.CFrame.Position + (move * State.FreecamSpeed * mult * dt)) * rotCF
        local spherePos = Funcs.getMouseTargetPos()
        if State.MouseSphere then local fillCol, _ = Funcs.getActiveAuraColors(); local diam = _G.AuraRange * 2; State.MouseSphere.Color = fillCol; State.MouseSphere.Size = Vector3.new(diam, diam, diam); State.MouseSphere.Position = spherePos end
        local root = Funcs.gcp("hrp"); if root and State.SavedRootCFrame then root.Velocity = Vector3.zero; root.RotVelocity = Vector3.zero; root.CFrame = State.SavedRootCFrame end
    end)
    return true
end

Funcs.stopFreecam = function()
    if not State.FreecamActive then return end; State.FreecamActive = false
    if State.FreecamCon then State.FreecamCon:Disconnect(); State.FreecamCon = nil end
    if State.MouseSphere then State.MouseSphere:Destroy(); State.MouseSphere = nil end
    GriefEnv.UserInputService.MouseBehavior = Enum.MouseBehavior.Default; GriefEnv.Camera.CameraType = Enum.CameraType.Custom
    local hum = Funcs.gcp("hum"); if hum then GriefEnv.Camera.CameraSubject = hum end
    local root = Funcs.gcp("hrp"); if root and State.SavedRootCFrame then root.Velocity = Vector3.zero; root.RotVelocity = Vector3.zero; root.CFrame = State.SavedRootCFrame; State.SavedRootCFrame = nil end
end

Funcs.stopAura = function(name)
    if State.auraTasks[name] then task.cancel(State.auraTasks[name]); State.auraTasks[name] = nil end
    if not Funcs.isMethodAuraActive() then Funcs.stopFreecam() end
    if not Funcs.isAnyAuraRunning() then
        Funcs.clearHighlights()
        Funcs.setGridVisible(false)
        table.clear(State.ProcessedBricks)
        table.clear(State.ProcessedVoxels)
        Funcs.restoreAllTools()
    end
end

Funcs.runBrickAura = function(auraKey, isRunningFn, toolName, filterFn, fireAction)
    local initTools = Funcs.findbtools(toolName); if #initTools == 0 then Funcs.safenotify("Tool Missing", toolName .. " tool not found!", 3, "alert"); return false end
    State.auraTasks[auraKey] = task.spawn(function()
        local dti = 0
        local lastRefreshTime = tick()
        if toolName == "Delete" and shared.DeleteToolRefresh then pcall(shared.DeleteToolRefresh) end

        while isRunningFn() do
            local hrp = Funcs.gcp("hrp")
            if not hrp then task.wait(); continue end

            local dtools = Funcs.findbtools(toolName)
            if #dtools > 0 then
                local method = _G.AuraMethod
                if method == "Freecam" then
                    if not Funcs.startFreecam() then method = "Range" end
                else
                    if State.FreecamActive then Funcs.stopFreecam() end
                end

                local targetOrigin = hrp.Position
                local respectRange = true
                local limit = 50
                if method == "Freecam" and State.MouseSphere then
                    targetOrigin = State.MouseSphere.Position
                    respectRange = true
                elseif method == "Inf Range" then
                    targetOrigin = hrp.Position
                    respectRange = false
                    limit = nil
                end

                local targetBlocks = Funcs.getclosestcubes(targetOrigin, limit, false, filterFn, respectRange)
                if #targetBlocks > 0 then
                    if toolName == "Delete" and tick() - lastRefreshTime >= 5 then
                        if shared.DeleteToolRefresh then pcall(shared.DeleteToolRefresh) end
                        lastRefreshTime = tick()
                    end

                    local fillCol, outCol = Funcs.getActiveAuraColors()
                    for i = 1, #targetBlocks do
                        if not isRunningFn() then break end
                        hrp = Funcs.gcp("hrp"); if not hrp then break end
                        local block = targetBlocks[i][1]
                        if block and block:IsDescendantOf(workspace) then
                            Funcs.highlightBrick(block, fillCol, outCol)
                            dti = dti + 1
                            local dt = dtools[(dti % #dtools) + 1]
                            Funcs.checktool(dt.bt)
                            local firePos = State.isog and block.Position or hrp.Position
                            pcall(function()
                                fireAction(dt.e, block, firePos)
                            end)
                            task.wait(State.ws / #dtools)
                            Funcs.clearBrickHighlight(block)
                        else
                            Funcs.clearBrickHighlight(block)
                        end
                    end
                else
                    Funcs.clearHighlights()
                    task.wait(0.1)
                end
            else
                task.wait(0.5)
            end
            task.wait()
        end
    end)
    return true
end

GriefEnv.RunService.RenderStepped:Connect(function()
    local activePositions = {}
    for brick, hl in pairs(State.DeleteAuraHighlights) do
        if not brick or not brick.Parent or not brick:IsDescendantOf(workspace) or not hl or not hl.Parent then
            if hl then pcall(function() hl:Destroy() end) end
            State.DeleteAuraHighlights[brick] = nil
        elseif _G.BlocksTracers and #activePositions < Consts.MAX_TRACERS then
            activePositions[#activePositions + 1] = brick.Position
        end
    end

    if _G.BlocksTracers and State.PreviewGhost and State.PreviewGhost.Parent == workspace and #activePositions < Consts.MAX_TRACERS then
        activePositions[#activePositions + 1] = State.PreviewGhost.Position
    end

    if not _G.BlocksTracers or not Funcs.isAnyAuraRunning() or #activePositions == 0 then
        for _, line in pairs(State.TracerPool) do if line.Visible then line.Visible = false end end
        return
    end

    local vp = GriefEnv.Camera.ViewportSize; local fromTop = Vector2.new(vp.X * 0.5, 0); local fillCol, _ = Funcs.getActiveAuraColors()
    for i = 1, Consts.MAX_TRACERS do
        local pos = activePositions[i]; local line = Funcs.getOrCreateTracer(i)
        if line then
            if pos then
                local screenVec, onScreen = GriefEnv.Camera:WorldToViewportPoint(pos)
                if onScreen and screenVec.Z > 0 then line.From = fromTop; line.To = Vector2.new(screenVec.X, screenVec.Y); line.Color = fillCol; line.Visible = true else line.Visible = false end
            else line.Visible = false end
        end
    end
end)

GriefEnv.RunService.RenderStepped:Connect(function()
    local showBorder = Funcs.isAnyAuraRunning() and (_G.AuraMethod == "Range" or not Funcs.isMethodAuraActive()); local hrp = Funcs.gcp("hrp")
    if not showBorder or not hrp then Funcs.setGridVisible(false); return end
    if State.BuiltRange ~= _G.AuraRange or State.BuiltShape ~= _G.RangeShape then Funcs.rebuildRangeGrid() end
    local fillCol, outCol = Funcs.getActiveAuraColors(); local centerPos = Vector3.new(hrp.Position.X, hrp.Position.Y - 2.95, hrp.Position.Z)
    for _, seg in ipairs(State.GridSegments) do
        local p = seg.Part; if p then p.Transparency = seg.IsBorder and 0.12 or 0.52; p.Color = seg.IsBorder and outCol or fillCol; p.CFrame = CFrame.new(centerPos + seg.Offset) * seg.Rot end
    end
end)

GriefTab:Toggle({
    Title = "loc:BUILD_AURA", Value = false,
    Callback = function(v)
        _G.BlocksAuraRunning = v; if not v then Funcs.stopAura("BlocksAura"); return end
        local initTools = Funcs.findbtools("Build"); if #initTools == 0 then Funcs.safenotify("Tool Missing", "Build tool not found!", 3, "alert"); _G.BlocksAuraRunning = false; return end
        State.auraTasks["BlocksAura"] = task.spawn(function()
            local dti = 0; local bothToggle = false
            while _G.BlocksAuraRunning do
                local hrp = Funcs.gcp("hrp"); local dtools = Funcs.findbtools("Build")
                if hrp and #dtools > 0 then
                    local fillCol, outCol = Funcs.getActiveAuraColors()
                    local activeMode = _G.BuildType
                    if activeMode == "both" then bothToggle = not bothToggle; activeMode = bothToggle and "normal" or "detailed" end
                    local previewSize = (activeMode == "detailed") and Vector3.new(1, 1, 1) or Vector3.new(4, 4, 4)
                    local targets = Funcs.getBuildSignTargets(hrp.Position, 15, activeMode)
                    if #targets > 0 then
                        for _, pos in ipairs(targets) do
                            if not _G.BlocksAuraRunning then break end
                            Funcs.showSinglePlacementPreview(CFrame.new(pos), previewSize, fillCol, outCol)
                            dti = dti + 1; local dt = dtools[(dti % #dtools) + 1]; Funcs.checktool(dt.bt)
                            pcall(function() dt.e:FireServer(workspace.Terrain, Enum.NormalId.Top, pos, activeMode) end)
                            task.wait(State.ws / #dtools)
                            Funcs.hideSinglePlacementPreview()
                            if _G.BuildType == "both" then bothToggle = not bothToggle; activeMode = bothToggle and "normal" or "detailed"; previewSize = (activeMode == "detailed") and Vector3.new(1, 1, 1) or Vector3.new(4, 4, 4) end
                        end
                    else Funcs.hideSinglePlacementPreview(); task.wait(0.05) end
                else Funcs.hideSinglePlacementPreview(); task.wait(0.5) end; task.wait()
            end
        end)
    end
})

GriefTab:Toggle({
    Title = "loc:DELETE_AURA", Value = false,
    Callback = function(v)
        _G.DeleteAuraRunning = v; if not v then Funcs.stopAura("DeleteAura"); return end
        local ok = Funcs.runBrickAura("DeleteAura", function() return _G.DeleteAuraRunning end, "Delete", nil, function(remote, brick, firePos)
            if State.isog then remote:FireServer(firePos, Enum.NormalId.Top, brick, Color3.new(0, 0, 0), "Smooth") else remote:FireServer(brick, firePos) end
        end)
        if not ok then _G.DeleteAuraRunning = false end
    end
})

GriefTab:Toggle({
    Title = "loc:UNANCHOR_AURA", Value = false,
    Callback = function(v)
        _G.UnanchorAuraRunning = v; if not v then Funcs.stopAura("UnanchorAura"); return end
        local ok = Funcs.runBrickAura("UnanchorAura", function() return _G.UnanchorAuraRunning end, "Paint", function(brick) return brick.Anchored == true end, function(remote, brick, firePos)
            remote:FireServer(brick, Enum.NormalId.Top, firePos, "material", _G.PaintColor, "anchor", "")
        end)
        if not ok then _G.UnanchorAuraRunning = false end
    end
})

GriefTab:Toggle({
    Title = "loc:TOXIC_AURA", Value = false,
    Callback = function(v)
        _G.ToxicAuraRunning = v; if not v then Funcs.stopAura("ToxicAura"); return end
        local ok = Funcs.runBrickAura("ToxicAura", function() return _G.ToxicAuraRunning end, "Paint", nil, function(remote, brick, firePos)
            remote:FireServer(brick, Enum.NormalId.Top, firePos, "material", _G.PaintColor, "toxic", "")
        end)
        if not ok then _G.ToxicAuraRunning = false end
    end
})

GriefTab:Toggle({
    Title = "loc:MATERIAL_AURA", Value = false,
    Callback = function(v)
        _G.MaterialAuraRunning = v; if not v then Funcs.stopAura("MaterialAura"); return end
        local ok = Funcs.runBrickAura("MaterialAura", function() return _G.MaterialAuraRunning end, "Paint", function(brick)
            local matInfo = Consts.MaterialLookup[_G.MaterialType]
            return matInfo and brick.Material.Name ~= matInfo.Name
        end, function(remote, brick, firePos)
            local matInfo = Consts.MaterialLookup[_G.MaterialType]
            if matInfo then remote:FireServer(brick, Enum.NormalId.Top, firePos, "material", _G.PaintColor, matInfo.Arg, "") end
        end)
        if not ok then _G.MaterialAuraRunning = false end
    end
})

GriefTab:Toggle({
    Title = "loc:PAINT_AURA", Value = false,
    Callback = function(v)
        _G.PaintAuraRunning = v; if not v then Funcs.stopAura("PaintAura"); return end
        local ok = Funcs.runBrickAura("PaintAura", function() return _G.PaintAuraRunning end, "Paint", function(brick) return brick.Color ~= _G.PaintColor end, function(remote, brick, firePos)
            remote:FireServer(brick, Enum.NormalId.Top, firePos, "color", _G.PaintColor, "tiles", "")
        end)
        if not ok then _G.PaintAuraRunning = false end
    end
})

GriefTab:Toggle({
    Title = "loc:SHOVEL_AURA", Value = false,
    Callback = function(v)
        _G.ShovelAuraRunning = v; if not v then Funcs.stopAura("ShovelAura"); return end
        local initTools = Funcs.findbtools("Shovel"); if #initTools == 0 then Funcs.safenotify("Tool Missing", "Shovel tool not found!", 3, "alert"); _G.ShovelAuraRunning = false; return end
        State.auraTasks["ShovelAura"] = task.spawn(function()
            local dti = 0
            while _G.ShovelAuraRunning do
                local hrp = Funcs.gcp("hrp"); local dtools = Funcs.findbtools("Shovel")
                if hrp and #dtools > 0 then
                    local voxelTargets = Funcs.getUnderPlayerTerrainVoxels(hrp.Position, 25); local fillCol, outCol = Funcs.getActiveAuraColors()
                    if #voxelTargets > 0 then
                        for _, vox in ipairs(voxelTargets) do
                            if not _G.ShovelAuraRunning then break end
                            Funcs.showSinglePlacementPreview(CFrame.new(vox.Pos), Vector3.new(4, 4, 4), fillCol, outCol)
                            dti = dti + 1; local dt = dtools[(dti % #dtools) + 1]; Funcs.checktool(dt.bt)
                            pcall(function() dt.e:FireServer(workspace.Terrain, Enum.NormalId.Top, vox.Pos, _G.ShovelType) end)
                            State.ProcessedVoxels[vox.Key] = tick() + 0.15
                            task.wait(State.ws / #dtools)
                            Funcs.hideSinglePlacementPreview()
                        end
                    else Funcs.hideSinglePlacementPreview(); Funcs.clearAllTracers(); task.wait(0.05) end
                else Funcs.hideSinglePlacementPreview(); task.wait(0.5) end; task.wait()
            end
        end)
    end
})

GriefTab:Toggle({
    Title = "loc:SIGN_AURA", Value = false,
    Callback = function(v)
        _G.SignAuraRunning = v; if not v then Funcs.stopAura("SignAura"); return end
        local initTools = Funcs.findbtools("Sign"); if #initTools == 0 then Funcs.safenotify("Tool Missing", "Sign tool not found!", 3, "alert"); _G.SignAuraRunning = false; return end
        State.auraTasks["SignAura"] = task.spawn(function()
            local dti = 0
            while _G.SignAuraRunning do
                local hrp = Funcs.gcp("hrp"); local dtools = Funcs.findbtools("Sign")
                if hrp and #dtools > 0 then
                    local fillCol, outCol = Funcs.getActiveAuraColors()
                    local targets = Funcs.getBuildSignTargets(hrp.Position, 15, "normal")
                    if #targets > 0 then
                        for _, pos in ipairs(targets) do
                            if not _G.SignAuraRunning then break end
                            Funcs.showSinglePlacementPreview(CFrame.new(pos), Vector3.new(3.2, 2.6, 0.6), fillCol, outCol)
                            dti = dti + 1; local dt = dtools[(dti % #dtools) + 1]; Funcs.checktool(dt.bt)
                            pcall(function() dt.e:FireServer(workspace.Terrain, Enum.NormalId.Top, pos) end)
                            task.wait(State.ws / #dtools)
                            Funcs.hideSinglePlacementPreview()
                        end
                    else Funcs.hideSinglePlacementPreview(); task.wait(0.05) end
                else Funcs.hideSinglePlacementPreview(); task.wait(0.5) end; task.wait()
            end
        end)
    end
})

GriefTab:Divider()
GriefTab:Section({Title = "loc:GRIEF_GUARD", Icon = "circle-alert"})
HX.loadStage(HX.stageLabel("ANTIS_TAB"), 0.67)
local AntisTab = Window:Tab({
    Title = "loc:ANTIS_TAB", 
    Icon = "shield-check", 
    Locked = false
})

local antiConnections = {}
local function UpdateConnection(name, conn)
    if antiConnections[name] then
        if type(antiConnections[name]) == "table" then
            for _, c in ipairs(antiConnections[name]) do
                pcall(function() c:Disconnect() end)
            end
        else
            pcall(function() antiConnections[name]:Disconnect() end)
        end
        antiConnections[name] = nil
    end
    if conn then
        antiConnections[name] = conn
    end
end

local resetReturnMode = "None"
local savedCollisionGroups = {}
local isUpdatingCollision = false

local bodyPartNames = {
    HumanoidRootPart = true,
    Torso = true,
    UpperTorso = true,
    LowerTorso = true,
    Head = true,
    ["Left Arm"] = true,
    ["Right Arm"] = true,
    ["Left Leg"] = true,
    ["Right Leg"] = true,
    LeftUpperArm = true,
    RightUpperArm = true,
    LeftLowerArm = true,
    RightLowerArm = true,
    LeftHand = true,
    RightHand = true,
    LeftUpperLeg = true,
    RightUpperLeg = true,
    LeftLowerLeg = true,
    RightLowerLeg = true,
    LeftFoot = true,
    RightFoot = true
}

local coreCollideParts = {
    Torso = true,
    UpperTorso = true,
    LowerTorso = true,
    Head = true
}

local function isGrounded(char, root, hum)
    if not char or not root then return false end
    if hum and hum.FloorMaterial == Enum.Material.Air then
        return false
    end
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {char}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local result = workspace:Raycast(root.Position, Vector3.new(0, -12, 0), rayParams)
    return result ~= nil
end

local function isSpawnLastPosEnabled()
    return resetReturnMode == "SpawnLastPosition" 
        or resetReturnMode == "loc:RESET_OPT_SPAWN_LAST_POS_TITLE" 
        or resetReturnMode == "Spawn Last Position"
end

AntisTab:Section({
    Title = "loc:ANTIS_SEC_CHAR_PROT_TITLE", 
    Icon = "user-check",
    Desc = "loc:ANTIS_SEC_CHAR_PROT_DESC"
})

AntisTab:Space()

AntisTab:Toggle({
    Title = "loc:ANTI_DRAG_TITLE",
    Desc = "loc:ANTI_DRAG_DESC",
    Value = false,
    Callback = function(value)
        WindUI:Notify({
            Title = "loc:ANTI_DRAG_TITLE",
            Content = value and "loc:ANTI_DRAG_NOTIFY_ON" or "loc:ANTI_DRAG_NOTIFY_OFF",
            Icon = value and "check-circle" or "x-circle",
            Duration = 3
        })
        if value then
            local conns = {}
            local function handleBadState(humanoid, char, newState)
                if lp:GetAttribute("Flying") == true or _G.Fly == true then return end
                if newState == Enum.HumanoidStateType.Ragdoll or 
                   newState == Enum.HumanoidStateType.FallingDown or 
                   newState == Enum.HumanoidStateType.PlatformStanding or
                   newState == Enum.HumanoidStateType.Seated then
                    humanoid.Sit = false
                    humanoid.PlatformStand = false
                    humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                    if char and char:FindFirstChild("HumanoidRootPart") then
                        char.HumanoidRootPart.Anchored = false
                    end
                end
            end

            local function hookChar(char)
                if not char then return end
                local humanoid = char:FindFirstChildWhichIsA("Humanoid") or char:WaitForChild("Humanoid", 3)
                if not humanoid then return end
                if lp:GetAttribute("Flying") ~= true and _G.Fly ~= true then
                    humanoid.Sit = false
                    handleBadState(humanoid, char, humanoid:GetState())
                end
                table.insert(conns, humanoid.StateChanged:Connect(function(_, newState)
                    handleBadState(humanoid, char, newState)
                end))
            end

            if lp.Character then
                hookChar(lp.Character)
            end
            table.insert(conns, lp.CharacterAdded:Connect(hookChar))

            for _, seat in pairs(workspace:GetDescendants()) do
                if seat:IsA("Seat") or seat:IsA("VehicleSeat") then
                    table.insert(conns, seat:GetPropertyChangedSignal("Occupant"):Connect(function()
                        if lp:GetAttribute("Flying") == true or _G.Fly == true then return end
                        local hum = lp.Character and lp.Character:FindFirstChildWhichIsA("Humanoid")
                        if hum and seat.Occupant == hum then
                            task.wait(0.01)
                            hum.Sit = false
                            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                        end
                    end))
                end
            end

            table.insert(conns, game:GetService("RunService").PreSimulation:Connect(function()
                if lp:GetAttribute("Flying") == true or _G.Fly == true then
                    return
                end
                local char = lp.Character
                if char then
                    local Dragger = char:FindFirstChild("Dragger")
                    local Humanoid = char:FindFirstChildWhichIsA("Humanoid")
                    if Dragger then
                        Dragger.ResponseStyle = Enum.DragDetectorResponseStyle.Custom
                    end
                    if Humanoid then
                        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
                        Humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
                        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
                        Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                        if Humanoid.Sit or Humanoid.PlatformStand then
                            Humanoid.Sit = false
                            Humanoid.PlatformStand = false
                            Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                        end
                        local state = Humanoid:GetState()
                        if state == Enum.HumanoidStateType.Seated or state == Enum.HumanoidStateType.PlatformStanding or state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown then
                            Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                        end
                        local seatPart = Humanoid.SeatPart
                        if seatPart then
                            local weld = seatPart:FindFirstChild("SeatWeld")
                            if weld then
                                weld:Destroy()
                            end
                        end
                    end
                end
            end))
            UpdateConnection("AntiDrag", conns)
        else
            UpdateConnection("AntiDrag", nil)
            if lp.Character then
                local Humanoid = lp.Character:FindFirstChildWhichIsA("Humanoid")
                if Humanoid then
                    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
                    Humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, true)
                    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
                    Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
                end
            end
        end
    end
})

AntisTab:Toggle({
    Title = "loc:ANTI_VAMPIRE_TITLE",
    Desc = "loc:ANTI_VAMPIRE_DESC",
    Value = false,
    Callback = function(value)
        WindUI:Notify({
            Title = "loc:ANTI_VAMPIRE_TITLE",
            Content = value and "loc:ANTI_VAMPIRE_NOTIFY_ON" or "loc:ANTI_VAMPIRE_NOTIFY_OFF",
            Icon = value and "droplets" or "x-circle",
            Duration = 3
        })
        if value then
            local connection = game:GetService("RunService").Heartbeat:Connect(function()
                if lp.Character then
                    local humanoid = lp.Character:FindFirstChild("Humanoid")
                    if humanoid and humanoid.Health > 0 then
                        pcall(function()
                            game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
                        end)
                        if workspace.CurrentCamera then
                            workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
                            workspace.CurrentCamera.CameraSubject = humanoid
                        end
                    end
                end
            end)
            UpdateConnection("AntiVampire", connection)
        else
            UpdateConnection("AntiVampire", nil)
        end
    end
})

AntisTab:Toggle({
    Title = "loc:ANTI_FLING_TITLE",
    Desc = "loc:ANTI_FLING_DESC",
    Value = false,
    Callback = function(value)
        WindUI:Notify({
            Title = "loc:ANTI_FLING_TITLE",
            Content = value and "loc:ANTI_FLING_NOTIFY_ON" or "loc:ANTI_FLING_NOTIFY_OFF",
            Icon = value and "wind" or "x-circle",
            Duration = 3
        })
        if value then
            local connection = game:GetService("RunService").Stepped:Connect(function()
                for _, player in pairs(game:GetService("Players"):GetPlayers()) do
                    if player ~= lp and player.Character then
                        for _, v in pairs(player.Character:GetDescendants()) do
                            if v:IsA("BasePart") then
                                v.CanCollide = false
                            end
                        end
                    end
                end
            end)
            UpdateConnection("AntiFling", connection)
        else
            UpdateConnection("AntiFling", nil)
        end
    end
})

AntisTab:Toggle({
    Title = "loc:ANTI_TELEPORT_TITLE",
    Desc = "loc:ANTI_TELEPORT_DESC",
    Value = false,
    Callback = function(value)
        WindUI:Notify({
            Title = "loc:ANTI_TELEPORT_TITLE",
            Content = value and "loc:ANTI_TELEPORT_NOTIFY_ON" or "loc:ANTI_TELEPORT_NOTIFY_OFF",
            Icon = value and "globe" or "x-circle",
            Duration = 3
        })
        if value then
            local savedCF = nil
            local savedCamCF = nil
            local connection = game:GetService("RunService").PreSimulation:Connect(function()
                if lp.Character then
                    local root = lp.Character:FindFirstChild("HumanoidRootPart")
                    if root then
                        local cam = workspace.CurrentCamera
                        if savedCF then
                            local distance = (root.Position - savedCF.Position).Magnitude
                            if distance > 15 then
                                lp.Character:PivotTo(savedCF)
                                root.CFrame = savedCF
                                root.Velocity = Vector3.new(0, 0, 0)
                                root.RotVelocity = Vector3.new(0, 0, 0)
                                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                                root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                                for _, v in ipairs(lp.Character:GetDescendants()) do
                                    if v:IsA("BasePart") then
                                        v.Velocity = Vector3.new(0, 0, 0)
                                        v.RotVelocity = Vector3.new(0, 0, 0)
                                        v.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                                        v.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                                    end
                                end
                                if cam and savedCamCF then
                                    cam.CFrame = savedCamCF
                                end
                                return
                            end
                        end
                        savedCF = root.CFrame
                        if cam then
                            savedCamCF = cam.CFrame
                        end
                    end
                end
            end)
            UpdateConnection("AntiTeleport", connection)
        else
            UpdateConnection("AntiTeleport", nil)
        end
    end
})

AntisTab:Toggle({
    Title = "loc:ANTI_GLITCH_TITLE",
    Desc = "loc:ANTI_GLITCH_DESC",
    Value = false,
    Callback = function(value)
        WindUI:Notify({
            Title = "loc:ANTI_GLITCH_TITLE",
            Content = value and "loc:ANTI_GLITCH_NOTIFY_ON" or "loc:ANTI_GLITCH_NOTIFY_OFF",
            Icon = value and "alert-octagon" or "x-circle",
            Duration = 3
        })
        if value then
            local savedCF = nil
            local savedCamCF = nil
            local connection = game:GetService("RunService").PreSimulation:Connect(function()
                if lp.Character then
                    local root = lp.Character:FindFirstChild("HumanoidRootPart")
                    if root then
                        local pos = root.Position
                        local vel = root.AssemblyLinearVelocity
                        local cam = workspace.CurrentCamera
                        if math.abs(pos.X) > 10000 or math.abs(pos.Y) > 10000 or math.abs(pos.Z) > 10000 or vel.Magnitude > 5000 then
                            if savedCF then
                                lp.Character:PivotTo(savedCF)
                                root.CFrame = savedCF
                            end
                            root.Velocity = Vector3.new(0, 0, 0)
                            root.RotVelocity = Vector3.new(0, 0, 0)
                            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                            root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                            for _, v in ipairs(lp.Character:GetDescendants()) do
                                if v:IsA("BasePart") then
                                    v.Velocity = Vector3.new(0, 0, 0)
                                    v.RotVelocity = Vector3.new(0, 0, 0)
                                    v.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                                    v.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                                end
                            end
                            if cam and savedCamCF then
                                cam.CFrame = savedCamCF
                            end
                            return
                        end
                        savedCF = root.CFrame
                        if cam then
                            savedCamCF = cam.CFrame
                        end
                    end
                end
            end)
            UpdateConnection("AntiGlitch", connection)
        else
            UpdateConnection("AntiGlitch", nil)
        end
    end
})

AntisTab:Toggle({
    Title = "loc:ANTI_NOCLIP_TITLE",
    Desc = "loc:ANTI_NOCLIP_DESC",
    Value = false,
    Callback = function(value)
        WindUI:Notify({
            Title = "loc:ANTI_NOCLIP_TITLE",
            Content = value and "loc:ANTI_NOCLIP_NOTIFY_ON" or "loc:ANTI_NOCLIP_NOTIFY_OFF",
            Icon = value and "shield" or "x-circle",
            Duration = 3
        })
        if value then
            savedCollisionGroups = {}
            local conns = {}

            local function trackPart(part)
                if not part:IsA("BasePart") or not bodyPartNames[part.Name] then return end
                if savedCollisionGroups[part] == nil then
                    savedCollisionGroups[part] = part.CollisionGroup
                end
                if part.CollisionGroup == "NoClip" then
                    isUpdatingCollision = true
                    part.CollisionGroup = "Default"
                    isUpdatingCollision = false
                end
                table.insert(conns, part:GetPropertyChangedSignal("CollisionGroup"):Connect(function()
                    if isUpdatingCollision then return end
                    savedCollisionGroups[part] = part.CollisionGroup
                    if part.CollisionGroup == "NoClip" then
                        isUpdatingCollision = true
                        part.CollisionGroup = "Default"
                        isUpdatingCollision = false
                    end
                end))
            end

            local function setupChar(char)
                savedCollisionGroups = {}
                if not char then return end
                for _, v in pairs(char:GetChildren()) do
                    trackPart(v)
                end
                table.insert(conns, char.ChildAdded:Connect(trackPart))
            end

            if lp.Character then
                setupChar(lp.Character)
            end
            table.insert(conns, lp.CharacterAdded:Connect(setupChar))

            table.insert(conns, game:GetService("RunService").Stepped:Connect(function()
                local char = lp.Character
                if not char then return end
                local hum = char:FindFirstChildOfClass("Humanoid")
                local isAlive = hum and hum.Health > 0 and hum:GetState() ~= Enum.HumanoidStateType.Dead

                for _, v in pairs(char:GetChildren()) do
                    if v:IsA("BasePart") and bodyPartNames[v.Name] then
                        if savedCollisionGroups[v] == nil then
                            savedCollisionGroups[v] = v.CollisionGroup
                        end
                        if v.CollisionGroup == "NoClip" then
                            savedCollisionGroups[v] = "NoClip"
                            isUpdatingCollision = true
                            v.CollisionGroup = "Default"
                            isUpdatingCollision = false
                        end
                        if isAlive and coreCollideParts[v.Name] and savedCollisionGroups[v] == "NoClip" then
                            v.CanCollide = true
                        end
                    end
                end
            end))

            UpdateConnection("AntiNoclip", conns)
        else
            UpdateConnection("AntiNoclip", nil)
            if lp.Character then
                isUpdatingCollision = true
                for part, origGroup in pairs(savedCollisionGroups) do
                    if part and part.Parent == lp.Character and part:IsA("BasePart") then
                        part.CollisionGroup = origGroup
                    end
                end
                isUpdatingCollision = false
            end
            savedCollisionGroups = {}
        end
    end
})

AntisTab:Toggle({
    Title = "loc:ANTI_FLY_TITLE",
    Desc = "loc:ANTI_FLY_DESC",
    Value = false,
    Callback = function(value)
        WindUI:Notify({
            Title = "loc:ANTI_FLY_TITLE",
            Content = value and "loc:ANTI_FLY_NOTIFY_ON" or "loc:ANTI_FLY_NOTIFY_OFF",
            Icon = value and "wind" or "x-circle",
            Duration = 3
        })
        if value then
            local connection = game:GetService("RunService").Heartbeat:Connect(function()
                lp:SetAttribute("Flying", false)
            end)
            UpdateConnection("AntiFly", connection)
        else
            UpdateConnection("AntiFly", nil)
        end
    end
})

AntisTab:Toggle({
    Title = "loc:ANTI_JAIL_TITLE",
    Desc = "loc:ANTI_JAIL_DESC",
    Value = false,
    Callback = function(value)
        WindUI:Notify({
            Title = "loc:ANTI_JAIL_TITLE",
            Content = value and "loc:ANTI_JAIL_NOTIFY_ON" or "loc:ANTI_JAIL_NOTIFY_OFF",
            Icon = value and "lock" or "x-circle",
            Duration = 3
        })
        if value then
            local connection = game:GetService("RunService").Stepped:Connect(function()
                if lp.Character and lp.Character:FindFirstChild("Jail") then
                    for _, v in pairs(lp.Character.Jail:GetChildren()) do
                        if v:IsA("BasePart") then
                            v.CanCollide = false
                        end
                    end
                end
            end)
            UpdateConnection("AntiJail", connection)
        else
            UpdateConnection("AntiJail", nil)
        end
    end
})

AntisTab:Toggle({
    Title = "loc:ANTI_AFK_TITLE",
    Desc = "loc:ANTI_AFK_DESC",
    Value = false,
    Callback = function(value)
        WindUI:Notify({
            Title = "loc:ANTI_AFK_TITLE",
            Content = value and "loc:ANTI_AFK_NOTIFY_ON" or "loc:ANTI_AFK_NOTIFY_OFF",
            Icon = value and "clock" or "x-circle",
            Duration = 3
        })
        _G.AntiAFKLoop = value
        if value then
            if getconnections then
                for _, c in pairs(getconnections(lp.Idled)) do
                    pcall(function() c:Disable() end)
                    pcall(function() c:Disconnect() end)
                end
            end
            local connection = lp.Idled:Connect(function()
                pcall(function()
                    local VirtualInputManager = Instance.new("VirtualInputManager")
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
                    VirtualInputManager:Destroy()
                end)
            end)
            UpdateConnection("AntiAFK", connection)
            task.spawn(function()
                while _G.AntiAFKLoop do
                    task.wait()
                    pcall(function()
                        local Event = game:GetService("ReplicatedStorage"):FindFirstChild("System")
                        if Event then
                            Event:FireServer("Focused")
                        end
                    end)
                end
            end)
        else
            UpdateConnection("AntiAFK", nil)
        end
    end
})

AntisTab:Space()
AntisTab:Divider()
AntisTab:Space()

AntisTab:Section({
    Title = "loc:ANTIS_SEC_RESET_PROT_TITLE", 
    Icon = "refresh-cw",
    Desc = "loc:ANTIS_SEC_RESET_PROT_DESC"
})

AntisTab:Space()

AntisTab:Dropdown({
    Title = "loc:RESET_MODE_DROPDOWN_TITLE",
    Desc = "loc:RESET_MODE_DROPDOWN_DESC",
    Multi = false,
    Values = {
        {
            Title = "loc:RESET_OPT_NONE_TITLE",
            Desc = "loc:RESET_OPT_NONE_DESC",
            Icon = "slash",
            Value = "None"
        },
        {
            Type = "Divider"
        },
        {
            Title = "loc:RESET_OPT_SPAWN_LAST_POS_TITLE",
            Desc = "loc:RESET_OPT_SPAWN_LAST_POS_DESC",
            Icon = "map-pin",
            Value = "SpawnLastPosition"
        }
    },
    Callback = function(value)
        if type(value) == "table" then
            resetReturnMode = value.Value or value.Title or "None"
        elseif type(value) == "string" then
            resetReturnMode = value
        end
    end
})

AntisTab:Toggle({
    Title = "loc:ANTI_FREEZE_TITLE",
    Desc = "loc:ANTI_FREEZE_DESC",
    Value = false,
    Callback = function(value)
        WindUI:Notify({
            Title = "loc:ANTI_FREEZE_TITLE",
            Content = value and "loc:ANTI_FREEZE_NOTIFY_ON" or "loc:ANTI_FREEZE_NOTIFY_OFF",
            Icon = value and "snowflake" or "x-circle",
            Duration = 3
        })
        if value then
            local savedCF = nil
            local savedCamCF = nil
            local respawnCF = nil
            local respawnCamCF = nil
            local resetting = false
            local conns = {}

            table.insert(conns, lp.CharacterAdded:Connect(function(newChar)
                if respawnCF and isSpawnLastPosEnabled() then
                    local targetCF = respawnCF
                    local targetCamCF = respawnCamCF
                    respawnCF = nil
                    respawnCamCF = nil
                    task.spawn(function()
                        local root = newChar:WaitForChild("HumanoidRootPart", 5)
                        if root then
                            task.wait()
                            newChar:PivotTo(targetCF)
                            root.CFrame = targetCF
                            if workspace.CurrentCamera and targetCamCF then
                                workspace.CurrentCamera.CFrame = targetCamCF
                            end
                        end
                        resetting = false
                    end)
                else
                    respawnCF = nil
                    respawnCamCF = nil
                    resetting = false
                end
            end))

            table.insert(conns, game:GetService("RunService").Heartbeat:Connect(function()
                local char = lp.Character
                if char then
                    local root = char:FindFirstChild("HumanoidRootPart")
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    local cam = workspace.CurrentCamera
                    local isFrozen = false

                    local character = workspace:FindFirstChild(lp.Name)
                    if character and character:FindFirstChild("Hielo") then
                        isFrozen = true
                    end
                    if char:FindFirstChild("Hielo") or char:FindFirstChild("Freeze") or char:FindFirstChild("Ice") then
                        isFrozen = true
                    end
                    if root and root.Anchored == true and lp:GetAttribute("Flying") ~= true and _G.Fly ~= true then
                        isFrozen = true
                    end

                    if isFrozen and hum and hum.Health > 0 then
                        if not resetting then
                            resetting = true
                            if isSpawnLastPosEnabled() and savedCF then
                                respawnCF = savedCF
                                respawnCamCF = savedCamCF
                            else
                                respawnCF = nil
                                respawnCamCF = nil
                            end
                            hum.Health = 0
                            hum:ChangeState(Enum.HumanoidStateType.Dead)
                        end
                    elseif root and hum and hum.Health > 0 and not resetting then
                        if isGrounded(char, root, hum) then
                            savedCF = root.CFrame
                            if cam then
                                savedCamCF = cam.CFrame
                            end
                        end
                    end
                end
            end))
            UpdateConnection("AntiFreeze", conns)
        else
            UpdateConnection("AntiFreeze", nil)
        end
    end
})

AntisTab:Toggle({
    Title = "loc:ANTI_INVISIBLE_TITLE",
    Desc = "loc:ANTI_INVISIBLE_DESC",
    Value = false,
    Callback = function(value)
        WindUI:Notify({
            Title = "loc:ANTI_INVISIBLE_TITLE",
            Content = value and "loc:ANTI_INVISIBLE_NOTIFY_ON" or "loc:ANTI_INVISIBLE_NOTIFY_OFF",
            Icon = value and "eye-off" or "x-circle",
            Duration = 3
        })
        if value then
            local savedCF = nil
            local savedCamCF = nil
            local respawnCF = nil
            local respawnCamCF = nil
            local resetting = false
            local conns = {}

            table.insert(conns, lp.CharacterAdded:Connect(function(newChar)
                if respawnCF and isSpawnLastPosEnabled() then
                    local targetCF = respawnCF
                    local targetCamCF = respawnCamCF
                    respawnCF = nil
                    respawnCamCF = nil
                    task.spawn(function()
                        local root = newChar:WaitForChild("HumanoidRootPart", 5)
                        if root then
                            task.wait()
                            newChar:PivotTo(targetCF)
                            root.CFrame = targetCF
                            if workspace.CurrentCamera and targetCamCF then
                                workspace.CurrentCamera.CFrame = targetCamCF
                            end
                        end
                        resetting = false
                    end)
                else
                    respawnCF = nil
                    respawnCamCF = nil
                    resetting = false
                end
            end))

            table.insert(conns, game:GetService("RunService").Heartbeat:Connect(function()
                local char = lp.Character
                if char then
                    local root = char:FindFirstChild("HumanoidRootPart")
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    local head = char:FindFirstChild("Head")
                    local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
                    local cam = workspace.CurrentCamera
                    local isHidden = false

                    if not char:IsDescendantOf(workspace) then
                        isHidden = true
                    end
                    if torso and (torso.Transparency >= 0.9 or torso.LocalTransparencyModifier >= 0.9) then
                        isHidden = true
                    end
                    if head and head.Transparency >= 0.9 and (not torso or torso.Transparency >= 0.9) then
                        isHidden = true
                    end
                    if root and not torso and not head then
                        isHidden = true
                    end

                    if isHidden and hum and hum.Health > 0 then
                        if not resetting then
                            resetting = true
                            if isSpawnLastPosEnabled() and savedCF then
                                respawnCF = savedCF
                                respawnCamCF = savedCamCF
                            else
                                respawnCF = nil
                                respawnCamCF = nil
                            end
                            hum.Health = 0
                            hum:ChangeState(Enum.HumanoidStateType.Dead)
                        end
                    elseif root and hum and hum.Health > 0 and not resetting then
                        if isGrounded(char, root, hum) then
                            savedCF = root.CFrame
                            if cam then
                                savedCamCF = cam.CFrame
                            end
                        end
                    end
                end
            end))
            UpdateConnection("AntiInvisible", conns)
        else
            UpdateConnection("AntiInvisible", nil)
        end
    end
})

AntisTab:Toggle({
    Title = "loc:ANTI_MAPTIDE_TITLE",
    Desc = "loc:ANTI_MAPTIDE_DESC",
    Value = false,
    Callback = function(value)
        WindUI:Notify({
            Title = "loc:ANTI_MAPTIDE_TITLE",
            Content = value and "loc:ANTI_MAPTIDE_NOTIFY_ON" or "loc:ANTI_MAPTIDE_NOTIFY_OFF",
            Icon = value and "mountain" or "x-circle",
            Duration = 3
        })
        if value then
            local savedCF = nil
            local savedCamCF = nil
            local respawnCF = nil
            local respawnCamCF = nil
            local conns = {}

            table.insert(conns, lp.CharacterAdded:Connect(function(newChar)
                if respawnCF and isSpawnLastPosEnabled() then
                    local targetCF = respawnCF
                    local targetCamCF = respawnCamCF
                    respawnCF = nil
                    respawnCamCF = nil
                    task.spawn(function()
                        local root = newChar:WaitForChild("HumanoidRootPart", 5)
                        if root then
                            task.wait()
                            newChar:PivotTo(targetCF)
                            root.CFrame = targetCF
                            if workspace.CurrentCamera and targetCamCF then
                                workspace.CurrentCamera.CFrame = targetCamCF
                            end
                        end
                    end)
                else
                    respawnCF = nil
                    respawnCamCF = nil
                end
            end))

            table.insert(conns, game:GetService("RunService").PreSimulation:Connect(function()
                if lp.Character and lp.Character:FindFirstChildWhichIsA("BasePart") then
                    local part = lp.Character:FindFirstChild("HumanoidRootPart") or lp.Character:FindFirstChildWhichIsA("BasePart")
                    local hum = lp.Character:FindFirstChildOfClass("Humanoid")
                    local cfr = part.CFrame
                    local cam = workspace.CurrentCamera
                    local destroyheight = workspace.FallenPartsDestroyHeight
                    local destroyheightnew = destroyheight + 5
                    local partvel = part.AssemblyLinearVelocity

                    if cfr.Position.Y < destroyheightnew or ((partvel.Y / 2.5) + part.Position.Y) < destroyheightnew then
                        part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        part.Velocity = Vector3.new(0, 0, 0)
                        part.RotVelocity = Vector3.new(0, 0, 0)
                        for _, v in pairs(lp.Character:GetChildren()) do
                            if v:IsA("BasePart") then
                                v.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                                v.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                                v.Velocity = Vector3.new(0, 0, 0)
                                v.RotVelocity = Vector3.new(0, 0, 0)
                            end
                        end
                        if isSpawnLastPosEnabled() and savedCF then
                            lp.Character:PivotTo(savedCF)
                            part.CFrame = savedCF
                            if cam and savedCamCF then
                                cam.CFrame = savedCamCF
                            end
                        else
                            local dhto = 25
                            local piv = lp.Character:GetPivot()
                            lp.Character:PivotTo(CFrame.new(piv.Position.X, destroyheight + dhto + lp.Character:GetExtentsSize().Y, piv.Position.Z))
                            lp.Character:PivotTo(CFrame.new(0, 51, 0))
                            if hum then
                                hum.Health = 0
                            end
                        end
                        return
                    end

                    if cfr.Position.Y > destroyheight + 25 and isGrounded(lp.Character, part, hum) then
                        savedCF = cfr
                        if cam then
                            savedCamCF = cam.CFrame
                        end
                    end
                end
            end))
            UpdateConnection("AntiMaptide", conns)
        else
            UpdateConnection("AntiMaptide", nil)
        end
    end
})

AntisTab:Toggle({
    Title = "loc:ANTI_MUTE_TITLE",
    Desc = "loc:ANTI_MUTE_DESC",
    Locked = true,
    Value = false,
    Callback = function(value)
        WindUI:Notify({
            Title = "loc:ANTI_MUTE_TITLE",
            Content = value and "loc:ANTI_MUTE_NOTIFY_ON" or "loc:ANTI_MUTE_NOTIFY_OFF",
            Icon = "volume-x",
            Duration = 3
        })
    end
})

AntisTab:Space()
AntisTab:Divider()
AntisTab:Space()

AntisTab:Section({
    Title = "loc:ANTIS_SEC_VISUAL_TITLE", 
    Icon = "eye",
    Desc = "loc:ANTIS_SEC_VISUAL_DESC"
})

AntisTab:Space()

local selectedVisuals = {}

local function isVisualSelected(key, locKey)
    if type(selectedVisuals) ~= "table" then return false end
    if selectedVisuals[key] == true or selectedVisuals[locKey] == true or selectedVisuals["All"] == true or selectedVisuals["loc:VISUAL_OPT_ALL_TITLE"] == true then
        return true
    end
    for _, v in pairs(selectedVisuals) do
        local id = (type(v) == "table" and (v.Value or v.Title)) or tostring(v)
        if id == "All" or id == "loc:VISUAL_OPT_ALL_TITLE" or id == key or id == locKey then
            return true
        end
    end
    return false
end

AntisTab:Dropdown({
    Title = "loc:VISUAL_PROT_DROPDOWN_TITLE",
    Desc = "loc:VISUAL_PROT_DROPDOWN_DESC",
    Multi = true,
    Values = {
        {
            Title = "loc:VISUAL_OPT_ALL_TITLE",
            Desc = "loc:VISUAL_OPT_ALL_DESC",
            Icon = "shield-check",
            Value = "All"
        },
        {
            Type = "Divider"
        },
        {
            Title = "loc:VISUAL_OPT_BLIND_TITLE",
            Desc = "loc:VISUAL_OPT_BLIND_DESC",
            Icon = "eye-off",
            Value = "Blind"
        },
        {
            Title = "loc:VISUAL_OPT_CURSED_TITLE",
            Desc = "loc:VISUAL_OPT_CURSED_DESC",
            Icon = "skull",
            Value = "Cursed"
        },
        {
            Title = "loc:VISUAL_OPT_MYOPIC_TITLE",
            Desc = "loc:VISUAL_OPT_MYOPIC_DESC",
            Icon = "focus",
            Value = "Myopic"
        },
        {
            Title = "loc:VISUAL_OPT_FOG_TITLE",
            Desc = "loc:VISUAL_OPT_FOG_DESC",
            Icon = "cloud-off",
            Value = "Fog"
        },
        {
            Title = "loc:VISUAL_OPT_COLORLESS_TITLE",
            Desc = "loc:VISUAL_OPT_COLORLESS_DESC",
            Icon = "palette",
            Value = "Colorless"
        }
    },
    Callback = function(value)
        if type(value) == "table" then
            selectedVisuals = value
        end
    end
})

AntisTab:Toggle({
    Title = "loc:VISUAL_TOGGLE_TITLE",
    Desc = "loc:VISUAL_TOGGLE_DESC",
    Value = false,
    Callback = function(value)
        WindUI:Notify({
            Title = "loc:VISUAL_PROT_DROPDOWN_TITLE",
            Content = value and "loc:VISUAL_TOGGLE_NOTIFY_ON" or "loc:VISUAL_TOGGLE_NOTIFY_OFF",
            Icon = value and "eye" or "x-circle",
            Duration = 3
        })
        if value then
            local connection = game:GetService("RunService").Heartbeat:Connect(function()
                local lighting = game:GetService("Lighting")
                if isVisualSelected("Blind", "loc:VISUAL_OPT_BLIND_TITLE") then
                    if lp.PlayerGui:FindFirstChild("Blind") then
                        lp.PlayerGui.Blind.Enabled = false
                    end
                end
                if isVisualSelected("Cursed", "loc:VISUAL_OPT_CURSED_TITLE") then
                    if lighting:FindFirstChild("RGB") then
                        lighting.RGB.Enabled = false
                    end
                    if lighting:FindFirstChild("ColorCorrection") then
                        lighting.ColorCorrection.Enabled = false
                    end
                end
                if isVisualSelected("Myopic", "loc:VISUAL_OPT_MYOPIC_TITLE") then
                    if lighting:FindFirstChild("BlurEffect") then
                        lighting.BlurEffect.Enabled = false
                    end
                    if lighting:FindFirstChild("Blur") then
                        lighting.Blur.Enabled = false
                    end
                    if lighting:FindFirstChild("DepthOfField") then
                        lighting.DepthOfField.Enabled = false
                    end
                end
                if isVisualSelected("Fog", "loc:VISUAL_OPT_FOG_TITLE") then
                    if lighting:FindFirstChild("Fog") then
                        lighting.Fog.Density = 0
                    end
                end
                if isVisualSelected("Colorless", "loc:VISUAL_OPT_COLORLESS_TITLE") then
                    if lighting:FindFirstChild("ColorCorrection") then
                        lighting.ColorCorrection.Enabled = false
                    end
                end
            end)
            UpdateConnection("Visuals", connection)
        else
            UpdateConnection("Visuals", nil)
        end
    end
})
HX.loadStage(HX.stageLabel("SILENT_TAB"), 0.73)
HX.SilentTab = Window:Tab({Title = "loc:SILENT_TAB", Icon = "message-circle-off", Locked = false})
HX.loadStage(HX.stageLabel("APPEARANCE_TAB"), 0.76)
HX.ApperanceTab = Window:Tab({Title = "loc:APPEARANCE_TAB", Icon = "palette", Locked = false})

do
    local Section = HX.ApperanceTab:Section({ Title = "loc:THEME_WORD", Side = "Left" })
    local pickers = {}
    local assetOn = false

    local function activeTheme()
        return WindUI.Themes[getgenv().Theme or HX.themeOrder[1]]
    end

    local themeDropdown

    local function syncPickers(name)
        local theme = WindUI.Themes[name or getgenv().Theme or HX.themeOrder[1]]
        if not theme then return end
        local top, bottom = HX.themeTextStops(theme)
        for field, picker in pairs(pickers) do
            if picker then
                if field == "TextTop" then
                    pcall(function() picker:Set(top) end)
                elseif field == "TextBottom" then
                    pcall(function() picker:Set(bottom) end)
                else
                    pcall(function() picker:Set(HX.themeColorValue(theme, field)) end)
                end
            end
        end
    end

    local function builtinCurrent()
        local current = getgenv().Theme
        if table.find(HX.themeOrder, current) then return current end
        return nil
    end

    themeDropdown = Section:Dropdown({
        Title = "loc:THEME_WORD",
        Values = HX.themeOrder,
        Value = builtinCurrent(),
        Callback = function(option)
            local name = HX.themeName(option)
            if name == "" then return end
            local chosen = HX.setTheme(name, true)
            syncPickers(chosen)
        end,
    })

    local savedDropdown = Section:Dropdown({
        Title = "loc:SAVED_THEME",
        Values = HX.savedThemeNames(),
        Callback = function(option)
            local name = HX.themeName(option)
            if name == "" or not WindUI.Themes[name] then return end
            HX.setTheme(name, true)
            syncPickers(name)
        end,
    })

    local active = activeTheme()
    local textTop, textBottom = HX.themeTextStops(active)
    local specs = {
        { "Accent", "loc:THEME_ACCENT", HX.themeColorValue(active, "Accent") },
        { "Background", "loc:THEME_BACKGROUND", HX.themeColorValue(active, "Background") },
        { "Dialog", "loc:THEME_DIALOG", HX.themeColorValue(active, "Dialog") },
        { "Outline", "loc:THEME_OUTLINE", HX.themeColorValue(active, "Outline") },
        { "TextTop", "loc:THEME_TEXT_TOP", textTop },
        { "TextBottom", "loc:THEME_TEXT_BOTTOM", textBottom },
        { "Placeholder", "loc:THEME_PLACEHOLDER", HX.themeColorValue(active, "Placeholder") },
        { "Button", "loc:THEME_BUTTON", HX.themeColorValue(active, "Button") },
        { "Icon", "loc:THEME_ICON", HX.themeColorValue(active, "Icon") },
    }
    for _, spec in ipairs(specs) do
        pickers[spec[1]] = Section:Colorpicker({
            Title = spec[2],
            Default = spec[3],
        })
    end

    local assetInput = Section:Input({
        Title = "loc:IMAGE_ASSET_ID",
        Placeholder = "loc:ASSET_ID_PLACEHOLDER",
        Callback = function(text)
            if assetOn then
                HX.themeAssetApply(text)
            end
        end,
    })

    Section:Toggle({
        Title = "loc:CUSTOM_BACKGROUND",
        Value = false,
        Callback = function(state)
            assetOn = state == true
            if assetOn then
                local ok, message = HX.themeAssetApply(assetInput.Value)
                if not ok and message then
                    pcall(function()
                        WindUI:Notify({ Title = "loc:BACKGROUND_WORD", Content = message, Duration = 3, Icon = "image" })
                    end)
                end
            else
                HX.themeAssetClear()
            end
        end,
    })

    local nameInput = Section:Input({
        Title = "loc:THEME_NAME",
        Placeholder = "loc:THEME_NAME_PLACEHOLDER",
    })

    Section:Button({
        Title = "loc:SAVE_AND_APPLY",
        Icon = "save",
        Callback = function()
            local colors = {}
            for field, picker in pairs(pickers) do
                colors[field] = picker and picker.Default or nil
            end
            colors.TextTop = pickers.TextTop and pickers.TextTop.Default or nil
            colors.TextBottom = pickers.TextBottom and pickers.TextBottom.Default or nil
            local saved, detail = HX.themeSave(nameInput.Value, colors)
            if not saved then
                pcall(function()
                    WindUI:Notify({ Title = "loc:THEME_WORD", Content = tostring(detail or "Could not save."), Duration = 4, Icon = "x-circle" })
                end)
                return
            end
            if savedDropdown then
                pcall(function()
                    savedDropdown.Values = HX.savedThemeNames()
                    savedDropdown.Value = saved
                    savedDropdown:Refresh(savedDropdown.Values)
                    savedDropdown:Display()
                end)
            end
            if themeDropdown then
                pcall(function()
                    themeDropdown.Value = nil
                    themeDropdown:Display()
                end)
            end
            pcall(function()
                WindUI:Notify({ Title = "loc:THEME_WORD", Content = HX.translate("SAVED_AND_APPLIED") .. " " .. saved, Duration = 3, Icon = "check" })
            end)
        end,
    })
end

HX.loadStage(HX.stageLabel("ESP_TAB"), 0.79)
HX.WorldTab = Window:Tab({
    Title = "World",
    Icon = "globe",
    Locked = false
})

HX.ESPTab = Window:Tab({
    Title = "loc:ESP_TAB", 
    Icon = "eye",
    Locked = false
})

HX.PlayersSection = HX.ESPTab:Section({
    Title = "loc:PLAYERS",
    Side = "Left"
})

local Players = game:GetService("Players")

local CoreGui
do
    local ok, service = pcall(function() return game:GetService("CoreGui") end)
    CoreGui = (ok and service) or nil
end
if not CoreGui then
    local player = Players.LocalPlayer
    CoreGui = HX.CoreGui or (player and player:WaitForChild("PlayerGui"))
end
local RunService = game:GetService("RunService")

HX.PlayersESPOn = false
HX.ChosenESPOn = false
HX.playerHighlights = {}
HX.playerConnections = {}

HX.ESP_ASPECT = 0.45
HX.espGui = nil

HX.EspStyle = {
    Box = true,
    BoxColor = Color3.fromRGB(255, 255, 255),
    Fill = 0,
    Thickness = 1,
    Brackets = true,
    Name = true,
    NameColor = Color3.fromRGB(255, 255, 255),
    Distance = true,
    TextSide = "Above",
    TextSize = 13,
    Health = false,
    Tracer = false,
    Scale = 1,
    BoxOffset = Vector2.new(0, 0),
    NameOffset = Vector2.new(0, 0),
    DistanceOffset = Vector2.new(0, 0),
}

function HX.isPlayerInChosenTeam(player)
    if not player then return false end
    local team = player.Team
    return team and team.Name == "Chosen"
end

function HX.ensureEspGui()
    if HX.espGui and HX.espGui.Parent then
        return HX.espGui
    end
    local gui = Instance.new("ScreenGui")
    gui.Name = "EnderHubESP"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999999
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = (type(gethui) == "function" and gethui()) or Players.LocalPlayer:WaitForChild("PlayerGui")
    HX.espGui = gui
    return gui
end

local function espBar(parent, name, color, transparency)
    local frame = Instance.new("Frame")
    frame.Name = name
    frame.BackgroundColor3 = color
    frame.BackgroundTransparency = transparency or 0
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.Parent = parent
    return frame
end

local function espLabel(parent, name, textSize, weight)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.BackgroundTransparency = 1
    label.Text = ""
    label.TextSize = textSize
    label.Font = weight
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextStrokeTransparency = 0.35
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.Visible = false
    label.Parent = parent
    return label
end

function HX.createESP(player, highlightColor)
    if not player or player == Players.LocalPlayer then return end
    if HX.playerHighlights[player] then return end

    local char = player.Character
    if not char then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local head = char:FindFirstChild("Head")
    if not head then return end

    local root = Instance.new("Frame")
    root.Name = player.Name .. "_ESP"
    root.BackgroundTransparency = 1
    root.Size = UDim2.fromScale(1, 1)
    root.Parent = HX.ensureEspGui()

    local entry = {
        player = player,
        fallback = highlightColor or Color3.new(1, 1, 1),
        root = root,
        fill = espBar(root, "Fill", Color3.new(1, 1, 1), 1),
        edges = {},
        brackets = {},
        healthBack = espBar(root, "HealthBack", Color3.new(0, 0, 0), 0.55),
        healthFill = espBar(root, "HealthFill", Color3.fromRGB(88, 214, 122), 0),
        tracer = espBar(root, "Tracer", Color3.new(1, 1, 1), 0.25),
        nameLabel = espLabel(root, "Name", 13, Enum.Font.GothamBold),
        distLabel = espLabel(root, "Distance", 11, Enum.Font.GothamMedium),
    }

    entry.distLabel.TextTransparency = 0.15
    entry.nameLabel.Text = player.DisplayName ~= player.Name
        and (player.DisplayName .. " | " .. player.Name)
        or player.Name

    for index = 1, 4 do
        entry.edges[index] = espBar(root, "Edge" .. index, Color3.new(1, 1, 1), 0.1)
    end
    for index = 1, 8 do
        entry.brackets[index] = espBar(root, "Bracket" .. index, Color3.new(1, 1, 1), 0)
    end

    HX.playerHighlights[player] = entry

    if not HX.playerConnections[player] then
        HX.playerConnections[player] = {}
    end

    local diedConnection = hum.Died:Connect(function()
        HX.removeESP(player)
    end)
    table.insert(HX.playerConnections[player], diedConnection)

    local removalConnection
    removalConnection = char.AncestryChanged:Connect(function(_, parent)
        if not parent then
            HX.removeESP(player)
        end
    end)
    table.insert(HX.playerConnections[player], removalConnection)
end

function HX.drawEspEntry(entry, camera, localRoot, style)
    local root = entry.root
    local char = entry.player.Character

    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local head = char and char:FindFirstChild("Head")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if not (root and camera and hum and head and hrp) or hum.Health <= 0 then
        if root then
            root.Visible = false
        end
        return
    end

    local topWorld = head.Position + Vector3.new(0, head.Size.Y * 0.5 + 0.15, 0)
    local footWorld = hrp.Position - Vector3.new(0, hrp.Size.Y * 0.5 + (hum.HipHeight or 2), 0)

    local topScreen = camera:WorldToViewportPoint(topWorld)
    local footScreen = camera:WorldToViewportPoint(footWorld)
    if topScreen.Z <= 0 or footScreen.Z <= 0 then
        root.Visible = false
        return
    end

    local rawHeight = math.abs(footScreen.Y - topScreen.Y)
    if rawHeight < 6 then
        root.Visible = false
        return
    end

    root.Visible = true

    local function place(frame, x, y, width, height)
        frame.Position = UDim2.fromOffset(x, y)
        frame.Size = UDim2.fromOffset(math.max(1, width), math.max(1, height))
        frame.Visible = true
    end

    local function hide(...)
        for _, frame in ipairs({ ... }) do
            frame.Visible = false
        end
    end

    local height = rawHeight * (style.Scale or 1)
    local width = height * HX.ESP_ASPECT
    local boxOffset = style.BoxOffset or Vector2.new(0, 0)
    local centreX = (topScreen.X + footScreen.X) * 0.5 + boxOffset.X
    local centreY = (topScreen.Y + footScreen.Y) * 0.5 + boxOffset.Y
    local left = centreX - width * 0.5
    local right = centreX + width * 0.5
    local topY = centreY - height * 0.5
    local bottomY = centreY + height * 0.5
    local color = style.BoxColor or entry.fallback

    if style.Box then
        local thickness = math.clamp(style.Thickness or 1, 1, 4)
        local fillAlpha = style.Fill or 0

        if fillAlpha > 0 then
            entry.fill.BackgroundColor3 = color
            entry.fill.BackgroundTransparency = 1 - fillAlpha
            place(entry.fill, left, topY, width, height)
        else
            entry.fill.Visible = false
        end

        for _, edge in ipairs(entry.edges) do
            edge.BackgroundColor3 = color
            edge.BackgroundTransparency = 0.1
        end
        place(entry.edges[1], left, topY, width, thickness)
        place(entry.edges[2], left, bottomY - thickness, width, thickness)
        place(entry.edges[3], left, topY, thickness, height)
        place(entry.edges[4], right - thickness, topY, thickness, height)

        if style.Brackets then
            local armX = math.clamp(width * 0.22, 6, 18)
            local armY = math.clamp(height * 0.13, 6, 18)
            local bar = thickness + 1
            for _, bracket in ipairs(entry.brackets) do
                bracket.BackgroundColor3 = color
            end
            place(entry.brackets[1], left, topY, armX, bar)
            place(entry.brackets[2], left, topY, bar, armY)
            place(entry.brackets[3], right - armX, topY, armX, bar)
            place(entry.brackets[4], right - bar, topY, bar, armY)
            place(entry.brackets[5], left, bottomY - bar, armX, bar)
            place(entry.brackets[6], left, bottomY - armY, bar, armY)
            place(entry.brackets[7], right - armX, bottomY - bar, armX, bar)
            place(entry.brackets[8], right - bar, bottomY - armY, bar, armY)
        else
            for _, bracket in ipairs(entry.brackets) do
                bracket.Visible = false
            end
        end
    else
        hide(entry.fill, entry.edges[1], entry.edges[2], entry.edges[3], entry.edges[4])
        for _, bracket in ipairs(entry.brackets) do
            bracket.Visible = false
        end
    end

    if style.Health then
        local barWidth = math.clamp(math.floor(width * 0.05 + 0.5), 2, 4)
        local barX = left - barWidth - 3
        local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
        entry.healthBack.Position = UDim2.fromOffset(barX, topY)
        entry.healthBack.Size = UDim2.fromOffset(barWidth, height)
        entry.healthBack.Visible = true
        entry.healthFill.Position = UDim2.fromOffset(barX, topY + height * (1 - ratio))
        entry.healthFill.Size = UDim2.fromOffset(barWidth, math.max(1, height * ratio))
        entry.healthFill.Visible = true
    else
        hide(entry.healthBack, entry.healthFill)
    end

    if style.Tracer and localRoot then
        local screen = camera.ViewportSize
        local originX, originY = screen.X * 0.5, screen.Y
        local dx, dy = centreX - originX, bottomY - originY
        entry.tracer.BackgroundColor3 = color
        entry.tracer.AnchorPoint = Vector2.new(0, 0.5)
        entry.tracer.Position = UDim2.fromOffset(originX, originY)
        entry.tracer.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy), 1)
        entry.tracer.Rotation = math.deg(math.atan2(dy, dx))
        entry.tracer.Visible = true
    else
        entry.tracer.Visible = false
    end

    local below = style.TextSide == "Below"
    local textSize = style.TextSize or 13
    local labelWidth = math.max(width, 100)
    local nameOffset = style.NameOffset or Vector2.new(0, 0)
    local distanceOffset = style.DistanceOffset or Vector2.new(0, 0)
    local nameY = below and (bottomY + textSize + 8) or (topY - textSize - 4)
    local distanceY = below and (bottomY + 2) or (topY - textSize * 2 - 8)

    if style.Name then
        entry.nameLabel.TextColor3 = style.NameColor or Color3.new(1, 1, 1)
        entry.nameLabel.TextSize = textSize
        place(entry.nameLabel, centreX - labelWidth * 0.5 + nameOffset.X, nameY + nameOffset.Y, labelWidth, textSize + 4)
    else
        entry.nameLabel.Visible = false
    end

    if style.Distance then
        local dist = localRoot and math.floor((hrp.Position - localRoot.Position).Magnitude) or 0
        entry.distLabel.Text = dist .. "m"
        entry.distLabel.TextColor3 = style.NameColor or Color3.new(1, 1, 1)
        entry.distLabel.TextSize = math.max(9, textSize - 2)
        place(
            entry.distLabel,
            centreX - labelWidth * 0.5 + distanceOffset.X,
            distanceY + distanceOffset.Y,
            labelWidth,
            math.max(9, textSize - 2) + 2
        )
    else
        entry.distLabel.Visible = false
    end
end

if not HX.espRenderLoop then
    HX.espRenderLoop = RunService.RenderStepped:Connect(function()
        if not next(HX.playerHighlights) then
            return
        end
        local camera = workspace.CurrentCamera
        if not camera then
            return
        end
        local myChar = Players.LocalPlayer.Character
        local localRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local style = HX.EspStyle or {}
        for _, entry in pairs(HX.playerHighlights) do
            HX.drawEspEntry(entry, camera, localRoot, style)
        end
    end)
end

function HX.removeESP(player)
    local entry = HX.playerHighlights[player]
    if entry then
        if entry.root then
            entry.root:Destroy()
        end
        HX.playerHighlights[player] = nil
    end
end

function HX.clearAllESP()
    for player, connections in pairs(HX.playerConnections) do
        for _, connection in ipairs(connections) do
            pcall(function() connection:Disconnect() end)
        end
    end
    HX.playerConnections = {}
    
    for player, _ in pairs(HX.playerHighlights) do
        HX.removeESP(player)
    end
    HX.playerHighlights = {}
end

function HX.updateAllESP()
    HX.clearAllESP()
    
    if not HX.PlayersESPOn and not HX.ChosenESPOn then return end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player == Players.LocalPlayer then continue end
        
        local isChosen = HX.isPlayerInChosenTeam(player)
        
        if isChosen and HX.ChosenESPOn then
            HX.createESP(player, Color3.fromRGB(255, 255, 0)) 
        elseif not isChosen and HX.PlayersESPOn then
            HX.createESP(player, Color3.fromRGB(255, 255, 255)) 
        end
    end
end

function HX.setupPlayer(player)
    if player == Players.LocalPlayer then return end

    if HX.playerConnections[player] then
        for _, connection in ipairs(HX.playerConnections[player]) do
            pcall(function() connection:Disconnect() end)
        end
        HX.playerConnections[player] = nil
    end

    local charAddedConnection = player.CharacterAdded:Connect(function(char)
        task.wait(0.5) 
        
        local isChosen = HX.isPlayerInChosenTeam(player)
        if isChosen and HX.ChosenESPOn then
            HX.createESP(player, Color3.fromRGB(255, 255, 0))
        elseif not isChosen and HX.PlayersESPOn then
            HX.createESP(player, Color3.fromRGB(255, 255, 255))
        end
    end)

    local teamChangedConnection = player:GetPropertyChangedSignal("Team"):Connect(function()
        HX.removeESP(player)
        if player.Character then
            task.wait(0.5)
            local isChosen = HX.isPlayerInChosenTeam(player)
            if isChosen and HX.ChosenESPOn then
                HX.createESP(player, Color3.fromRGB(255, 255, 0))
            elseif not isChosen and HX.PlayersESPOn then
                HX.createESP(player, Color3.fromRGB(255, 255, 255))
            end
        end
    end)

    HX.playerConnections[player] = {charAddedConnection, teamChangedConnection}

    if player.Character then
        local isChosen = HX.isPlayerInChosenTeam(player)
        if isChosen and HX.ChosenESPOn then
            HX.createESP(player, Color3.fromRGB(255, 255, 0))
        elseif not isChosen and HX.PlayersESPOn then
            HX.createESP(player, Color3.fromRGB(255, 255, 255))
        end
    end
end

HX.PlayersEspToggle = HX.ESPTab:Toggle({
    Title = "loc:ESP_PLAYERS",
    Value = false,
    Callback = function(state)
        HX.PlayersESPOn = state
        HX.updateAllESP()
    end
})

HX.ChosenEspToggle = HX.ESPTab:Toggle({
    Title = "loc:ESP_CHOSEN", 
    Value = false,
    Callback = function(state)
        HX.ChosenESPOn = state
        HX.updateAllESP()
    end
})

HX.ESPTab:Button({
    Title = "loc:ESP_CLEAR",
    Callback = function()
        HX.clearAllESP()
        HX.SafeNotify({
            Title = "loc:ESP_CLEARED",
            Content = "loc:ESP_CLEARED_DESC",
            Duration = 2,
            Icon = "check"
        })
    end
})

for _, player in pairs(Players:GetPlayers()) do
    HX.setupPlayer(player)
end

Players.PlayerAdded:Connect(function(player)
    HX.setupPlayer(player)
end)

Players.PlayerRemoving:Connect(function(player)
    if HX.playerConnections[player] then
        for _, connection in ipairs(HX.playerConnections[player]) do
            pcall(function() connection:Disconnect() end)
        end
        HX.playerConnections[player] = nil
    end
    HX.removeESP(player)
end)

Window:OnDestroy(function()
    HX.clearAllESP()
end)

HX.loadStage(HX.stageLabel("ESP_TAB"), 0.80)

do
    local Players = game:GetService("Players")
    local Lighting = game:GetService("Lighting")
    local UIS = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")

    local player = Players.LocalPlayer
    local Visuals = {}
    HX.Visuals = Visuals

    

    
    local Cursor = {
        On = false,
        Preset = "Star of David",
        Color = Color3.fromRGB(255, 255, 255),
        Size = 34,
        Thickness = 0.09,
        Offset = Vector2.new(0, 0),
        Spin = false,
        Speed = 60,
        Rotation = 0,
        Bounce = false,
        BounceSpeed = 2.4,
        BounceHeight = 10,
        Pulse = false,
        PulseSpeed = 1.6,
        PulseAmount = 0.22,
        Phase = 0,
        PulsePhase = 0,
        Gui = nil,
        Root = nil,
        Scale = nil,
        Conn = nil,
    }
    Visuals.Cursor = Cursor

    local CURSOR_PRESETS = {
        "Star of David", "Star", "Cross", "Crosshair", "Diamond", "Triangle", "Chevron",
        "Hexagon", "Ring", "Dot", "Corners", "Square", "Ticks", "Arrows", "Brackets",
        "Spark",
    }

    local function stroke(a, b)
        local dx, dy = b[1] - a[1], b[2] - a[2]
        return {
            X = (a[1] + b[1]) * 0.5,
            Y = (a[2] + b[2]) * 0.5,
            Len = math.sqrt(dx * dx + dy * dy),
            Angle = math.deg(math.atan2(dy, dx)),
        }
    end

    local function outline(points)
        local list = {}
        for i = 1, #points do
            list[i] = stroke(points[i], points[i % #points + 1])
        end
        return list
    end

    local function polygon(sides, radius, offsetDeg)
        local points = {}
        for i = 0, sides - 1 do
            local angle = math.rad(-90 + (offsetDeg or 0) + i * (360 / sides))
            points[i + 1] = { math.cos(angle) * radius, math.sin(angle) * radius }
        end
        return outline(points)
    end

    local function triangle(radius, flip)
        return polygon(3, radius, flip and 180 or 0)
    end

    local function star(arms, inner)
        local points = {}
        for i = 0, arms * 2 - 1 do
            local angle = math.rad(-90 + i * (180 / arms))
            local radius = (i % 2 == 0) and 1 or inner
            points[i + 1] = { math.cos(angle) * radius, math.sin(angle) * radius }
        end
        return outline(points)
    end

    local function corners(radius, arm)
        local list = {}
        for _, sx in ipairs({ -1, 1 }) do
            for _, sy in ipairs({ -1, 1 }) do
                list[#list + 1] = stroke({ sx * radius, sy * radius }, { sx * (radius - arm), sy * radius })
                list[#list + 1] = stroke({ sx * radius, sy * radius }, { sx * radius, sy * (radius - arm) })
            end
        end
        return list
    end

    local function cursorStrokes(name)
        if name == "Star of David" then

            local list = triangle(0.94, false)
            for _, s in ipairs(triangle(0.94, true)) do
                list[#list + 1] = s
            end
            return list
        elseif name == "Star" then
            return star(5, 0.42)
        elseif name == "Diamond" then
            return outline({ { 0, -0.94 }, { 0.94, 0 }, { 0, 0.94 }, { -0.94, 0 } })
        elseif name == "Cross" then
            return {
                { X = 0, Y = 0, Len = 1.7, Angle = 0 },
                { X = 0, Y = 0, Len = 1.7, Angle = 90 },
            }
        elseif name == "Crosshair" then
            return {
                { X = 0, Y = -0.66, Len = 0.62, Angle = 90 },
                { X = 0, Y = 0.66, Len = 0.62, Angle = 90 },
                { X = -0.66, Y = 0, Len = 0.62, Angle = 0 },
                { X = 0.66, Y = 0, Len = 0.62, Angle = 0 },
            }
        elseif name == "Chevron" then
            return {
                stroke({ -0.55, -0.72 }, { 0.32, 0 }),
                stroke({ 0.32, 0 }, { -0.55, 0.72 }),
            }
        elseif name == "Hexagon" then
            return polygon(6, 0.92, 0)
        elseif name == "Square" then
            return outline({ { -0.72, -0.72 }, { 0.72, -0.72 }, { 0.72, 0.72 }, { -0.72, 0.72 } })
        elseif name == "Brackets" then
            return corners(0.9, 0.5)
        elseif name == "Ticks" then

            local list = {}
            for index = 0, 3 do
                local angle = math.rad(index * 90)
                local cx, cy = math.cos(angle), math.sin(angle)
                list[#list + 1] = stroke({ cx * 0.42, cy * 0.42 }, { cx * 0.95, cy * 0.95 })
            end
            return list
        elseif name == "Arrows" then
            
            local list = {}
            for index = 0, 3 do
                local angle = math.rad(index * 90)
                local cx, cy = math.cos(angle), math.sin(angle)
                local px, py = -cy, cx
                local tip = { cx * 0.92, cy * 0.92 }
                list[#list + 1] = stroke(tip, { cx * 0.34 + px * 0.36, cy * 0.34 + py * 0.36 })
                list[#list + 1] = stroke(tip, { cx * 0.34 - px * 0.36, cy * 0.34 - py * 0.36 })
            end
            return list
        elseif name == "Spark" then
            local list = star(4, 0.3)
            for _, s in ipairs(polygon(4, 0.52, 45)) do
                list[#list + 1] = s
            end
            return list
        elseif name == "Dot" then
            return { { X = 0, Y = 0, Len = 0.001, Angle = 0 } }
        elseif name == "Corners" then
            return corners(0.86, 0.34)
        end
        return triangle(0.94, false)
    end

    
    
    local function paintCursor(parent, state, size)
        local color = state.Color or Color3.new(1, 1, 1)
        local thickness = math.max(1, math.floor(size * (state.Thickness or 0.09) + 0.5))
        local half = size * 0.5
        local shadow = Color3.new(0, 0, 0)

        local function capsule(position, length, width, rotation, tint, transparency)
            local bar = Instance.new("Frame")
            bar.AnchorPoint = Vector2.new(0.5, 0.5)
            bar.BackgroundColor3 = tint
            bar.BackgroundTransparency = transparency
            bar.BorderSizePixel = 0
            bar.Position = UDim2.fromOffset(position.X, position.Y)
            bar.Size = UDim2.fromOffset(math.max(1, length), math.max(1, width))
            bar.Rotation = rotation
            bar.Parent = parent
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(1, 0)
            corner.Parent = bar
            return bar
        end

        if state.Preset == "Ring" then
            for pass = 1, 2 do
                local ring = Instance.new("Frame")
                ring.AnchorPoint = Vector2.new(0.5, 0.5)
                ring.Position = UDim2.fromScale(0.5, 0.5)
                ring.Size = UDim2.fromScale(1, 1)
                ring.BackgroundTransparency = 1
                ring.Parent = parent
                local corner = Instance.new("UICorner")
                corner.CornerRadius = UDim.new(1, 0)
                corner.Parent = ring
                local edge = Instance.new("UIStroke")
                edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                edge.Color = pass == 1 and shadow or color
                edge.Transparency = pass == 1 and 0.55 or 0
                edge.Thickness = pass == 1 and thickness + 2 or thickness
                edge.Parent = ring
            end
            return
        end

        if state.Preset == "Dot" then
            for pass = 1, 2 do
                local dot = Instance.new("Frame")
                dot.AnchorPoint = Vector2.new(0.5, 0.5)
                dot.Position = UDim2.fromScale(0.5, 0.5)
                dot.Size = UDim2.fromScale(0.42, 0.42)
                dot.BackgroundColor3 = pass == 1 and shadow or color
                dot.BackgroundTransparency = pass == 1 and 0.55 or 0
                dot.BorderSizePixel = 0
                dot.Parent = parent
                local corner = Instance.new("UICorner")
                corner.CornerRadius = UDim.new(1, 0)
                corner.Parent = dot
            end
            return
        end

        local strokes = cursorStrokes(state.Preset)
        for _, s in ipairs(strokes) do
            capsule(
                Vector2.new(half + s.X * half, half + s.Y * half),
                math.floor(s.Len * half + 0.5),
                thickness + 2,
                s.Angle,
                shadow,
                0.55
            )
        end
        for _, s in ipairs(strokes) do
            capsule(
                Vector2.new(half + s.X * half, half + s.Y * half),
                math.floor(s.Len * half + 0.5),
                thickness,
                s.Angle,
                color,
                0
            )
        end
    end

    local function cursorBuild()
        if Cursor.Gui then
            Cursor.Gui:Destroy()
            Cursor.Gui = nil
            Cursor.Root = nil
        end
        if not Cursor.On then
            return
        end

        
        local host = (type(gethui) == "function" and gethui()) or player:WaitForChild("PlayerGui")
        for _, stale in ipairs(host:GetChildren()) do
            if stale.Name == "EnderHubCursor" then
                stale:Destroy()
            end
        end

        local gui = Instance.new("ScreenGui")
        gui.Name = "EnderHubCursor"
        gui.IgnoreGuiInset = true
        gui.ResetOnSpawn = false
        gui.DisplayOrder = 1000000
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.Parent = host

        local root = Instance.new("Frame")
        root.Name = "Pointer"
        root.AnchorPoint = Vector2.new(0.5, 0.5)
        root.BackgroundTransparency = 1
        root.Size = UDim2.fromOffset(Cursor.Size, Cursor.Size)
        root.Rotation = Cursor.Rotation
        root.Parent = gui

        
        local scale = Instance.new("UIScale")
        scale.Name = "Pulse"
        scale.Scale = 1
        scale.Parent = root

        paintCursor(root, Cursor, Cursor.Size)

        Cursor.Gui = gui
        Cursor.Root = root
        Cursor.Scale = scale
    end

    local function cursorLoop()
        if Cursor.Conn then
            return
        end
        Cursor.Conn = RunService.RenderStepped:Connect(function(dt)
            local root = Cursor.Root
            if not root or not root.Parent then
                return
            end
            local at = UIS:GetMouseLocation()
            local offset = Cursor.Offset or Vector2.new(0, 0)

            
            local factor = 1
            if Cursor.Pulse then
                Cursor.PulsePhase = (Cursor.PulsePhase + Cursor.PulseSpeed * dt) % (math.pi * 2)
                factor = 1 + math.sin(Cursor.PulsePhase) * (Cursor.PulseAmount or 0.22)
            end
            local compensation = (factor - 1) * Cursor.Size * 0.5
            local x = at.X + offset.X - compensation
            local y = at.Y + offset.Y - compensation

            if Cursor.Bounce then
                Cursor.Phase = (Cursor.Phase + Cursor.BounceSpeed * dt) % (math.pi * 2)
                y = y - math.abs(math.sin(Cursor.Phase)) * (Cursor.BounceHeight or 10)
            end

            root.Position = UDim2.fromOffset(x, y)
            if Cursor.Scale then
                Cursor.Scale.Scale = factor
            end
            if Cursor.Spin then
                Cursor.Rotation = (Cursor.Rotation + Cursor.Speed * dt) % 360
                root.Rotation = Cursor.Rotation
            end
        end)
    end

    local function cursorSet(on)
        Cursor.On = on == true
        UIS.MouseIconEnabled = not Cursor.On
        cursorBuild()
        if Cursor.On then
            cursorLoop()
        end
    end
    Visuals.SetCursor = cursorSet

    local Avatar = {
        MaterialOn = false,
        Material = Enum.Material.Neon,
        ColorOn = false,
        Color = Color3.fromRGB(126, 92, 255),
        Saved = {},
    }
    Visuals.Avatar = Avatar

    local MATERIALS = {
        "Plastic", "SmoothPlastic", "Neon", "Glass", "ForceField", "Metal", "DiamondPlate",
        "Foil", "Concrete", "Brick", "Granite", "Marble", "Slate", "Sand", "Fabric", "Ice",
        "Wood", "WoodPlanks", "Grass", "LeafyGrass", "Snow", "Glacier", "Sandstone", "Rock",
        "Basalt", "Cobblestone", "Asphalt", "Pebble", "Limestone", "Salt", "Mud", "Ground",
        "Carpet", "CeramicTiles", "Plaster", "Rubber", "CorrodedMetal", "Cardboard",
    }

    local function avatarParts()
        local list = {}
        local char = player.Character
        if not char then
            return list
        end
        for _, item in ipairs(char:GetDescendants()) do
            if item:IsA("BasePart") then
                list[#list + 1] = item
            end
        end
        return list
    end

    
    local function avatarApply()
        for _, part in ipairs(avatarParts()) do
            local saved = Avatar.Saved[part]
            if not saved then
                saved = { Material = part.Material, Color = part.Color }
                Avatar.Saved[part] = saved
            end
            part.Material = Avatar.MaterialOn and Avatar.Material or saved.Material
            part.Color = Avatar.ColorOn and Avatar.Color or saved.Color
        end
        for part in pairs(Avatar.Saved) do
            if part.Parent == nil then
                Avatar.Saved[part] = nil
            end
        end
    end

    Visuals.AvatarConn = player.CharacterAdded:Connect(function()
        Avatar.Saved = {}
        task.defer(function()
            avatarApply()
        end)
    end)

    local World = {
        FogOn = false,
        FogColor = Color3.fromRGB(150, 165, 190),
        FogStart = 200,
        FogEnd = 2000,
        Brightness = 2,
        ClockTime = 14,
        Ambient = Color3.fromRGB(70, 70, 70),
        Exposure = 0,
        Shadows = true,
        Motion = false,
        MotionSpeed = 0.12,
        Saved = nil,
    }
    Visuals.World = World

    
    
    local LIGHT_KEYS = {
        "FogColor", "FogStart", "FogEnd", "Brightness", "ClockTime", "Ambient",
        "ExposureCompensation", "GlobalShadows", "EnvironmentSpecularScale",
        "EnvironmentDiffuseScale",
    }

    local function lightingSnapshot()
        local snapshot = {}
        for _, key in ipairs(LIGHT_KEYS) do
            local ok, value = pcall(function()
                return Lighting[key]
            end)
            if ok then
                snapshot[key] = value
            end
        end
        return snapshot
    end

    local function lightingRestore(snapshot)
        if type(snapshot) ~= "table" then
            return
        end
        for key, value in next, snapshot do
            pcall(function()
                Lighting[key] = value
            end)
        end
    end

    local function worldBoot()
        lightingRestore(HX.bootGenv.EnderHubLightingBase)
        HX.bootGenv.EnderHubLightingBase = lightingSnapshot()

        for _, child in ipairs(workspace:GetChildren()) do
            if child.Name == "EnderHubWeather" or child.Name == "EnderHubPuddles" then
                child:Destroy()
            end
        end
        local terrain = workspace:FindFirstChildOfClass("Terrain")
        local clouds = terrain and terrain:FindFirstChild("EnderHubClouds")
        if clouds then
            clouds:Destroy()
        end
        local soundService = game:GetService("SoundService")
        local ambience = soundService:FindFirstChild("EnderHubAmbience")
        if ambience then
            ambience:Destroy()
        end
        for _, effect in ipairs(Lighting:GetChildren()) do
            if effect.Name:sub(1, 11) == "EnderHubPost" or effect.Name == "EnderHubAtmosphere" then
                effect:Destroy()
            end
        end
    end

    worldBoot()

    
    
    local SKY_FACES = {
        "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp",
    }

    
    
    local SKY_PRESETS = {
        ["Default"] = false,
        ["Clear Sky"] = { Sun = 21, Moon = 12, StarCount = 3000, Bodies = true },
        ["Big Sun"] = { Sun = 70, Moon = 12, StarCount = 3000, Bodies = true },
        ["Tiny Sun"] = { Sun = 7, Moon = 12, StarCount = 3000, Bodies = true },
        ["Full Moon"] = { Sun = 12, Moon = 60, StarCount = 3000, Bodies = true },
        ["Starfield"] = { Sun = 10, Moon = 10, StarCount = 6000, Bodies = true },
        ["Moonless Night"] = { Sun = 7, Moon = 6, StarCount = 4500, Bodies = false },
        ["Purple Nebula"] = {
            Faces = {
                "rbxassetid://159454286",
                "rbxassetid://159454288",
                "rbxassetid://159454300",
                "rbxassetid://159454293",
                "rbxassetid://159454299",
                "rbxassetid://159454296",
            },
            Sun = 12,
            Moon = 12,
            StarCount = 3000,
            Bodies = true,
        },
    }

    local function worldSave()
        if World.Saved then
            return
        end
        local sky = Lighting:FindFirstChildOfClass("Sky")
        local faces = {}
        if sky then
            for _, property in ipairs(SKY_FACES) do

                local ok, value = pcall(function()
                    return sky[property]
                end)
                faces[property] = ok and value or ""
            end
        end
        World.Saved = {
            HadSky = sky ~= nil,
            Faces = faces,
            StarCount = sky and sky.StarCount or 3000,
            FogColor = Lighting.FogColor,
            FogStart = Lighting.FogStart,
            FogEnd = Lighting.FogEnd,
            Brightness = Lighting.Brightness,
            ClockTime = Lighting.ClockTime,
            Ambient = Lighting.Ambient,
            ExposureCompensation = Lighting.ExposureCompensation,
            GlobalShadows = Lighting.GlobalShadows,
            EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
            EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
            GlobalWind = workspace.GlobalWind,
        }
    end

    
    local skyOwned = false

    local function skyApply(preset)
        worldSave()
        local sky = Lighting:FindFirstChildOfClass("Sky")
        if not preset then
            if sky then
                if World.Saved.HadSky then
                    for _, property in ipairs(SKY_FACES) do
                        local ok, value = pcall(function()
                            return World.Saved.Faces[property]
                        end)
                        sky[property] = ok and value or ""
                    end
                    sky.StarCount = World.Saved.StarCount
                elseif skyOwned then
                    sky:Destroy()
                end
            end
            skyOwned = false
            return
        end
        if not sky then
            sky = Instance.new("Sky")
            sky.Parent = Lighting
            skyOwned = true
        end
        if preset.Faces then
            for index, property in ipairs(SKY_FACES) do
                sky[property] = preset.Faces[index]
            end
        end
        if preset.StarCount ~= nil then
            sky.StarCount = preset.StarCount
        end
        if preset.Sun then
            sky.SunAngularSize = preset.Sun
        end
        if preset.Moon then
            sky.MoonAngularSize = preset.Moon
        end
        if preset.Bodies ~= nil then
            sky.CelestialBodiesShown = preset.Bodies
        end
    end

    local function parseFaces(text)
        local list = {}
        for piece in string.gmatch(tostring(text or ""), "[^,%s]+") do
            local id = string.match(piece, "(%d+)")
            if id then
                list[#list + 1] = "rbxassetid://" .. id
            end
        end
        if #list == 1 then
            for index = 2, #SKY_FACES do
                list[index] = list[1]
            end
        end
        if #list < #SKY_FACES then
            return nil
        end
        return list
    end

    local function fogApply()
        worldSave()
        if not World.FogOn then
            Lighting.FogColor = World.Saved.FogColor
            Lighting.FogStart = World.Saved.FogStart
            Lighting.FogEnd = World.Saved.FogEnd
            return
        end
        Lighting.FogColor = World.FogColor
        Lighting.FogStart = World.FogStart
        Lighting.FogEnd = math.max(World.FogStart + 1, World.FogEnd)
    end

    local function lightApply()
        worldSave()
        Lighting.Brightness = World.Brightness
        Lighting.ClockTime = World.ClockTime
        Lighting.Ambient = World.Ambient
        Lighting.ExposureCompensation = World.Exposure
        Lighting.GlobalShadows = World.Shadows
    end

    
    
    local Post = {
        ColorOn = false, Saturation = 0, Contrast = 0, ColorBrightness = 0,
        AtmosphereOn = false, Haze = 0.3,
        BloomOn = false, BloomIntensity = 2.5, BloomSize = 24, BloomThreshold = 1,
        RaysOn = false, RaysIntensity = 0.1, RaysSpread = 0.5,
        Blur = 0,
        FovOn = false, Fov = 70,
        AspectOn = false, RatioX = 1, RatioY = 1,
    }
    World.Post = Post

    local FX = {
        Color = { Class = "ColorCorrectionEffect", Properties = { "Saturation", "Contrast", "Brightness" } },
        Bloom = { Class = "BloomEffect", Properties = { "Intensity", "Size", "Threshold" } },
        Rays = { Class = "SunRaysEffect", Properties = { "Intensity", "Spread" } },
        Blur = { Class = "BlurEffect", Properties = { "Size" } },
    }
    local fxOwned, fxSaved = {}, {}
    local atmosphereOwned = false

    local function fxGet(key)
        local spec = FX[key]
        local effect = Lighting:FindFirstChildOfClass(spec.Class)
        if not effect then
            effect = Instance.new(spec.Class)
            effect.Name = "EnderHubPost" .. spec.Class
            effect.Enabled = false
            effect.Parent = Lighting
            fxOwned[key] = true
        end
        if not fxSaved[key] then
            local saved = { Enabled = effect.Enabled }
            for _, property in ipairs(spec.Properties) do
                saved[property] = effect[property]
            end
            fxSaved[key] = saved
        end
        return effect
    end

    local function fxApply(key, on, values)
        local effect = Lighting:FindFirstChildOfClass(FX[key].Class)
        if on then
            effect = fxGet(key)
            for property, value in next, values do
                effect[property] = value
            end
            effect.Enabled = true
            return
        end
        local saved = fxSaved[key]
        if fxOwned[key] then
            if effect then
                effect:Destroy()
            end
            fxOwned[key] = nil
            fxSaved[key] = nil
        elseif effect and saved then
            for _, property in ipairs(FX[key].Properties) do
                effect[property] = saved[property]
            end
            effect.Enabled = saved.Enabled
        end
    end

    local cameraSaved = nil

    local function cameraApply()
        local camera = workspace.CurrentCamera
        if not camera then
            return
        end
        cameraSaved = cameraSaved or camera.FieldOfView
        camera.FieldOfView = Post.FovOn and math.clamp(Post.Fov, 20, 120) or cameraSaved
    end

    
    
    local stretchConn = nil

    local function aspectApply()
        if not Post.AspectOn then
            if stretchConn then
                stretchConn:Disconnect()
                stretchConn = nil
            end
            return
        end
        if stretchConn then
            return
        end
        local run = game:GetService("RunService")
        stretchConn = run.RenderStepped:Connect(function()
            local camera = workspace.CurrentCamera
            if not camera or not Post.AspectOn then
                return
            end
            local viewport = camera.ViewportSize

            
            local target = math.clamp(Post.RatioX / math.clamp(Post.RatioY, 1, 3), 1 / 3, 3)
            local scaleY = math.clamp(1 / target, 0.1, 4)
            camera.CFrame = camera.CFrame * CFrame.new(0, 0, 0, 1, 0, 0, 0, scaleY, 0, 0, 0, 1)
        end)
    end

    local function postApply()
        fxApply("Color", Post.ColorOn, {
            Saturation = Post.Saturation,
            Contrast = Post.Contrast,
            Brightness = Post.ColorBrightness,
        })
        fxApply("Bloom", Post.BloomOn, {
            Intensity = Post.BloomIntensity,
            Size = Post.BloomSize,
            Threshold = Post.BloomThreshold,
        })
        fxApply("Rays", Post.RaysOn, {
            Intensity = Post.RaysIntensity,
            Spread = Post.RaysSpread,
        })
        fxApply("Blur", Post.Blur > 0.5, { Size = Post.Blur })

        local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
        if Post.AtmosphereOn then
            if not atmosphere then
                atmosphere = Instance.new("Atmosphere")
                atmosphere.Name = "EnderHubAtmosphere"
                atmosphere.Parent = Lighting
                atmosphereOwned = true
            end
            atmosphere.Density = math.clamp(Post.Haze, 0, 1)
        elseif atmosphereOwned and atmosphere then
            atmosphere:Destroy()
            atmosphereOwned = false
        end

        cameraApply()
        aspectApply()
    end
    Visuals.PostApply = postApply

    local function postReset()
        Post.ColorOn = false
        Post.BloomOn = false
        Post.RaysOn = false
        Post.AtmosphereOn = false
        Post.Blur = 0
        Post.FovOn = false
        Post.AspectOn = false
        for key in next, FX do
            fxApply(key, false, nil)
        end
        local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
        if atmosphereOwned and atmosphere then
            atmosphere:Destroy()
            atmosphereOwned = false
        end
        local camera = workspace.CurrentCamera
        if camera and cameraSaved then
            camera.FieldOfView = cameraSaved
        end
        if stretchConn then
            stretchConn:Disconnect()
            stretchConn = nil
        end
    end

    local function worldReset()
        local saved = World.Saved
        if not saved then
            return
        end
        local sky = Lighting:FindFirstChildOfClass("Sky")
        if sky then
            for _, property in ipairs(SKY_FACES) do
                sky[property] = saved.Faces[property] or ""
            end
            sky.StarCount = saved.StarCount
            if not saved.HadSky then
                sky:Destroy()
            end
        end
        Lighting.FogColor = saved.FogColor
        Lighting.FogStart = saved.FogStart
        Lighting.FogEnd = saved.FogEnd
        Lighting.Brightness = saved.Brightness
        Lighting.ClockTime = saved.ClockTime
        Lighting.Ambient = saved.Ambient
        Lighting.ExposureCompensation = saved.ExposureCompensation
        Lighting.GlobalShadows = saved.GlobalShadows
        Lighting.EnvironmentSpecularScale = saved.EnvironmentSpecularScale or 0
        Lighting.EnvironmentDiffuseScale = saved.EnvironmentDiffuseScale or 1
        workspace.GlobalWind = saved.GlobalWind or workspace.GlobalWind
        local terrain = workspace:FindFirstChildOfClass("Terrain")
        local clouds = terrain and terrain:FindFirstChild("EnderHubClouds")
        if clouds then
            clouds:Destroy()
        end
        postReset()
        World.Weather.On = true
        World.Weather.Mode = "Clear"
        World.Weather.Rain = false
        World.Weather.Snow = false
        if Visuals.WeatherApply then
            Visuals.WeatherApply()
        end
        if Visuals.WetReset then
            Visuals.WetReset()
        end
        if Visuals.AmbienceReset then
            Visuals.AmbienceReset()
        end
    end
    Visuals.ResetWorld = worldReset

    
    
    local CloudState = {
        On = true,
        Cover = 0.45,
        Density = 0.35,
        Color = Color3.fromRGB(255, 255, 255),
        Wind = 18,
        Direction = 90,
    }
    World.Clouds = CloudState

    local function cloudsApply()
        local terrain = workspace:FindFirstChildOfClass("Terrain")
        if not terrain then
            return
        end
        local clouds = terrain:FindFirstChildOfClass("Clouds")
        if not clouds then
            clouds = Instance.new("Clouds")
            clouds.Name = "EnderHubClouds"
            clouds.Parent = terrain
        end
        clouds.Enabled = CloudState.On
        clouds.Cover = math.clamp(CloudState.Cover, 0, 1)
        clouds.Density = math.clamp(CloudState.Density, 0, 1)
        clouds.Color = CloudState.Color
        local radians = math.rad(CloudState.Direction)
        workspace.GlobalWind = Vector3.new(math.cos(radians) * CloudState.Wind, 0, math.sin(radians) * CloudState.Wind)
    end
    Visuals.CloudsApply = cloudsApply

    

    local function atmosphereApply(spec)
        local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
        if not spec then
            if atmosphere and atmosphereOwned then
                atmosphere:Destroy()
            end
            atmosphereOwned = false
            return
        end
        if not atmosphere then
            atmosphere = Instance.new("Atmosphere")
            atmosphere.Name = "EnderHubAtmosphere"
            atmosphere.Parent = Lighting
            atmosphereOwned = true
        end
        atmosphere.Density = spec.Density
        atmosphere.Haze = spec.Haze
        atmosphere.Color = spec.Color
        atmosphere.Decay = spec.Decay or Color3.fromRGB(106, 112, 125)
        atmosphere.Glare = spec.Glare or 0
        atmosphere.Offset = spec.Offset or 0.25
    end

    

    local LOOKS = {
        ["Default"] = false,
        ["Golden Hour"] = {
            ClockTime = 17.4, Brightness = 2.5, Ambient = Color3.fromRGB(104, 84, 74), Exposure = 0.1,
            Fog = { Color3.fromRGB(255, 182, 128), 160, 3400 },
            Clouds = { Cover = 0.52, Density = 0.42, Color = Color3.fromRGB(255, 200, 176) },
            Atmosphere = { Density = 0.34, Haze = 1.6, Color = Color3.fromRGB(255, 196, 160) },
        },
        ["Clear Noon"] = {
            ClockTime = 12.5, Brightness = 2.8, Ambient = Color3.fromRGB(96, 104, 120), Exposure = 0,
            Fog = { Color3.fromRGB(196, 214, 236), 320, 6000 },
            Clouds = { Cover = 0.34, Density = 0.3, Color = Color3.fromRGB(255, 255, 255) },
            Atmosphere = { Density = 0.28, Haze = 0.8, Color = Color3.fromRGB(214, 226, 240) },
        },
        ["Sunset"] = {
            ClockTime = 18.05, Brightness = 1.9, Ambient = Color3.fromRGB(112, 76, 82), Exposure = 0.15,
            Fog = { Color3.fromRGB(255, 148, 112), 120, 2800 },
            Clouds = { Cover = 0.46, Density = 0.4, Color = Color3.fromRGB(255, 168, 148) },
            Atmosphere = { Density = 0.42, Haze = 2.1, Color = Color3.fromRGB(255, 156, 122) },
        },
        ["Dawn"] = {
            ClockTime = 6.2, Brightness = 1.6, Ambient = Color3.fromRGB(84, 92, 126), Exposure = 0.25,
            Fog = { Color3.fromRGB(178, 176, 214), 180, 3600 },
            Clouds = { Cover = 0.5, Density = 0.44, Color = Color3.fromRGB(216, 200, 236) },
            Atmosphere = { Density = 0.38, Haze = 1.8, Color = Color3.fromRGB(196, 186, 232) },
        },
        ["Overcast"] = {
            ClockTime = 11, Brightness = 1.5, Ambient = Color3.fromRGB(104, 108, 116), Exposure = -0.1,
            Fog = { Color3.fromRGB(168, 174, 184), 90, 2400 },
            Clouds = { Cover = 0.86, Density = 0.72, Color = Color3.fromRGB(186, 192, 202) },
            Atmosphere = { Density = 0.5, Haze = 2.6, Color = Color3.fromRGB(176, 182, 192) },
        },
        ["Rainy"] = {
            ClockTime = 14.2, Brightness = 1.1, Ambient = Color3.fromRGB(72, 78, 92), Exposure = -0.25,
            Fog = { Color3.fromRGB(122, 132, 148), 55, 1500 },
            Clouds = { Cover = 0.93, Density = 0.88, Color = Color3.fromRGB(132, 140, 154) },
            Atmosphere = { Density = 0.58, Haze = 3.2, Color = Color3.fromRGB(138, 148, 164) },
        },
        ["Storm"] = {
            ClockTime = 15, Brightness = 1.2, Ambient = Color3.fromRGB(58, 62, 72), Exposure = -0.3,
            Fog = { Color3.fromRGB(118, 126, 140), 60, 1400 },
            Clouds = { Cover = 0.95, Density = 0.9, Color = Color3.fromRGB(120, 128, 142) },
            Atmosphere = { Density = 0.55, Haze = 3, Color = Color3.fromRGB(150, 158, 172) },
        },
        ["Midnight"] = {
            ClockTime = 0.4, Brightness = 0.8, Ambient = Color3.fromRGB(34, 40, 60), Exposure = 0.2,
            Fog = { Color3.fromRGB(20, 26, 42), 120, 2600 },
            Clouds = { Cover = 0.4, Density = 0.35, Color = Color3.fromRGB(60, 70, 100) },
            Atmosphere = { Density = 0.3, Haze = 1.2, Color = Color3.fromRGB(40, 52, 82) },
        },
        ["Neon City"] = {
            ClockTime = 21.5, Brightness = 1.4, Ambient = Color3.fromRGB(70, 40, 96), Exposure = 0.35,
            Fog = { Color3.fromRGB(96, 40, 140), 80, 1800 },
            Clouds = { Cover = 0.6, Density = 0.5, Color = Color3.fromRGB(180, 120, 255) },
            Atmosphere = { Density = 0.42, Haze = 2, Color = Color3.fromRGB(150, 90, 220) },
        },
        ["Snowfield"] = {
            ClockTime = 9, Brightness = 2.4, Ambient = Color3.fromRGB(150, 164, 184), Exposure = 0.1,
            Fog = { Color3.fromRGB(214, 226, 240), 90, 2200 },
            Clouds = { Cover = 0.7, Density = 0.55, Color = Color3.fromRGB(236, 242, 250) },
            Atmosphere = { Density = 0.4, Haze = 2.4, Color = Color3.fromRGB(226, 236, 248) },
        },
        ["Toxic"] = {
            ClockTime = 13, Brightness = 1.8, Ambient = Color3.fromRGB(60, 90, 60), Exposure = 0.2,
            Fog = { Color3.fromRGB(120, 190, 90), 70, 1600 },
            Clouds = { Cover = 0.65, Density = 0.6, Color = Color3.fromRGB(150, 220, 120) },
            Atmosphere = { Density = 0.45, Haze = 2.2, Color = Color3.fromRGB(140, 210, 110) },
        },
        ["Deep Space"] = {
            ClockTime = 0, Brightness = 0.3, Ambient = Color3.fromRGB(18, 20, 34), Exposure = 0.5,
            Fog = { Color3.fromRGB(8, 10, 20), 400, 9000 },
            Clouds = { Cover = 0.05, Density = 0.05, Color = Color3.fromRGB(30, 34, 54) },
            Atmosphere = { Density = 0.12, Haze = 0.4, Color = Color3.fromRGB(30, 40, 70) },
            Faces = "nebula",
        },
        ["Aurora"] = {
            ClockTime = 1.2, Brightness = 0.9, Ambient = Color3.fromRGB(30, 52, 54), Exposure = 0.4,
            Fog = { Color3.fromRGB(18, 52, 58), 140, 3200 },
            Clouds = { Cover = 0.3, Density = 0.28, Color = Color3.fromRGB(90, 220, 190) },
            Atmosphere = { Density = 0.35, Haze = 1.4, Color = Color3.fromRGB(80, 220, 190) },
        },
        ["Blood Moon"] = {
            ClockTime = 0.8, Brightness = 0.7, Ambient = Color3.fromRGB(64, 26, 26), Exposure = 0.3,
            Fog = { Color3.fromRGB(56, 18, 22), 160, 3000 },
            Clouds = { Cover = 0.5, Density = 0.45, Color = Color3.fromRGB(150, 70, 70) },
            Atmosphere = { Density = 0.4, Haze = 1.8, Color = Color3.fromRGB(160, 60, 60) },
            Faces = "nebula",
        },
        ["Desert"] = {
            ClockTime = 13.5, Brightness = 3.2, Ambient = Color3.fromRGB(150, 124, 88), Exposure = 0.25,
            Fog = { Color3.fromRGB(226, 196, 150), 220, 5200 },
            Clouds = { Cover = 0.18, Density = 0.16, Color = Color3.fromRGB(255, 236, 206) },
            Atmosphere = { Density = 0.3, Haze = 1.4, Color = Color3.fromRGB(240, 212, 170) },
        },
        ["Volcanic"] = {
            ClockTime = 16.5, Brightness = 1.4, Ambient = Color3.fromRGB(70, 40, 32), Exposure = 0.1,
            Fog = { Color3.fromRGB(84, 42, 30), 90, 2200 },
            Clouds = { Cover = 0.78, Density = 0.7, Color = Color3.fromRGB(120, 66, 48) },
            Atmosphere = { Density = 0.55, Haze = 2.8, Color = Color3.fromRGB(150, 70, 40) },
        },
        ["Sakura"] = {
            ClockTime = 8.5, Brightness = 2.6, Ambient = Color3.fromRGB(150, 120, 138), Exposure = 0.2,
            Fog = { Color3.fromRGB(240, 204, 220), 200, 4000 },
            Clouds = { Cover = 0.42, Density = 0.38, Color = Color3.fromRGB(255, 214, 232) },
            Atmosphere = { Density = 0.32, Haze = 1.5, Color = Color3.fromRGB(248, 214, 232) },
        },
        ["Cyberpunk"] = {
            ClockTime = 22, Brightness = 1.2, Ambient = Color3.fromRGB(56, 34, 86), Exposure = 0.45,
            Fog = { Color3.fromRGB(48, 22, 76), 70, 1700 },
            Clouds = { Cover = 0.55, Density = 0.5, Color = Color3.fromRGB(110, 70, 190) },
            Atmosphere = { Density = 0.42, Haze = 2.2, Color = Color3.fromRGB(120, 60, 210) },
        },
        ["Frozen Dusk"] = {
            ClockTime = 5.6, Brightness = 1.4, Ambient = Color3.fromRGB(96, 108, 140), Exposure = 0.25,
            Fog = { Color3.fromRGB(196, 214, 240), 120, 2600 },
            Clouds = { Cover = 0.66, Density = 0.58, Color = Color3.fromRGB(214, 226, 246) },
            Atmosphere = { Density = 0.45, Haze = 2.4, Color = Color3.fromRGB(200, 218, 244) },
        },
        ["Meteor Shower"] = {
            ClockTime = 2.5, Brightness = 0.5, Ambient = Color3.fromRGB(24, 26, 44), Exposure = 0.55,
            Fog = { Color3.fromRGB(10, 12, 26), 380, 8500 },
            Clouds = { Cover = 0.1, Density = 0.1, Color = Color3.fromRGB(40, 44, 70) },
            Atmosphere = { Density = 0.16, Haze = 0.5, Color = Color3.fromRGB(40, 50, 90) },
            Faces = "nebula",
        },
        ["Alien World"] = {
            ClockTime = 10.5, Brightness = 1.7, Ambient = Color3.fromRGB(40, 86, 70), Exposure = 0.3,
            Fog = { Color3.fromRGB(70, 150, 120), 90, 2400 },
            Clouds = { Cover = 0.6, Density = 0.55, Color = Color3.fromRGB(120, 220, 170) },
            Atmosphere = { Density = 0.48, Haze = 2.4, Color = Color3.fromRGB(100, 220, 170) },
        },
        ["Foggy Hollow"] = {
            ClockTime = 7.4, Brightness = 1.3, Ambient = Color3.fromRGB(96, 102, 100), Exposure = -0.15,
            Fog = { Color3.fromRGB(176, 184, 180), 30, 900 },
            Clouds = { Cover = 0.7, Density = 0.6, Color = Color3.fromRGB(196, 202, 198) },
            Atmosphere = { Density = 0.62, Haze = 3.6, Color = Color3.fromRGB(188, 196, 192) },
        },
    }

    local LOOK_NAMES = {
        "Default", "Clear Noon", "Sunny Morning", "Golden Hour", "Sunset",
        "Dusk", "Dawn", "Overcast", "Rainy Afternoon", "Stormy",
        "Foggy Morning", "Snowy Day", "Night",
    }

    
    LOOKS["Sunny Morning"] = {
        ClockTime = 8.6, Brightness = 2.6, Ambient = Color3.fromRGB(110, 116, 128), Exposure = 0.05,
        Fog = { Color3.fromRGB(206, 220, 236), 300, 5200 },
        Clouds = { Cover = 0.3, Density = 0.26, Color = Color3.fromRGB(255, 255, 255) },
        Atmosphere = { Density = 0.24, Haze = 0.6, Color = Color3.fromRGB(218, 230, 244) },
    }
    LOOKS["Dusk"] = {
        ClockTime = 19.4, Brightness = 1.3, Ambient = Color3.fromRGB(72, 62, 86), Exposure = 0.18,
        Fog = { Color3.fromRGB(196, 132, 150), 140, 3000 },
        Clouds = { Cover = 0.55, Density = 0.48, Color = Color3.fromRGB(214, 150, 170) },
        Atmosphere = { Density = 0.42, Haze = 2, Color = Color3.fromRGB(208, 146, 168) },
    }
    LOOKS["Rainy Afternoon"] = LOOKS["Rainy"]
    LOOKS["Stormy"] = LOOKS["Storm"]
    LOOKS["Foggy Morning"] = LOOKS["Foggy Hollow"]
    LOOKS["Snowy Day"] = LOOKS["Snowfield"]
    LOOKS["Night"] = LOOKS["Midnight"]

    local LOOK_KEYS = {
        ["Default"] = "LOOK_DEFAULT",
        ["Clear Noon"] = "LOOK_CLEAR_NOON",
        ["Sunny Morning"] = "LOOK_SUNNY_MORNING",
        ["Golden Hour"] = "LOOK_GOLDEN_HOUR",
        ["Sunset"] = "LOOK_SUNSET",
        ["Dusk"] = "LOOK_DUSK",
        ["Dawn"] = "LOOK_DAWN",
        ["Overcast"] = "LOOK_OVERCAST",
        ["Rainy Afternoon"] = "LOOK_RAINY_AFTERNOON",
        ["Stormy"] = "LOOK_STORMY",
        ["Foggy Morning"] = "LOOK_FOGGY_MORNING",
        ["Snowy Day"] = "LOOK_SNOWY_DAY",
        ["Night"] = "LOOK_NIGHT",
    }

    local function lookApply(name)
        local look = LOOKS[name]
        worldSave()
        if not look then
            local saved = World.Saved
            World.FogOn = false
            World.ClockTime = saved.ClockTime
            World.Brightness = saved.Brightness
            World.Ambient = saved.Ambient
            World.Exposure = saved.ExposureCompensation
            World.Shadows = saved.GlobalShadows
            atmosphereApply(nil)
            skyApply(nil)
            lightApply()
            fogApply()
            return
        end
        World.ClockTime = look.ClockTime
        World.Brightness = look.Brightness
        World.Ambient = look.Ambient
        World.Exposure = look.Exposure
        World.FogColor = look.Fog[1]
        World.FogStart = look.Fog[2]
        World.FogEnd = look.Fog[3]
        World.FogOn = true
        CloudState.Cover = look.Clouds.Cover
        CloudState.Density = look.Clouds.Density
        CloudState.Color = look.Clouds.Color
        lightApply()
        fogApply()
        cloudsApply()
        atmosphereApply(look.Atmosphere)

        if look.Faces == "nebula" then
            skyApply(SKY_PRESETS["Purple Nebula"])
        end
    end
    Visuals.LookApply = lookApply

    
    
    local Weather = {
        On = true,
        Rain = false,
        Snow = false,
        Mode = "Clear",
        Intensity = 55,
        Speed = 55,
        Size = 1,
        Color = Color3.fromRGB(206, 226, 255),
        Area = 60,
        Streak = 1.6,
    }
    World.Weather = Weather

    
    local RAIN_TEXTURE = "rbxassetid://1822856633"
    local SNOW_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

    local weatherPart, rainEmitter, snowEmitter

    local function weatherEnsure()
        if weatherPart and weatherPart.Parent then
            return
        end

        for _, stale in ipairs(workspace:GetChildren()) do
            if stale.Name == "EnderHubWeather" then
                stale:Destroy()
            end
        end
        weatherPart = Instance.new("Part")
        weatherPart.Name = "EnderHubWeather"
        weatherPart.Size = Vector3.new(1, 1, 1)
        weatherPart.Transparency = 1
        weatherPart.Anchored = true
        weatherPart.CanCollide = false
        weatherPart.CanQuery = false
        weatherPart.CanTouch = false
        weatherPart.CastShadow = false
        weatherPart.Locked = true
        weatherPart.Parent = workspace

        rainEmitter = Instance.new("ParticleEmitter")
        rainEmitter.Name = "Rain"
        rainEmitter.Shape = Enum.ParticleEmitterShape.Box
        rainEmitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
        rainEmitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
        rainEmitter.EmissionDirection = Enum.NormalId.Bottom
        rainEmitter.Lifetime = NumberRange.new(0.55, 0.95)
        rainEmitter.Acceleration = Vector3.new(0, -85, 0)
        rainEmitter.SpreadAngle = Vector2.new(1, 1)
        rainEmitter.LightEmission = 0.3

        rainEmitter.Squash = NumberSequence.new(1.6)
        rainEmitter.WindAffectsDrag = true
        rainEmitter.Drag = 0.4
        rainEmitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.3),
            NumberSequenceKeypoint.new(1, 0.85),
        })
        rainEmitter.Enabled = false
        rainEmitter.Parent = weatherPart

        snowEmitter = Instance.new("ParticleEmitter")
        snowEmitter.Name = "Snow"
        snowEmitter.Shape = Enum.ParticleEmitterShape.Box
        snowEmitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
        snowEmitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
        snowEmitter.EmissionDirection = Enum.NormalId.Bottom
        snowEmitter.Lifetime = NumberRange.new(5, 9)
        snowEmitter.Acceleration = Vector3.new(0, -2.5, 0)
        snowEmitter.SpreadAngle = Vector2.new(24, 24)
        snowEmitter.Rotation = NumberRange.new(0, 360)
        snowEmitter.RotSpeed = NumberRange.new(-24, 24)
        snowEmitter.WindAffectsDrag = true
        snowEmitter.Drag = 2.2
        snowEmitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.15),
            NumberSequenceKeypoint.new(1, 0.7),
        })
        snowEmitter.Enabled = false
        snowEmitter.Parent = weatherPart
    end

    
    
    local function weatherApply()
        weatherEnsure()
        local area = math.clamp(Weather.Area, 20, 400)
        weatherPart.Size = Vector3.new(area, 2, area)
        local cam = workspace.CurrentCamera
        local origin = cam and cam.CFrame.Position or Vector3.zero
        weatherPart.CFrame = CFrame.new(origin + Vector3.new(0, 30, 0))

        local rainSize = math.max(0.05, Weather.Size * 0.5)
        local snowSize = math.max(0.1, Weather.Size * 0.55)

        rainEmitter.Texture = RAIN_TEXTURE
        rainEmitter.Enabled = Weather.On == true and Weather.Rain == true

        rainEmitter.LightEmission = rainEmitter.Enabled and 1 or 0.3
        rainEmitter.Rate = math.clamp(Weather.Intensity * 45, 0, 6000)
        rainEmitter.Speed = NumberRange.new(Weather.Speed * 0.9, Weather.Speed * 1.2)
        rainEmitter.Lifetime = NumberRange.new(1.1, 1.5)
        rainEmitter.Size = NumberSequence.new(rainSize)
        rainEmitter.Squash = NumberSequence.new(math.clamp(Weather.Streak, 1, 4))
        rainEmitter.Color = ColorSequence.new(Weather.Color)

        snowEmitter.Texture = SNOW_TEXTURE
        snowEmitter.Enabled = Weather.On == true and Weather.Snow == true
        snowEmitter.Rate = math.clamp(Weather.Intensity * 6, 0, 1200)
        snowEmitter.Speed = NumberRange.new(2, 5)
        snowEmitter.Lifetime = NumberRange.new(9, 14)
        snowEmitter.Size = NumberSequence.new(snowSize)
        snowEmitter.Color = ColorSequence.new(Weather.Color)
    end
    Visuals.WeatherApply = weatherApply

    

    local Wet = {
        On = false,
        Strength = 0.55,
        Quality = "Medium",
    }
    World.Wet = Wet

    local WET_QUALITY = {
        Low = { Specular = 0.55 },
        Medium = { Specular = 0.8 },
        High = { Specular = 1 },
    }

    local function wetApply()
        worldSave()
        local quality = WET_QUALITY[Wet.Quality] or WET_QUALITY.Medium
        if not Wet.On then
            Lighting.EnvironmentSpecularScale = World.Saved.EnvironmentSpecularScale or 0
            Lighting.EnvironmentDiffuseScale = World.Saved.EnvironmentDiffuseScale or 1
            return
        end
        Lighting.EnvironmentSpecularScale = math.clamp(Wet.Strength * quality.Specular, 0, 1)
        Lighting.EnvironmentDiffuseScale = math.clamp(0.35 + Wet.Strength * 0.65, 0, 1)
    end
    Visuals.WetApply = wetApply
    Visuals.WetTune = wetApply

    local function wetReset()
        Wet.On = false
        if World.Saved then
            Lighting.EnvironmentSpecularScale = World.Saved.EnvironmentSpecularScale or 0
            Lighting.EnvironmentDiffuseScale = World.Saved.EnvironmentDiffuseScale or 1
        end
    end
    Visuals.WetReset = wetReset

    
    
    local SoundService = game:GetService("SoundService")
    local Ambient = {
        On = true,
        RainOn = false,
        WindOn = false,
        ThunderOn = false,
        Volume = 0.4,
    }
    World.AmbientSound = Ambient

    
    local AMBIENCE_IDS = {
        Rain = "rbxassetid://1516791621",
        Wind = "rbxassetid://116565742544806",
        Thunder = "rbxassetid://9120016037",
    }
    local ambienceSounds = {}
    local ambienceFolder = nil

    local function ambienceEnsure()
        if ambienceSounds.Rain and ambienceSounds.Rain.Parent then
            return
        end
        if not ambienceFolder or not ambienceFolder.Parent then
            ambienceFolder = Instance.new("Folder")
            ambienceFolder.Name = "EnderHubAmbience"
            ambienceFolder.Parent = SoundService
        end
        for name, id in next, AMBIENCE_IDS do
            local sound = ambienceSounds[name]
            if not sound or not sound.Parent then
                sound = Instance.new("Sound")
                sound.Name = "EnderHub" .. name
                sound.SoundId = id
                sound.Looped = name ~= "Thunder"
                sound.Volume = 0
                sound.Parent = ambienceFolder
                ambienceSounds[name] = sound
            end
        end
    end

    local function ambienceApply()
        ambienceEnsure()
        local volume = math.clamp(Ambient.Volume, 0, 1)
        local rainOn = Ambient.On == true and Ambient.RainOn == true
        local windOn = Ambient.On == true and Ambient.WindOn == true

        local rain = ambienceSounds.Rain
        rain.Volume = rainOn and volume * 0.55 or 0
        if rainOn then
            if not rain.IsPlaying then
                rain:Play()
            end
        elseif rain.IsPlaying then
            rain:Stop()
        end

        local wind = ambienceSounds.Wind
        wind.Volume = windOn and volume * 0.4 or 0
        if windOn then
            if not wind.IsPlaying then
                wind:Play()
            end
        elseif wind.IsPlaying then
            wind:Stop()
        end

        local thunder = ambienceSounds.Thunder
        if (Ambient.On ~= true or not Ambient.ThunderOn) and thunder.IsPlaying then
            thunder:Stop()
        end
    end
    Visuals.AmbienceApply = ambienceApply

    local function ambienceReset()
        Ambient.RainOn = false
        Ambient.WindOn = false
        Ambient.ThunderOn = false
        if ambienceSounds.Rain then
            ambienceSounds.Rain:Stop()
        end
        if ambienceSounds.Wind then
            ambienceSounds.Wind:Stop()
        end
        if ambienceSounds.Thunder then
            ambienceSounds.Thunder:Stop()
        end
    end
    Visuals.AmbienceReset = ambienceReset

    if not HX.thunderLoop then
        HX.thunderLoop = task.spawn(function()
            while true do
                task.wait(math.random(9, 26))
                local thunder = ambienceSounds.Thunder
                if Ambient.On and Ambient.ThunderOn and thunder and thunder.Parent then
                    thunder.Volume = math.clamp(Ambient.Volume, 0, 1) * 0.85
                    thunder:Play()
                end
            end
        end)
    end

    
    
    local WEATHER_MODES = {
        Clear = { Rain = false, Snow = false },
        Rain = { Rain = true, Snow = false, Intensity = 60, Speed = 60, Size = 1.1, Streak = 1.8 },
        Storm = { Rain = true, Snow = false, Intensity = 95, Speed = 78, Size = 1.25, Streak = 2 },
        Snow = { Rain = false, Snow = true, Intensity = 65, Speed = 22, Size = 1.1 },
    }

    local function weatherModeApply(mode)
        local spec = WEATHER_MODES[mode]
        if not spec then
            return
        end
        Weather.Mode = mode
        Weather.Rain = spec.Rain
        Weather.Snow = spec.Snow
        if spec.Intensity then Weather.Intensity = spec.Intensity end
        if spec.Speed then Weather.Speed = spec.Speed end
        if spec.Size then Weather.Size = spec.Size end
        if spec.Streak then Weather.Streak = spec.Streak end
        weatherApply()
    end
    Visuals.WeatherModeApply = weatherModeApply

    
    
    if HX.weatherLoop then
        HX.weatherLoop:Disconnect()
        HX.weatherLoop = nil
    end
    if not HX.weatherLoop then
        HX.weatherLoop = RunService.RenderStepped:Connect(function()
            if not weatherPart or not weatherPart.Parent then
                return
            end
            local cam = workspace.CurrentCamera
            if cam then
                weatherPart.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 30, 0))
            end
        end)
    end

    
    
    if HX.skyMotionLoop then
        HX.skyMotionLoop:Disconnect()
        HX.skyMotionLoop = nil
    end
    HX.skyMotionLoop = RunService.RenderStepped:Connect(function(dt)
        if not World.Motion then
            return
        end
        World.ClockTime = (World.ClockTime + World.MotionSpeed * dt) % 24
        Lighting.ClockTime = World.ClockTime
    end)

    

    local function syncPreview()
        if not HX.EspPreview then
            return
        end
        HX.EspPreview:SetESP(HX.EspStyle)
        HX.EspPreview:SetCursorState(Cursor)
    end

    HX.ESPTab:Section({
        Title = "Visuals",
        Icon = "eye",
        TextSize = 22,
    })
    HX.ESPTab:Space({ Columns = 0.5 })

    HX.ESPTab:Section({ Title = "Box", Icon = "scan-eye", TextSize = 20 })
    HX.ESPTab:Space({ Columns = 0.5 })

    local boxPill = HX.ESPTab:VStack({})
    local boxRow = boxPill:HStack({})
    boxRow:Toggle({
        Title = "Box",
        Value = HX.EspStyle.Box,
        Callback = function(state)
            HX.EspStyle.Box = state == true
            syncPreview()
        end,
    })
    boxRow:Toggle({
        Title = "Brackets",
        Value = HX.EspStyle.Brackets,
        Callback = function(state)
            HX.EspStyle.Brackets = state == true
            syncPreview()
        end,
    })

    boxPill:Colorpicker({
        Title = "Box color",
        Default = HX.EspStyle.BoxColor,
        Callback = function(color)
            HX.EspStyle.BoxColor = color
            syncPreview()
        end,
    })

    boxPill:Slider({
        Title = "Fill",
        Step = 5,
        Value = { Min = 0, Max = 100, Default = 0 },
        Icons = { From = "minus", To = "plus" },
        Callback = function(value)
            HX.EspStyle.Fill = value / 100
            syncPreview()
        end,
    })

    boxPill:Slider({
        Title = "Thickness",
        Step = 1,
        Value = { Min = 1, Max = 4, Default = HX.EspStyle.Thickness },
        Icons = { From = "minus", To = "plus" },
        Callback = function(value)
            HX.EspStyle.Thickness = value
            syncPreview()
        end,
    })

    HX.ESPTab:Space({ Columns = 0.5 })

    HX.ESPTab:Section({ Title = "Text", Icon = "focus", TextSize = 20 })
    HX.ESPTab:Space({ Columns = 0.5 })

    local textPill = HX.ESPTab:VStack({})
    local textRow = textPill:HStack({})
    textRow:Toggle({
        Title = "Name",
        Value = HX.EspStyle.Name,
        Callback = function(state)
            HX.EspStyle.Name = state == true
            syncPreview()
        end,
    })
    textRow:Toggle({
        Title = "Distance",
        Value = HX.EspStyle.Distance,
        Callback = function(state)
            HX.EspStyle.Distance = state == true
            syncPreview()
        end,
    })

    textPill:Colorpicker({
        Title = "Text color",
        Default = HX.EspStyle.NameColor,
        Callback = function(color)
            HX.EspStyle.NameColor = color
            syncPreview()
        end,
    })

    textPill:Dropdown({
        Title = "Text side",
        Values = { "Above", "Below" },
        Value = HX.EspStyle.TextSide,
        Callback = function(option)
            local name = type(option) == "table" and option.Title or option
            if type(name) ~= "string" then
                return
            end
            HX.EspStyle.TextSide = name
            syncPreview()
        end,
    })

    textPill:Slider({
        Title = "Text size",
        Step = 1,
        Value = { Min = 9, Max = 22, Default = HX.EspStyle.TextSize },
        Icons = { From = "minus", To = "plus" },
        Callback = function(value)
            HX.EspStyle.TextSize = value
            syncPreview()
        end,
    })

    HX.ESPTab:Space({ Columns = 0.5 })

    HX.ESPTab:Section({ Title = "Extras", Icon = "sparkle", TextSize = 20 })
    HX.ESPTab:Space({ Columns = 0.5 })

    local extraPill = HX.ESPTab:VStack({})
    local extraRow = extraPill:HStack({})
    extraRow:Toggle({
        Title = "Health bar",
        Value = HX.EspStyle.Health,
        Callback = function(state)
            HX.EspStyle.Health = state == true
            syncPreview()
        end,
    })
    extraRow:Toggle({
        Title = "Tracer",
        Value = HX.EspStyle.Tracer,
        Callback = function(state)
            HX.EspStyle.Tracer = state == true
            syncPreview()
        end,
    })

    extraPill:Slider({
        Title = "Scale",
        Step = 0.05,
        Value = { Min = 0.5, Max = 2, Default = 1 },
        Icons = { From = "minus", To = "plus" },
        Callback = function(value)
            HX.EspStyle.Scale = value
            syncPreview()
        end,
    })

    HX.ESPTab:Space({ Columns = 0.5 })

    HX.ESPTab:Section({ Title = "Layout", Icon = "maximize-2", TextSize = 20 })
    HX.ESPTab:Space({ Columns = 0.5 })

    HX.EspPreview = HX.ESPTab:Customize({
        Title = "Customize",
        Height = 190,

        Aspect = 0.56,
        ESP = HX.EspStyle,
        Cursor = Cursor,
        CursorDraw = paintCursor,
        OnChange = function(kind, key, value)
            if kind == "ESP" then
                HX.EspStyle[key] = value
            else
                Cursor[key] = value
                cursorBuild()
            end
        end,
    })

    
    HX.bootGenv.EnderHubEspStyle = HX.EspStyle

    HX.bootGenv.EnderHubVisuals = Visuals
    
    HX.bootGenv.EnderHubTabs = {
        World = HX.WorldTab,
        Visuals = HX.ESPTab,
        LocalPlayer = LocalPlayerTab,
        Settings = SettingsTab,
    }
    HX.bootGenv.EnderHubEspPreview = HX.EspPreview

    HX.bootGenv.EnderHubEspApi = {
        SetPlayers = function(on)
            HX.PlayersESPOn = on == true
            HX.updateAllESP()
            return HX.PlayersESPOn
        end,
        SetChosen = function(on)
            HX.ChosenESPOn = on == true
            HX.updateAllESP()
            return HX.ChosenESPOn
        end,
        Clear = function()
            HX.clearAllESP()
        end,
        Gui = function()
            return HX.espGui
        end,
    }

    HX.ESPTab:Section({
        Title = "Cursor",
        Icon = "mouse-pointer-2",
        TextSize = 20,
    })
    HX.ESPTab:Space({ Columns = 0.5 })

    local cursorPill = HX.ESPTab:VStack({})
    cursorPill:Toggle({
        Title = "Custom cursor",
        Value = false,
        Callback = function(state)
            cursorSet(state == true)
        end,
    })

    cursorPill:Dropdown({
        Title = "Preset",
        Values = CURSOR_PRESETS,
        Value = Cursor.Preset,
        Callback = function(option)
            local name = type(option) == "table" and option.Title or option
            if type(name) ~= "string" then
                return
            end
            Cursor.Preset = name
            cursorBuild()
            syncPreview()
        end,
    })

    cursorPill:Colorpicker({
        Title = "Color",
        Default = Cursor.Color,
        Callback = function(color)
            Cursor.Color = color
            cursorBuild()
            syncPreview()
        end,
    })

    cursorPill:Slider({
        Title = "Size",
        Step = 1,
        Value = { Min = 10, Max = 64, Default = Cursor.Size },
        Icons = { From = "minus", To = "plus" },
        Callback = function(value)
            Cursor.Size = value
            cursorBuild()
            syncPreview()
        end,
    })

    cursorPill:Slider({
        Title = "Thickness",
        Step = 0.01,
        Value = { Min = 0.04, Max = 0.2, Default = Cursor.Thickness },
        Icons = { From = "minus", To = "plus" },
        Callback = function(value)
            Cursor.Thickness = value
            cursorBuild()
            syncPreview()
        end,
    })

    HX.ESPTab:Space({ Columns = 0.5 })

    local motionPill = HX.ESPTab:VStack({})
    local motionRow = motionPill:HStack({})
    motionRow:Toggle({
        Title = "Spin",
        Value = false,
        Callback = function(state)
            Cursor.Spin = state == true
        end,
    })
    motionRow:Toggle({
        Title = "Bounce",
        Value = false,
        Callback = function(state)
            Cursor.Bounce = state == true
            Cursor.Phase = 0
        end,
    })
    motionPill:Toggle({
        Title = "Pulse",
        Value = false,
        Callback = function(state)
            Cursor.Pulse = state == true
            Cursor.PulsePhase = 0
        end,
    })

    motionPill:Slider({
        Title = "Spin speed",
        Step = 5,
        Value = { Min = 5, Max = 360, Default = Cursor.Speed },
        Icons = { From = "minus", To = "plus" },
        Callback = function(value)
            Cursor.Speed = value
        end,
    })

    motionPill:Slider({
        Title = "Bounce speed",
        Step = 0.1,
        Value = { Min = 0.2, Max = 12, Default = Cursor.BounceSpeed },
        Icons = { From = "minus", To = "plus" },
        Callback = function(value)
            Cursor.BounceSpeed = value
        end,
    })

    motionPill:Slider({
        Title = "Bounce height",
        Step = 1,
        Value = { Min = 1, Max = 40, Default = Cursor.BounceHeight },
        Icons = { From = "minus", To = "plus" },
        Callback = function(value)
            Cursor.BounceHeight = value
        end,
    })

    motionPill:Slider({
        Title = "Pulse speed",
        Step = 0.1,
        Value = { Min = 0.2, Max = 8, Default = Cursor.PulseSpeed },
        Icons = { From = "minus", To = "plus" },
        Callback = function(value)
            Cursor.PulseSpeed = value
        end,
    })

    motionPill:Slider({
        Title = "Pulse amount",
        Step = 0.01,
        Value = { Min = 0.02, Max = 0.6, Default = Cursor.PulseAmount },
        Icons = { From = "minus", To = "plus" },
        Callback = function(value)
            Cursor.PulseAmount = value
        end,
    })

    HX.ESPTab:Space({ Columns = 0.5 })

    HX.ESPTab:Section({ Title = "Avatar", Icon = "user-round", TextSize = 20 })
    HX.ESPTab:Space({ Columns = 0.5 })

    local avatarPill = HX.ESPTab:VStack({})
    local avatarRow = avatarPill:HStack({})
    avatarRow:Toggle({
        Title = "Material override",
        Value = false,
        Callback = function(state)
            Avatar.MaterialOn = state == true
            avatarApply()
        end,
    })
    avatarRow:Toggle({
        Title = "Color override",
        Value = false,
        Callback = function(state)
            Avatar.ColorOn = state == true
            avatarApply()
        end,
    })

    avatarPill:Dropdown({
        Title = "Material",
        Values = MATERIALS,
        Value = "Neon",
        Callback = function(option)
            local name = type(option) == "table" and option.Title or option
            local material = name and Enum.Material[name]
            if not material then
                return
            end
            Avatar.Material = material
            if Avatar.MaterialOn then
                avatarApply()
            end
        end,
    })

    avatarPill:Colorpicker({
        Title = "Avatar color",
        Default = Avatar.Color,
        Callback = function(color)
            Avatar.Color = color
            if Avatar.ColorOn then
                avatarApply()
            end
        end,
    })

    avatarPill:Button({
        Title = "Reset avatar",
        Icon = "rotate-ccw",
        Callback = function()
            Avatar.MaterialOn = false
            Avatar.ColorOn = false
            avatarApply()
        end,
    })

    

    
    local function worldShow(pills, index)
        for position, pill in ipairs(pills) do
            if pill.ElementFrame then
                pill.ElementFrame.Visible = position == index
            end
        end
    end

    
    
    local WORLD_CARD_PAD = 10
    local WORLD_STRIP_RADIUS = 16

    
    local WORLD_STRIP_INSET = 4
    local WORLD_SEGMENT_GAP = 4

    
    
    local WORLD_GLASS_IMAGE = "rbxassetid://84819521201001"
    local WORLD_GLASS_SLICE = Rect.new(512, 325, 512, 325)
    local WORLD_GLASS_RADIUS = 325

    local WORLD_SEGMENT_WASH = 0.9
    local WORLD_GLASS_TRANSPARENCY = 0.55

    local function worldStrip(titles, parent)
        local strip = Instance.new("Frame")
        strip.Name = "Strip"
        strip.BackgroundColor3 = Color3.new(1, 1, 1)
        strip.BackgroundTransparency = 1
        strip.Size = UDim2.new(1, WORLD_CARD_PAD * 2, 0, 40)
        strip.Parent = parent.ElementFrame

        local padding = Instance.new("UIPadding")
        padding.PaddingTop = UDim.new(0, WORLD_STRIP_INSET)
        padding.PaddingBottom = UDim.new(0, WORLD_STRIP_INSET)
        padding.PaddingLeft = UDim.new(0, WORLD_STRIP_INSET)
        padding.PaddingRight = UDim.new(0, WORLD_STRIP_INSET)
        padding.Parent = strip

        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, WORLD_SEGMENT_GAP)
        layout.Parent = strip

        local buttons, selected, callbacks = {}, 1, {}
        local count = #titles

        local function caption(text)
            if text:sub(1, 4) == "loc:" then
                return HX.translate(text:sub(5))
            end
            return text
        end

        
        local function paint()
            for index, segment in ipairs(buttons) do
                local on = index == selected
                segment.BackgroundTransparency = on and WORLD_SEGMENT_WASH or 1
                segment.TextTransparency = on and 0 or 0.5
                local glass = segment:FindFirstChild("Glass")
                if glass then
                    glass.Visible = on
                    glass.ImageTransparency = on and WORLD_GLASS_TRANSPARENCY or 1
                end
            end
        end

        local segmentRadius = (40 - WORLD_STRIP_INSET * 2) / 2

        for index, title in ipairs(titles) do
            local segment = Instance.new("TextButton")
            segment.Name = "Segment" .. index
            segment.LayoutOrder = index
            segment.Size = UDim2.new(1 / count, -WORLD_SEGMENT_GAP, 1, 0)
            segment.BackgroundColor3 = Color3.new(1, 1, 1)
            segment.BackgroundTransparency = 1
            segment.BorderSizePixel = 0
            segment.AutoButtonColor = false
            segment.Text = caption(title)
            segment.TextColor3 = Color3.new(1, 1, 1)
            segment.TextSize = 13
            segment.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium)
            segment.TextTransparency = 0.5
            segment.Parent = strip

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, segmentRadius)
            corner.Parent = segment

            
            segment.ZIndex = 2

            local glass = Instance.new("ImageLabel")
            glass.Name = "Glass"
            glass.Image = WORLD_GLASS_IMAGE
            glass.ScaleType = Enum.ScaleType.Slice
            glass.SliceCenter = WORLD_GLASS_SLICE
            glass.SliceScale = segmentRadius / WORLD_GLASS_RADIUS
            glass.BackgroundTransparency = 1
            glass.BorderSizePixel = 0
            glass.Size = UDim2.new(1, 0, 1, 0)
            glass.ZIndex = 1
            glass.Visible = false
            glass.Parent = segment

            
            local sheen = Instance.new("UIGradient")
            sheen.Rotation = 90
            sheen.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(0.6, 0.15),
                NumberSequenceKeypoint.new(1, 0.6),
            })
            sheen.Parent = glass

            buttons[index] = segment

            segment.MouseButton1Click:Connect(function()
                if selected == index then
                    return
                end
                selected = index
                paint()
                for _, callback in ipairs(callbacks) do
                    callback(index)
                end
            end)
        end

        paint()

        return function(callback)
            callbacks[#callbacks + 1] = callback
        end
    end

    local function worldSection(title, icon)
        HX.WorldTab:Section({
            Title = title,
            Icon = icon,
            TextSize = 20,
        })
    end

    
    
    local function worldCard()
        return HX.WorldTab:VStack({
            Card = true,
            CardPadding = WORLD_CARD_PAD,
            CardRadius = WORLD_STRIP_RADIUS,
        })
    end

    HX.WorldTab:Section({
        Title = "loc:WORLD_TAB",
        Icon = "globe",
        TextSize = 22,
    })

    worldSection("loc:WORLD_COLOR_GRADING", "palette")
    local gradePill = worldCard()
    local onGrade = worldStrip({ "loc:WORLD_COLOR", "loc:WORLD_HAZE" }, gradePill)

    local colorRows = gradePill:VStack({})
    colorRows:Toggle({
        Title = "loc:WORLD_COLOR_CORRECTION",
        Value = Post.ColorOn,
        Callback = function(state)
            Post.ColorOn = state
            postApply()
        end,
    })
    colorRows:Slider({
        Title = "loc:WORLD_SATURATION",
        Step = 0.05,
        Value = { Min = -1, Max = 1, Default = Post.Saturation },
        Callback = function(value)
            Post.Saturation = value
            postApply()
        end,
    })
    colorRows:Slider({
        Title = "loc:WORLD_CONTRAST",
        Step = 0.05,
        Value = { Min = -1, Max = 1, Default = Post.Contrast },
        Callback = function(value)
            Post.Contrast = value
            postApply()
        end,
    })
    colorRows:Slider({
        Title = "loc:WORLD_BRIGHTNESS",
        Step = 0.05,
        Value = { Min = -1, Max = 1, Default = Post.ColorBrightness },
        Callback = function(value)
            Post.ColorBrightness = value
            postApply()
        end,
    })

    local hazeRows = gradePill:VStack({})
    hazeRows:Toggle({
        Title = "loc:WORLD_ATMOSPHERE",
        Value = Post.AtmosphereOn,
        Callback = function(state)
            Post.AtmosphereOn = state
            postApply()
        end,
    })
    hazeRows:Slider({
        Title = "loc:WORLD_DENSITY",
        Step = 0.05,
        Value = { Min = 0, Max = 1, Default = Post.Haze },
        Callback = function(value)
            Post.Haze = value
            postApply()
        end,
    })

    worldShow({ colorRows, hazeRows }, 1)
    onGrade(function(index)
        worldShow({ colorRows, hazeRows }, index)
    end)

    

    worldSection("loc:WORLD_ENVIRONMENT", "cloud-sun")

    local envPill = worldCard()
    local onEnv = worldStrip({ "loc:WORLD_SKYBOX", "loc:WORLD_WEATHER", "loc:WORLD_AMBIENCE" }, envPill)

    local skyRows = envPill:VStack({})
    skyRows:Dropdown({
        Title = "loc:WORLD_SKYBOX",
        Values = {
            { Title = "loc:SKY_DEFAULT", Value = "Default" },
            { Title = "loc:SKY_CLEAR", Value = "Clear Sky" },
            { Title = "loc:SKY_BIG_SUN", Value = "Big Sun" },
            { Title = "loc:SKY_TINY_SUN", Value = "Tiny Sun" },
            { Title = "loc:SKY_FULL_MOON", Value = "Full Moon" },
            { Title = "loc:SKY_STARFIELD", Value = "Starfield" },
            { Title = "loc:SKY_MOONLESS", Value = "Moonless Night" },
            { Title = "loc:SKY_NEBULA", Value = "Purple Nebula" },
        },
        Value = "Default",
        Callback = function(option)
            local name = type(option) == "table" and option.Value or option
            skyApply(SKY_PRESETS[name])
        end,
    })
    skyRows:Dropdown({
        Title = "loc:WORLD_LOOK",
        Values = (function()
            local list = {}
            for _, name in ipairs(LOOK_NAMES) do
                list[#list + 1] = { Title = "loc:" .. LOOK_KEYS[name], Value = name }
            end
            return list
        end)(),
        Value = "Default",
        Callback = function(option)
            local name = type(option) == "table" and option.Value or option
            if type(name) == "string" then
                lookApply(name)
            end
        end,
    })

    
    local function weatherWet()
        Wet.On = Weather.On == true and (Weather.Rain == true or Weather.Snow == true)
        wetApply()
    end

    local weatherRows = envPill:VStack({})
    weatherRows:Dropdown({
        Title = "loc:WORLD_WEATHER",
        Values = {
            { Title = "loc:WORLD_WEATHER_CLEAR", Value = "Clear" },
            { Title = "loc:WORLD_WEATHER_RAIN", Value = "Rain" },
            { Title = "loc:WORLD_WEATHER_STORM", Value = "Storm" },
            { Title = "loc:WORLD_WEATHER_SNOW", Value = "Snow" },
        },
        Value = "Clear",
        Callback = function(option)
            local name = type(option) == "table" and option.Value or option
            weatherModeApply(name)
            weatherWet()
        end,
    })
    weatherRows:Toggle({
        Title = "loc:WORLD_WEATHER_TOGGLE",
        Value = Weather.On,
        Callback = function(state)
            Weather.On = state
            weatherApply()
            weatherWet()
        end,
    })

    
    local AMBIENCE_MODES = {
        Off = { Rain = false, Thunder = false },
        Rain = { Rain = true, Thunder = false, Volume = 0.45 },
        Thunder = { Rain = false, Thunder = true, Volume = 0.5 },
        Storm = { Rain = true, Thunder = true, Volume = 0.6 },
    }

    local ambienceRows = envPill:VStack({})
    ambienceRows:Dropdown({
        Title = "loc:WORLD_AMBIENCE",
        Values = {
            { Title = "loc:WORLD_AMBIENCE_OFF", Value = "Off" },
            { Title = "loc:WORLD_AMBIENCE_RAIN", Value = "Rain" },
            { Title = "loc:WORLD_AMBIENCE_THUNDER", Value = "Thunder" },
            { Title = "loc:WORLD_AMBIENCE_STORM", Value = "Storm" },
        },
        Value = "Off",
        Callback = function(option)
            local name = type(option) == "table" and option.Value or option
            local mode = AMBIENCE_MODES[name]
            if not mode then
                return
            end
            Ambient.On = name ~= "Off"
            Ambient.RainOn = mode.Rain
            Ambient.ThunderOn = mode.Thunder
            if mode.Volume then
                Ambient.Volume = mode.Volume
            end
            ambienceApply()
        end,
    })
    ambienceRows:Toggle({
        Title = "loc:WORLD_AMBIENCE_TOGGLE",
        Value = Ambient.On,
        Callback = function(state)
            Ambient.On = state
            ambienceApply()
        end,
    })

    worldShow({ skyRows, weatherRows, ambienceRows }, 1)
    onEnv(function(index)
        worldShow({ skyRows, weatherRows, ambienceRows }, index)
    end)

    worldSection("loc:WORLD_POST_FX", "sparkles")
    local postPill = worldCard()
    local onPost = worldStrip({ "loc:WORLD_BLOOM", "loc:WORLD_SUN_RAYS" }, postPill)

    local bloomRows = postPill:VStack({})
    bloomRows:Toggle({
        Title = "loc:WORLD_BLOOM",
        Value = Post.BloomOn,
        Callback = function(state)
            Post.BloomOn = state
            postApply()
        end,
    })
    bloomRows:Slider({
        Title = "loc:WORLD_INTENSITY",
        Step = 0.1,
        Value = { Min = 0, Max = 5, Default = Post.BloomIntensity },
        Callback = function(value)
            Post.BloomIntensity = value
            postApply()
        end,
    })
    bloomRows:Slider({
        Title = "loc:WORLD_SIZE",
        Step = 1,
        Value = { Min = 0, Max = 56, Default = Post.BloomSize },
        Callback = function(value)
            Post.BloomSize = value
            postApply()
        end,
    })
    bloomRows:Slider({
        Title = "loc:WORLD_THRESHOLD",
        Step = 0.1,
        Value = { Min = 0, Max = 5, Default = Post.BloomThreshold },
        Callback = function(value)
            Post.BloomThreshold = value
            postApply()
        end,
    })

    local raysRows = postPill:VStack({})
    raysRows:Toggle({
        Title = "loc:WORLD_SUN_RAYS",
        Value = Post.RaysOn,
        Callback = function(state)
            Post.RaysOn = state
            postApply()
        end,
    })
    raysRows:Slider({
        Title = "loc:WORLD_INTENSITY",
        Step = 0.05,
        Value = { Min = 0, Max = 1, Default = Post.RaysIntensity },
        Callback = function(value)
            Post.RaysIntensity = value
            postApply()
        end,
    })
    raysRows:Slider({
        Title = "loc:WORLD_SPREAD",
        Step = 0.05,
        Value = { Min = 0, Max = 1, Default = Post.RaysSpread },
        Callback = function(value)
            Post.RaysSpread = value
            postApply()
        end,
    })

    worldShow({ bloomRows, raysRows }, 1)
    onPost(function(index)
        worldShow({ bloomRows, raysRows }, index)
    end)

    
    local blurPill = postPill:VStack({})
    blurPill:Slider({
        Title = "loc:WORLD_BLUR",
        Step = 1,
        Value = { Min = 0, Max = 56, Default = Post.Blur },
        Callback = function(value)
            Post.Blur = value
            postApply()
        end,
    })

    worldSection("loc:WORLD_CAMERA", "camera")
    local cameraPill = worldCard()
    cameraPill:Toggle({
        Title = "loc:WORLD_FOV_CHANGER",
        Value = Post.FovOn,
        Callback = function(state)
            Post.FovOn = state
            postApply()
        end,
    })
    cameraPill:Slider({
        Title = "loc:WORLD_FOV",
        Step = 1,
        Value = { Min = 20, Max = 120, Default = Post.Fov },
        Callback = function(value)
            Post.Fov = value
            postApply()
        end,
    })
    cameraPill:Toggle({
        Title = "loc:WORLD_ASPECT_RATIO",
        Value = Post.AspectOn,
        Callback = function(state)
            Post.AspectOn = state
            postApply()
        end,
    })

    cameraPill:Slider({
        Title = "loc:WORLD_RATIO_X",
        Step = 0.05,
        Value = { Min = 1, Max = 3, Default = Post.RatioX },
        Callback = function(value)
            Post.RatioX = value
            postApply()
        end,
    })
    cameraPill:Slider({
        Title = "loc:WORLD_RATIO_Y",
        Step = 0.05,
        Value = { Min = 1, Max = 3, Default = Post.RatioY },
        Callback = function(value)
            Post.RatioY = value
            postApply()
        end,
    })

    HX.WorldTab:Space({ Columns = 1 })
    HX.WorldTab:Button({
        Title = "loc:WORLD_RESET",
        Icon = "rotate-ccw",
        Callback = function()
            worldReset()
        end,
    })
    function HX.VisualsCleanup()
        if Cursor.Conn then
            Cursor.Conn:Disconnect()
            Cursor.Conn = nil
        end
        if Cursor.Gui then
            Cursor.Gui:Destroy()
            Cursor.Gui = nil
        end
        UIS.MouseIconEnabled = true
        if Visuals.AvatarConn then
            Visuals.AvatarConn:Disconnect()
            Visuals.AvatarConn = nil
        end
        worldReset()
    end
end
HX.loadStage(HX.stageLabel("SERVER_SNIPE_TAB"), 0.86)
HX.ServerTab = Window:Tab({Title = "loc:SERVER_SNIPE_TAB", Icon = "crosshair", Locked = false})

HX.ServerTab:Section({Title = "loc:SERVER_SNIPE_TAB", TextSize = 25})
HX.ServerTab:Section({Title = "loc:WARNING_TEXT", Icon = "triangle-alert"})
HX.ServerTab:Section({Title = "loc:SERVER_TYPE_SECTION", Icon = "server"})

HX.selectedServerType = "None"
HX.selectedServerSize = "None"

HX.serverTypeDropdown = HX.ServerTab:Dropdown({
    Title = "loc:SERVER_TYPE_SECTION",
    Desc = "loc:SERVER_TYPE_DESC",
    Values = { "None", "Normal", "XL", "VC" },
    Value = "None",
    Callback = function(value)
        HX.selectedServerType = value
        if value ~= "None" then
            HX.SafeNotify({
                Title = "loc:SERVER_TYPE_SELECTED",
                Content = value,
                Duration = 2,
                Icon = "server"
            })
        end
    end
})

HX.serverSizeDropdown = HX.ServerTab:Dropdown({
    Title = "loc:SERVER_SIZE",
    Desc = "loc:SERVER_SIZE_DESC",
    Values = { "None", "Lowest Population", "Medium Population", "Highest Population" },
    Value = "None",
    Callback = function(value)
        HX.selectedServerSize = value
        if value ~= "None" then
            HX.SafeNotify({
                Title = "loc:SERVER_SIZE_SELECTED",
                Content = value,
                Duration = 2,
                Icon = "users"
            })
        end
    end
})

HX.serverInfo = {
    Normal = 11137575513,
    XL = 12943245078,
    VC = 12943247001
}

local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local lp = game:GetService("Players").LocalPlayer

function HX.getServers(gameId)
    local servers = {}
    local cursor = nil

    repeat
        local url = "https://games.roblox.com/v1/games/"..gameId.."/servers/Public?sortOrder=Asc&limit=100"
        if cursor then
            url = url .. "&cursor=" .. cursor
        end

        local success, response = pcall(function()
            return game:HttpGet(url)
        end)

        if success then
            local data = HttpService:JSONDecode(response)
            for _,server in ipairs(data.data) do
                if server.playing and server.id then
                    table.insert(servers, server)
                end
            end
            cursor = data.nextPageCursor
        else
            break
        end
    until not cursor

    return servers
end

function HX.joinServerWithSnipe(gameId, serverType)
    if HX.selectedServerType == "None" then
        HX.SafeNotify({
            Title = "loc:ERROR",
            Content = "loc:SERVER_SELECT_TYPE_FIRST",
            Duration = 3,
            Icon = "alert-circle"
        })
        return
    end
    
    local message = string.format(HX.translate("FINDING_SERVER"), serverType)

    if serverType == "Normal" and HX.selectedServerSize ~= "None" then
        if HX.selectedServerSize == "Lowest Population" then
            message = HX.translate("FINDING_LOWEST")
        elseif HX.selectedServerSize == "Medium Population" then
            message = HX.translate("FINDING_MEDIUM")
        elseif HX.selectedServerSize == "Highest Population" then
            message = HX.translate("FINDING_2_SPOTS")
        end
    end
    
    HX.SafeNotify({
        Title = "loc:SERVER_SNIPE_TAB",
        Content = message,
        Duration = 3,
        Icon = "search"
    })
    
    task.wait(1)
    
    local servers = HX.getServers(gameId)

    if #servers == 0 then
        HX.SafeNotify({
            Title = "loc:NO_SERVERS_TITLE",
            Content = "loc:NO_SERVERS",
            Duration = 2,
            Icon = "xmark"
        })
        return
    end

    if HX.selectedServerSize == "Lowest Population" then
        table.sort(servers, function(a,b) return a.playing < b.playing end)
    elseif HX.selectedServerSize == "Medium Population" then
        table.sort(servers, function(a,b) return math.abs(a.playing - 10) < math.abs(b.playing - 10) end)
    elseif HX.selectedServerSize == "Highest Population" then
        table.sort(servers, function(a,b) return a.playing > b.playing end)
    else
        table.sort(servers, function(a,b) return a.playing < b.playing end)
    end

    local targetServer = servers[1]
    if targetServer then
        HX.SafeNotify({
            Title = "loc:JOINING_SERVER_TITLE",
            Content = string.format(HX.translate("SERVER_WITH_PLAYERS"), serverType, targetServer.playing),
            Duration = 2,
            Icon = "check"
        })
        
        TeleportService:TeleportToPlaceInstance(gameId, targetServer.id, lp)
    end
end

HX.ServerTab:Button({
    Title = "loc:JOIN_SERVER",
    Icon = "play",
    Callback = function()
        if HX.selectedServerType == "None" then
            HX.SafeNotify({
                Title = "loc:ERROR",
                Content = "loc:SERVER_SELECT_TYPE_FIRST",
                Duration = 3,
                Icon = "alert-circle"
            })
            return
        end
        
        local gameId = HX.serverInfo[HX.selectedServerType]
        if not gameId then return end
        
        HX.joinServerWithSnipe(gameId, HX.selectedServerType)
    end
})

HX.ServerTab:Button({
    Title = "loc:SERVER_HOP",
    Icon = "refresh-cw",
    Callback = function()
        if HX.selectedServerType == "None" then
            HX.SafeNotify({
                Title = "loc:ERROR",
                Content = "loc:SERVER_SELECT_TYPE_FIRST",
                Duration = 3,
                Icon = "alert-circle"
            })
            return
        end
        
        local gameId = HX.serverInfo[HX.selectedServerType]
        if not gameId then return end
        
        HX.SafeNotify({
            Title = "loc:SERVER_HOP_SECTION",
            Content = string.format(HX.translate("SERVER_HOPPING"), HX.selectedServerType),
            Duration = 2,
            Icon = "refresh-cw"
        })
        
        HX.joinServerWithSnipe(gameId, HX.selectedServerType)
    end
})
HX.ServerTab:Section({Title = "loc:SERVER_LIST_SECTION", Icon = "list"})
HX.ServerTab:Code({Title = "loc:SERVER_LIST_MENTAL", Code = [[-- Server Hopper / List
loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-Server-Hopper-21123"))()]]})
HX.ServerTab:Button({Title = "loc:SERVER_LIST_BUTTON", Icon = "play", Callback = function()
    loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-Server-Hopper-21123"))()()
    WindUI:Notify({Title = "loc:SCRIPT_EXECUTED", Content = string.format(HX.translate("LOADED_SUCCESSFULLY"), HX.translate("SERVER_HOPPER")), Duration = 3, Icon = "check"})
end})
HX.ServerTab:Section({Title = "loc:QUICK_JOIN_SECTION", Icon = "zap"})

HX.ServerTab:Button({
    Title = "loc:JOIN_NORMAL_LOW_POP",
    Icon = "user-minus",
    Callback = function()
        HX.selectedServerType = "Normal"
        HX.selectedServerSize = "Lowest Population"
        HX.serverTypeDropdown:Select("Normal")
        HX.serverSizeDropdown:Select("Lowest Population")
        
        HX.SafeNotify({
            Title = "loc:JOINING_NORMAL",
            Content = "loc:FINDING_LOWEST",
            Duration = 3,
            Icon = "user-minus"
        })
        
        HX.joinServerWithSnipe(HX.serverInfo.Normal, "Normal")
    end
})

HX.ServerTab:Button({
    Title = "loc:JOIN_NORMAL_MEDIUM_POP",
    Icon = "users",
    Callback = function()
        HX.selectedServerType = "Normal"
        HX.selectedServerSize = "Medium Population"
        HX.serverTypeDropdown:Select("Normal")
        HX.serverSizeDropdown:Select("Medium Population")
        
        HX.SafeNotify({
            Title = "loc:JOINING_NORMAL",
            Content = "loc:FINDING_MEDIUM",
            Duration = 3,
            Icon = "users"
        })
        
        HX.joinServerWithSnipe(HX.serverInfo.Normal, "Normal")
    end
})

HX.ServerTab:Button({
    Title = "loc:JOIN_NORMAL_2_SPOTS",
    Icon = "user-plus",
    Callback = function()
        HX.selectedServerType = "Normal"
        HX.selectedServerSize = "Highest Population"
        HX.serverTypeDropdown:Select("Normal")
        HX.serverSizeDropdown:Select("Highest Population")
        
        HX.SafeNotify({
            Title = "loc:JOINING_NORMAL",
            Content = "loc:FINDING_2_SPOTS",
            Duration = 3,
            Icon = "users"
        })
        
        HX.joinServerWithSnipe(HX.serverInfo.Normal, "Normal")
    end
})

HX.ServerTab:Button({
    Title = "loc:JOIN_XL_SERVER",
    Icon = "maximize-2",
    Callback = function()
        HX.selectedServerType = "XL"
        HX.selectedServerSize = "None"
        HX.serverTypeDropdown:Select("XL")
        HX.serverSizeDropdown:Select("None")
        
        HX.SafeNotify({
            Title = "loc:JOINING_XL",
            Content = "loc:FINDING_XL",
            Duration = 3,
            Icon = "maximize-2"
        })
        
        HX.joinServerWithSnipe(HX.serverInfo.XL, "XL")
    end
})

HX.ServerTab:Button({
    Title = "loc:JOIN_VC_SERVER",
    Icon = "mic",
    Callback = function()
        HX.selectedServerType = "VC"
        HX.selectedServerSize = "None"
        HX.serverTypeDropdown:Select("VC")
        HX.serverSizeDropdown:Select("None")
        
        HX.SafeNotify({
            Title = "loc:JOINING_VC",
            Content = "loc:FINDING_VC",
            Duration = 3,
            Icon = "mic"
        })
        
        HX.joinServerWithSnipe(HX.serverInfo.VC, "Voice Chat")
    end
})

HX.loadStage(HX.stageLabel("SCRIPTS_TAB"), 0.92)
HX.ScriptsTab = Window:Tab({Title = "loc:SCRIPTS_TAB", Icon = "code", Locked = false})

HX.ScriptsTab:Section({Title = "loc:TCO_SCRIPTS_SECTION"})

HX.ScriptsTab:Button({Title = "loc:TCO_EXTRAS", Icon = "play", Callback = function()
    loadstring(game:HttpGet("https://rawscripts.net/raw/The-Chosen-One-Extra-Stuff-18127"))()
    WindUI:Notify({Title = "loc:SCRIPT_EXECUTED", Content = string.format(HX.translate("LOADED_SUCCESSFULLY"), HX.translate("TCO_EXTRAS")), Duration = 3, Icon = "check"})
end})

HX.ScriptsTab:Button({Title = "loc:CORAVEN_LITE", Icon = "play", Callback = function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/bob448/public-scripts/main/src/CO-Raven%20Lite/CO-Raven-Lite.lua"))()
    WindUI:Notify({Title = "loc:SCRIPT_EXECUTED", Content = string.format(HX.translate("LOADED_SUCCESSFULLY"), HX.translate("CORAVEN_LITE")), Duration = 3, Icon = "check"})
end})

HX.ScriptsTab:Button({Title = "loc:ZTE_HUB", Icon = "play", Callback = function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/khanh-lol/Ztehub/refs/heads/main/ztebeta"))()()
    WindUI:Notify({Title = "loc:SCRIPT_EXECUTED", Content = string.format(HX.translate("LOADED_SUCCESSFULLY"), HX.translate("ZTE_HUB")), Duration = 3, Icon = "check"})
end})

HX.ScriptsTab:Code({Title = "loc:TCO_CODE_TITLE", Code = [[-- Tco Extras
loadstring(game:HttpGet("https://rawscripts.net/raw/The-Chosen-One-Extra-Stuff-18127"))()

loadstring(game:HttpGet("https://raw.githubusercontent.com/bob448/public-scripts/main/src/CO-Raven%20Lite/CO-Raven-Lite.lua"))()

loadstring(game:HttpGet("https://raw.githubusercontent.com/khanh-lol/Ztehub/refs/heads/main/ztebeta"))()()]]})

HX.loadStage(HX.stageLabel("SETTINGS_TAB"), 0.95)
local SettingsTab = Window:Tab({
    Title = "loc:SETTINGS_TAB",
    Icon = "settings",
    Locked = false,
})
local ConfigManager
local HttpService = game:GetService("HttpService")

local hasFs = type(writefile) == "function"
    and type(readfile) == "function"
    and type(isfile) == "function"

local CONFIG_DIR = "WindUI/Ender Hub V2/config"
local AUTOLOAD_POINTER = CONFIG_DIR .. "/.autoload"
local LOADER_URL = "https://raw.githubusercontent.com/qilex/enderhubloader/main/loader.luau"
local LOADER_LOCAL = "enderhubloader/loader.luau"
local LOADER_LOCAL_WIN = "enderhubloader\\loader.luau"

local selectedConfig = nil
local autosaveEnabled = false
local teleportArmed = false
local isLoadingConfig = false
local saveQueued = false
local hookedElements = {}

local nameInput
local configDropdown
local autoloadToggle
local autosaveToggle

local function alertImportant(message)
    if type(SafeNotify) == "function" then
        SafeNotify({
            Title = "loc:CONFIG_WARNING",
            Content = tostring(message),
            Duration = 3,
            Icon = "triangle-alert",
        })
    else
        WindUI:Notify({
            Title = "loc:CONFIG_WARNING",
            Content = tostring(message),
            Duration = 3,
            Icon = "triangle-alert",
        })
    end
end

local function configPath(name)
    return CONFIG_DIR .. "/" .. tostring(name) .. ".json"
end

local function sanitizeName(value)
    local folded = tostring(value or ""):gsub("%s+", "-"):gsub("[^%w%-_]", "")
    return folded
end

local function readConfigFile(name)
    if not hasFs then return nil end
    local path = configPath(name)
    local ok, exists = pcall(isfile, path)
    if not ok or not exists then return nil end
    local fine, data = pcall(readfile, path)
    if not fine or type(data) ~= "string" or #data == 0 then return nil end
    local decoded, parsed = pcall(function()
        return HttpService:JSONDecode(data)
    end)
    if decoded and type(parsed) == "table" then return parsed end
    return nil
end

local SNAPSHOT_TYPES = {
    Colorpicker = true,
    Dropdown = true,
    Input = true,
    Keybind = true,
    Slider = true,
    Toggle = true,
}

local function captureElementValue(element)
    local kind = element.__type
    if kind == "Colorpicker" then
        local color = element.Default
        if typeof(color) ~= "Color3" then return nil end
        return { value = color:ToHex(), transparency = element.Transparency }
    elseif kind == "Slider" then
        local value = element.Value
        if type(value) == "table" then value = value.Default end
        value = tonumber(value)
        if not value then return nil end
        return { value = value }
    elseif kind == "Dropdown" then
        local value = element.Value
        if typeof(value) == "table" then
            value = value.Title ~= nil and value.Title or value[1]
        end
        local valueType = type(value)
        if valueType ~= "string" and valueType ~= "number" then return nil end
        return { value = value }
    end
    local value = element.Value
    local valueType = type(value)
    if valueType == "string" or valueType == "number" or valueType == "boolean" then
        return { value = value }
    end
    return nil
end

local function applyElementValue(element, saved)
    if type(saved) ~= "table" then return end
    local kind = element.__type
    if kind == "Colorpicker" then
        if type(saved.value) ~= "string" then return end
        local ok, color = pcall(Color3.fromHex, saved.value)
        if not ok or type(element.Update) ~= "function" then return end
        pcall(function() element:Update(color, saved.transparency) end)
        return
    end
    if kind == "Slider" then
        local value = tonumber(saved.value)
        if value and type(element.Set) == "function" then
            pcall(function() element:Set(value) end)
        end
        return
    end
    if kind == "Dropdown" then
        if type(element.Select) ~= "function" then return end
        pcall(function() element:Select(saved.value) end)
        return
    end
    if type(element.Set) == "function" then
        pcall(function() element:Set(saved.value) end)
    end
end

local function walkElements(visitor)
    local function walk(list, prefix)
        if type(list) ~= "table" then return end
        for index, element in ipairs(list) do
            if type(element) == "table" then
                local key = prefix .. tostring(index)
                visitor(key, element)
                if type(element.Elements) == "table" then
                    walk(element.Elements, key .. "/")
                end
            end
        end
    end
    local tabs = Window.TabModule and Window.TabModule.Tabs
    if type(tabs) ~= "table" then return end
    for tabIndex, tab in next, tabs do
        if type(tab) == "table" and tab ~= SettingsTab then
            walk(tab.Elements, tostring(tabIndex) .. ":")
        end
    end
end

local function collectElements()
    local snapshot = {}
    walkElements(function(key, element)
        local kind = element.__type
        if kind and SNAPSHOT_TYPES[kind] then
            local saved = captureElementValue(element)
            if saved then snapshot[key] = saved end
        end
    end)
    return snapshot
end

local function newConfigModule(name, autoload)
    local module = {
        Name = name,
        Path = configPath(name),
        AutoLoad = autoload == true,
        CustomData = {},
    }

    function module:SetAsCurrent() Window.CurrentConfig = module end
    function module:Register() end
    function module:Set(key, value) module.CustomData[key] = value end
    function module:Get(key) return module.CustomData[key] end
    function module:SetAutoLoad(value) module.AutoLoad = value == true end

    function module:Save()
        local payload = {
            __version = 3,
            __autoload = module.AutoLoad,
            __custom = module.CustomData,
            __elements = collectElements(),
        }
        local okJson, encoded = pcall(function() return HttpService:JSONEncode(payload) end)
        if not okJson or type(encoded) ~= "string" then return nil end
        if not pcall(writefile, module.Path, encoded) then return nil end
        return payload
    end

    function module:Load()
        local data = readConfigFile(name)
        if not data then return false, "config file could not be read" end
        local elements = type(data.__elements) == "table" and data.__elements or data
        isLoadingConfig = true
        walkElements(function(key, element)
            local saved = elements[key]
            if type(saved) == "table" then
                applyElementValue(element, saved)
            end
        end)
        isLoadingConfig = false
        module.CustomData = type(data.__custom) == "table" and data.__custom or {}
        if data.__autoload ~= nil then module.AutoLoad = data.__autoload == true end
        return module.CustomData
    end

    return module
end

ConfigManager = {
    Path = CONFIG_DIR .. "/",
    Parser = SNAPSHOT_TYPES,
    CreateConfig = function(_, name, autoload)
        if type(name) ~= "string" or name == "" then return nil end
        return newConfigModule(name, autoload)
    end,
    DeleteConfig = function(_, name)
        if not hasFs or type(delfile) ~= "function" then
            return false, "this executor cannot delete files"
        end
        local path = configPath(name)
        local ok, exists = pcall(isfile, path)
        if not ok or not exists then return false, "config does not exist" end
        if not pcall(delfile, path) then return false, "could not delete the file" end
        return true
    end,
}
local function listConfigs()
    local names = {}
    if not hasFs or type(listfiles) ~= "function" then return names end
    local ok, files = pcall(function()
        if type(isfolder) == "function" and not isfolder(CONFIG_DIR) then
            makefolder(CONFIG_DIR)
        end
        return listfiles(CONFIG_DIR)
    end)
    if not ok or type(files) ~= "table" then return names end
    for _, entry in ipairs(files) do
        local name = tostring(entry):match("([^\\/]+)%.json$")
        if name and name ~= "" then
            table.insert(names, name)
        end
    end
    table.sort(names)
    return names
end

local function markAutoload(name, enabled)
    if not hasFs then return end
    if enabled == true and name then
        pcall(writefile, AUTOLOAD_POINTER, name)
    else
        pcall(function()
            if type(delfile) == "function" and isfile(AUTOLOAD_POINTER) then
                delfile(AUTOLOAD_POINTER)
            end
        end)
    end
    for _, other in ipairs(listConfigs()) do
        local data = readConfigFile(other)
        if data and data.__version then
            local wanted = enabled == true and other == name
            if data.__autoload ~= wanted then
                data.__autoload = wanted
                local okJson, encoded = pcall(function()
                    return HttpService:JSONEncode(data)
                end)
                if okJson and type(encoded) == "string" then
                    pcall(writefile, configPath(other), encoded)
                end
            end
        end
    end
end

local function pointerAutoload()
    if not hasFs then return nil end
    local okFile, exists = pcall(isfile, AUTOLOAD_POINTER)
    if not okFile or not exists then return nil end
    local okRead, raw = pcall(readfile, AUTOLOAD_POINTER)
    if not okRead or type(raw) ~= "string" then return nil end
    local name = raw:match("^%s*([%w%-_]+)%s*$")
    if not name or name == "" then return nil end
    local data = readConfigFile(name)
    if data and data.__autoload == true then return name end
    return nil
end

local function findAutoload()
    local pointed = pointerAutoload()
    if pointed then return pointed end
    for _, name in ipairs(listConfigs()) do
        local data = readConfigFile(name)
        if data and data.__autoload == true then
            return name
        end
    end
    return nil
end

local function queueFunction()
    local found = nil
    local function consider(value)
        if found == nil and type(value) == "function" then
            found = value
        end
    end
    local okDirect, direct = pcall(function() return queue_on_teleport end)
    if okDirect then consider(direct) end
    local okAlt, alt = pcall(function() return queue_teleport end)
    if okAlt then consider(alt) end
    local okSyn, synTable = pcall(function() return syn end)
    if okSyn and type(synTable) == "table" then
        consider(synTable.queue_on_teleport)
        consider(synTable.queue_teleport)
    end
    local okFlux, fluxusTable = pcall(function() return fluxus end)
    if okFlux and type(fluxusTable) == "table" then
        consider(fluxusTable.queue_on_teleport)
    end
    local okEnv, env = pcall(function()
        return (typeof(getgenv) == "function" and getgenv()) or nil
    end)
    if okEnv and type(env) == "table" then
        consider(env.queue_on_teleport)
        consider(env.queue_teleport)
    end
    return found
end

local function queueCommand()
    return string.format([[
local source
local candidates = { "%s", "%s", "loader.luau" }
if type(isfile) == "function" and type(readfile) == "function" then
    for _, path in ipairs(candidates) do
        local ok, data = pcall(function()
            if isfile(path) then return readfile(path) end
        end)
        if ok and type(data) == "string" and #data > 0 then
            source = data
            break
        end
    end
end
if not source then
    source = game:HttpGet("%s")
end
local chunk, message = loadstring(source, "=enderhub-loader")
if type(chunk) ~= "function" then
    error("[enderhub] " .. tostring(message), 0)
end
chunk()
]], LOADER_LOCAL, LOADER_LOCAL_WIN, LOADER_URL)
end

local function armTeleport(enabled)
    local fn = queueFunction()
    if not fn then
        teleportArmed = false
        return false, "this executor has no queue_on_teleport"
    end
    local ok, err = pcall(fn, enabled and queueCommand() or "")
    if not ok then
        teleportArmed = false
        return false, tostring(err)
    end
    teleportArmed = enabled == true
    return true
end

local saveCurrent

local function triggerInstantAutosave()
    if not autosaveEnabled or isLoadingConfig or not Window.CurrentConfig then return end
    if saveQueued then return end
    saveQueued = true
    task.defer(function()
        task.wait(0.15)
        saveQueued = false
        if autosaveEnabled and not isLoadingConfig and Window.CurrentConfig then
            pcall(saveCurrent)
        end
    end)
end

local function hookElementForAutosave(element)
    if type(element) ~= "table" or hookedElements[element] then return end
    hookedElements[element] = true

    if type(element.Callback) == "function" then
        local oldCb = element.Callback
        element.Callback = function(...)
            local r1, r2, r3 = oldCb(...)
            triggerInstantAutosave()
            return r1, r2, r3
        end
    elseif type(element.Callback) == "table" then
        table.insert(element.Callback, function()
            triggerInstantAutosave()
        end)
    end

    if type(element.Set) == "function" then
        local oldSet = element.Set
        element.Set = function(self, ...)
            local r1, r2, r3 = oldSet(self, ...)
            triggerInstantAutosave()
            return r1, r2, r3
        end
    end
end

local function registerTree(module, elements, prefix)
    if type(elements) ~= "table" then return 0 end
    local count = 0
    for index, element in ipairs(elements) do
        if type(element) == "table" then
            local kind = element.__type
            local key = string.format("%s%d", prefix, index)
            if kind and ConfigManager and ConfigManager.Parser and ConfigManager.Parser[kind] then
                local ok = pcall(function()
                    module:Register(key, element)
                end)
                if ok then
                    count = count + 1
                    hookElementForAutosave(element)
                end
            end
            if type(element.Elements) == "table" then
                count = count + registerTree(module, element.Elements, key .. "/")
            end
        end
    end
    return count
end

local function registerAll(module)
    if not module or not ConfigManager then return 0 end
    local tabs = Window.TabModule and Window.TabModule.Tabs
    if type(tabs) ~= "table" then return 0 end
    local count = 0
    for tabIndex, tab in next, tabs do
        if type(tab) == "table" and tab ~= SettingsTab then
            count = count + registerTree(module, tab.Elements, tostring(tabIndex) .. ":")
        end
    end
    return count
end

saveCurrent = function(target)
    if not ConfigManager then return false, "config manager unavailable" end
    if not hasFs then return false, "executor has no file access" end
    local module = Window.CurrentConfig
    if target and target ~= "" then
        local wanted = configPath(target)
        if not (module and module.Path == wanted) then
            local created = ConfigManager:CreateConfig(target, false)
            if not created then return false, "could not open config" end
            registerAll(created)
            created:SetAsCurrent()
            module = created
            selectedConfig = target
        end
    end
    if not module then return false, "no config selected" end
    local ok, err = pcall(function()
        module:Save()
    end)
    if not ok then return false, tostring(err) end
    return true
end

local function useConfig(name)
    if not ConfigManager then return false, "config manager unavailable" end
    if not hasFs then return false, "executor has no file access" end
    local path = configPath(name)
    local okFile, exists = pcall(isfile, path)
    if not okFile or not exists then return false, "config does not exist" end
    local module = ConfigManager:CreateConfig(name, false)
    if not module then return false, "could not open config" end
    registerAll(module)
    isLoadingConfig = true
    local okLoad, result = pcall(function()
        return module:Load()
    end)
    isLoadingConfig = false
    if not okLoad then return false, tostring(result) end
    if result == false then return false, "could not read the file" end
    module:SetAsCurrent()
    selectedConfig = name
    pcall(function()
        autoloadToggle:Set(module.AutoLoad == true, false, true)
    end)
    return true
end

local function selectedName()
    if selectedConfig and selectedConfig ~= "" then return selectedConfig end
    local typed = sanitizeName(nameInput and nameInput.Value or "")
    if typed ~= "" then return typed end
    return nil
end

local function persistCustom(key, value)
    if not Window.CurrentConfig then return end
    pcall(function()
        Window.CurrentConfig:Set(key, value)
        Window.CurrentConfig:Save()
    end)
end

local function refreshDropdown()
    if not configDropdown or type(configDropdown.Refresh) ~= "function" then return end
    local names = listConfigs()
    pcall(function()
        configDropdown:Refresh(names)
    end)
    if selectedConfig and table.find(names, selectedConfig) then
        pcall(function()
            configDropdown:Select(selectedConfig)
        end)
    end
end

SettingsTab:Section({
    Title = "loc:CONFIG_WORD",
    Icon = "folder-cog",
    Desc = "loc:CONFIG_MANAGER_DESC",
})

SettingsTab:Space({ Columns = 1 })

SettingsTab:Section({
    Title = "loc:CONFIG_CREATOR",
    Icon = "file-plus",
    TextSize = 16,
    FontWeight = Enum.FontWeight.SemiBold,
})
SettingsTab:Space({ Columns = 0.5 })
nameInput = SettingsTab:Input({
    Title = "loc:CONFIG_NAME",
    Placeholder = "loc:CONFIG_NAME_PLACEHOLDER",
    Value = "",
    InputIcon = "pencil",
})

SettingsTab:Space({ Columns = 0.5 })

local Group1 = SettingsTab:Group()

Group1:Button({
    Title = "loc:CREATE_CONFIG",
    Justify = "Center",
    Icon = "file-plus",
    IconAlign = "Left",
    Size = "Small",
    Callback = function()
        local name = sanitizeName(nameInput and nameInput.Value or "")
        if name == "" then
            alertImportant("type a config name first")
            return
        end
        if not ConfigManager then
            alertImportant("config manager unavailable")
            return
        end
        if not hasFs then
            alertImportant("executor has no file access")
            return
        end
        if isfile(configPath(name)) then
            alertImportant(name .. " already exists")
            return
        end
        local module = ConfigManager:CreateConfig(name, false)
        if not module then
            alertImportant("could not create the file")
            return
        end
        module:SetAsCurrent()
        registerAll(module)
        pcall(function()
            module:Set("autosave", autosaveEnabled)
            module:Set("teleportAutoload", teleportArmed)
        end)
        local ok, err = pcall(function()
            module:Save()
        end)
        if not ok then
            alertImportant(tostring(err))
            return
        end
        selectedConfig = name
        refreshDropdown()
    end,
})

Group1:Space({ Columns = 0.5 })

Group1:Button({
    Title = "loc:DELETE_CONFIG",
    Justify = "Center",
    Icon = "trash-2",
    IconAlign = "Left",
    Size = "Small",
    Callback = function()
        local name = selectedName()
        if not name then
            alertImportant("pick a config in the dropdown")
            return
        end
        if not ConfigManager then
            alertImportant("config manager unavailable")
            return
        end
        local pointed = pointerAutoload()
        local wasAuto = pointed == name
        local ok, message = ConfigManager:DeleteConfig(name)
        if ok ~= true then
            alertImportant(tostring(message))
            return
        end
        if wasAuto then
            markAutoload(nil, false)
            teleportArmed = false
            pcall(function() autoloadToggle:Set(false, false, true) end)
            pcall(armTeleport, false)
        end
        if selectedConfig == name then
            selectedConfig = nil
            pcall(function() configDropdown:Select(nil) end)
        end
        refreshDropdown()
    end,
})

SettingsTab:Space({ Columns = 1 })

SettingsTab:Section({
    Title = "loc:CONFIG_LOADER",
    Icon = "folder-open",
    TextSize = 16,
    FontWeight = Enum.FontWeight.SemiBold,
})

configDropdown = SettingsTab:Dropdown({
    Title = "loc:SAVED_CONFIGS",
    Values = listConfigs(),
    Value = nil,
    AllowNone = true,
    SearchBarEnabled = true,
    Callback = function(value)
        selectedConfig = typeof(value) == "string" and value or nil
    end,
})

SettingsTab:Space({ Columns = 0.5 })

local Group2 = SettingsTab:Group()

Group2:Button({
    Title = "loc:LOAD_CONFIG",
    Justify = "Center",
    Icon = "folder-open",
    IconAlign = "Left",
    Size = "Small",
    Callback = function()
        local name = selectedName()
        if not name then
            alertImportant("pick a config in the dropdown")
            return
        end
        local ok, message = useConfig(name)
        refreshDropdown()
        if not ok then
            alertImportant(message)
        end
    end,
})

Group2:Space({ Columns = 0.5 })

Group2:Button({
    Title = "loc:SAVE_CONFIG",
    Justify = "Center",
    Icon = "save",
    IconAlign = "Left",
    Size = "Small",
    Callback = function()
        local name = selectedName()
        if not name then
            alertImportant("pick a config in the dropdown")
            return
        end
        local ok, message = saveCurrent(name)
        refreshDropdown()
        if not ok then
            alertImportant(message)
        end
    end,
})

SettingsTab:Space({ Columns = 1 })

SettingsTab:Section({
    Title = "loc:AUTOMATION",
    Icon = "sliders-horizontal",
    TextSize = 16,
    FontWeight = Enum.FontWeight.SemiBold,
})

local Group3 = SettingsTab:Group()

autoloadToggle = Group3:Toggle({
    Title = "loc:AUTOLOAD_CONFIG",
    Value = false,
    Callback = function(value)
        if value == true and not Window.CurrentConfig then
            alertImportant("create or load a config first")
            pcall(function() autoloadToggle:Set(false, false, true) end)
            return
        end
        local name = nil
        if Window.CurrentConfig then
            name = tostring(Window.CurrentConfig.Path):match("([^\\/]+)%.json$")
            pcall(function()
                Window.CurrentConfig:SetAutoLoad(value == true)
                Window.CurrentConfig:Set("teleportAutoload", value == true)
                Window.CurrentConfig:Save()
            end)
            if name then markAutoload(name, value == true) end
        end
        if value == true then
            local armed, message = armTeleport(true)
            if not armed then
                alertImportant("autoload on, but " .. tostring(message))
            end
        else
            armTeleport(false)
        end
        if name then
            selectedConfig = name
            refreshDropdown()
        end
    end,
})

Group3:Space({ Columns = 0.5 })

autosaveToggle = Group3:Toggle({
    Title = "loc:AUTOSAVE_CONFIG",
    Value = false,
    Callback = function(value)
        autosaveEnabled = value == true
        persistCustom("autosave", autosaveEnabled)
        if autosaveEnabled and Window.CurrentConfig then
            registerAll(Window.CurrentConfig)
            pcall(saveCurrent)
        end
    end,
})

SettingsTab:Space({ Columns = 0.5 })

SettingsTab:Button({
    Title = "loc:REFRESH_FOLDER",
    Justify = "Center",
    Icon = "refresh-cw",
    IconAlign = "Left",
    Size = "Small",
    Callback = function()
        refreshDropdown()
        if type(listfiles) ~= "function" then
            alertImportant("this executor cannot list files, type the name instead")
        end
    end,
})

SettingsTab:Space({ Columns = 1 })

SettingsTab:Section({
    Title = "loc:MUSIC_WORD",
    Icon = "music",
    TextSize = 16,
    FontWeight = Enum.FontWeight.SemiBold,
})

local MusicGroup = SettingsTab:Group()

local MusicToggle
MusicToggle = MusicGroup:Toggle({
    Title = "loc:ENABLE_MUSIC",
    Desc = "loc:MUSIC_DESC",
    Value = false,
    Callback = function(value)
        local on = value == true
        HX.IslandMusic = on
        local island = HX.Island
        if type(island) == "table" then
            if HX.IslandMusic then
                pcall(function()
                    island:BindMusic({ "files", "demo" }, "Ender Hub/songs")
                end)
            else
                pcall(function()
                    island:UnbindMusic()
                end)
            end
        end
        HX.historyPush({
            undo = function()
                pcall(function() MusicToggle:Set(not on, true) end)
            end,
            redo = function()
                pcall(function() MusicToggle:Set(on, true) end)
            end,
        })
    end,
})

local MusicEffectsToggle
MusicEffectsToggle = MusicGroup:Toggle({
    Title = "loc:MUSIC_EFFECTS",
    Desc = "loc:MUSIC_EFFECTS_DESC",
    Value = true,
    Callback = function(value)
        local on = value == true
        HX.musicEffects = on
        pcall(function()
            if type(Window.SetMusicEffects) == "function" then
                Window:SetMusicEffects(on)
            end
        end)
        HX.historyPush({
            undo = function()
                pcall(function() MusicEffectsToggle:Set(not on, true) end)
            end,
            redo = function()
                pcall(function() MusicEffectsToggle:Set(on, true) end)
            end,
        })
    end,
})
HX.musicEffects = true

local autoloadProfile = hasFs and findAutoload() or nil

if autoloadProfile and ConfigManager then
    task.spawn(function()
        task.wait(0.6)
        pcall(function()
            local module = ConfigManager:CreateConfig(autoloadProfile, false)
            if module then
                registerAll(module)
                module:SetAsCurrent()
                pcall(function() module:SetAutoLoad(true) end)
                isLoadingConfig = true
                local okLoad, errLoad = pcall(function()
                    return module:Load()
                end)
                isLoadingConfig = false
                if not okLoad then
                    alertImportant("Autoload error: " .. tostring(errLoad))
                end
                selectedConfig = autoloadProfile
                pcall(function() configDropdown:Select(autoloadProfile) end)
                pcall(function() autoloadToggle:Set(true, false, true) end)
            end
        end)
    end)
end

do
    local data = autoloadProfile and readConfigFile(autoloadProfile) or nil
    local custom = data and data.__custom or nil
    if custom then
        if custom.autosave == true then
            autosaveEnabled = true
            pcall(function()
                autosaveToggle:Set(true, false, true)
            end)
        end
        if custom.teleportAutoload == true then
            task.spawn(function()
                task.wait(1)
                local ok, message = armTeleport(true)
                if ok then
                    pcall(function() autoloadToggle:Set(true, false, true) end)
                else
                    alertImportant("Teleport queue: " .. tostring(message))
                end
            end)
        end
    end
end

HX.loadStage(HX.translate("WIRING_SERVICES"), 0.97)
task.wait(0.15)
HX.loadStage(HX.translate("SCRIPT_LOADED"), 1)

task.delay(0.8, function()
    local island = HX.Island
    if type(island) ~= "table" or type(island.SetIdle) ~= "function" then
        return
    end
    pcall(function()
        island:SetIdle()
    end)
end)
task.defer(function()
    HX.bootStage("loaded")
    if HX.Boot then
        pcall(function()
            HX.Boot:Ready()
        end)
    end
    print(string.format("EnderHub Loaded (%.2fs)", os.clock() - HX.t0))
end)

end
