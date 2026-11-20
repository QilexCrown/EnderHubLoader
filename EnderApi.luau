local __privacyG = (type(getgenv) == "function" and getgenv()) or _G
do
local __oldSession = __privacyG.EnderHubSession
if type(__oldSession) == "table" and type(__oldSession.stop) == "function" then __oldSession.stop("restart") end
__privacyG.EnderHubBootStage = "startup"
end

local function genv()
    return (typeof(getgenv) == "function" and getgenv()) or _G
end

-- Local-only API surface. The hub runs offline: nothing in this module opens a
-- socket, resolves hardware, or reads the profile. Every entry point stays so
-- callers keep working; the network answers are constant.
local Api = {}
Api.hosts = {}
Api.hostIndex = 1
Api.base = ""
Api.secret = ""
Api.key = ""
Api.ok = true
Api.premium = true
Api.reason = ""
Api.ban = nil
Api.banUntil = nil
Api.lockdown = nil
Api.developer = false
Api.plan = ""
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

function Api.hardwareId()
    return ""
end

function Api.setProfile()
    Api.profile = {}
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

function Api.verify(key)
    Api.key = string.upper(tostring(key or ""))
    Api.ok = true
    Api.premium = true
    Api.reason = ""
    Api.ban = nil
    Api.banUntil = nil
    Api.lockdown = nil
    return true, nil
end

function Api.heartbeat()
    return nil
end

-- Chat forwarding removed: the Main chat view is local-only.
function Api.flushChat() Api.chatQueue = {} end

local fpsFrames = 0

local function startFps()
    local ok, run = pcall(function()
        return game:GetService("RunService")
    end)
    if not ok or typeof(run) ~= "Instance" then return end
    pcall(function()
        run.RenderStepped:Connect(function()
            fpsFrames = fpsFrames + 1
        end)
    end)
    task.spawn(function()
        while not Api.closed do
            task.wait(1)
            fpsFrames = 0
        end
    end)
end

function Api.start()
    if Api.closed then return end
    Api.startedAt = os.time()
    pcall(startFps)
end

function Api.stop()
    Api.closed = true
    Api.profile, Api.ip = {}, nil
    local chatThread = Api.chatThread
    Api.chatThread = nil
    if chatThread and chatThread ~= coroutine.running() then
        pcall(task.cancel, chatThread)
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
return Api
