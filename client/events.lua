-- Ereignisse, simulierte Uhr, C_Timer, OnUpdate und Animationen.
local W = require("widgets")
local R = require("report")
local Sec = require("secret")

local E = { clock = 1000, timers = {}, frameStep = 1 / 60 }
local st = W.st

-- Startzeit wie ein Client, der schon eine Weile laeuft (GetTime > 0).
function W.now() return E.clock end

local eventLists = {}
function W.eventList(ev)
    local l = eventLists[ev]
    if not l then l = {} eventLists[ev] = l end
    return l
end

E.docs = nil
function W.validEvent(ev)
    if type(ev) ~= "string" then return false end
    if not E.docs then return true end
    return E.docs.events[ev] ~= nil
end

-- Verteilt ein Ereignis an alle angemeldeten Rahmen (in Anmeldereihenfolge).
function E.Fire(ev, ...)
    local list = eventLists[ev]
    if not list then return end
    local copy = {}
    for i, f in ipairs(list) do copy[i] = f end
    local unit = ...
    for _, f in ipairs(copy) do
        local s = st(f)
        local filter = s.unitFilter and s.unitFilter[ev]
        if not filter or filter[1] == unit or filter[2] == unit then
            if s.events and s.events[ev] then W.Fire(f, "OnEvent", ev, ...) end
        end
    end
    if E.onFire then E.onFire(ev, ...) end
end

-- C_Timer ----------------------------------------------------------------------------

local function schedule(delay, fn, iterations, handle)
    local t = handle or {}
    t.due = E.clock + math.max(0, Sec.Unwrap(delay) or 0)
    t.interval = math.max(0, Sec.Unwrap(delay) or 0)
    t.fn = fn
    t.left = iterations
    E.timers[#E.timers + 1] = t
    return t
end

local TimerHandle = {}
TimerHandle.__index = TimerHandle
function TimerHandle:Cancel() self.cancelled = true end
function TimerHandle:IsCancelled() return not not self.cancelled end
function TimerHandle:Invoke(...) self.fn(self, ...) end
function TimerHandle:GetRemainingTime() return math.max(0, self.due - E.clock) end

E.C_Timer = {
    After = function(delay, fn) schedule(delay, fn, 1) end,
    NewTimer = function(delay, fn) return schedule(delay, fn, 1, setmetatable({ handle = true }, TimerHandle)) end,
    NewTicker = function(delay, fn, n) return schedule(delay, fn, n, setmetatable({ handle = true }, TimerHandle)) end,
}

local function runTimers()
    local i = 1
    while i <= #E.timers do
        local t = E.timers[i]
        if t.cancelled then
            table.remove(E.timers, i)
        elseif t.due <= E.clock + 1e-9 then
            if t.handle then R.Call(t.fn, t) else R.Call(t.fn) end
            if t.left then t.left = t.left - 1 end
            if (t.left and t.left <= 0) or t.cancelled then
                table.remove(E.timers, i)
            else
                -- Faellig ab dem naechsten Takt, nie mehrfach im selben.
                t.due = t.due + math.max(t.interval, E.frameStep)
                i = i + 1
            end
        else
            i = i + 1
        end
    end
end

-- Ein Bild: Uhr vor, Timer, Animationen, OnUpdate sichtbarer Rahmen.
function E.Step(dt)
    E.clock = E.clock + dt
    runTimers()
    E.AdvanceAnimations(dt)
    local list = {}
    for f in pairs(W.onUpdate) do
        if W.visible(f) then list[#list + 1] = f end
    end
    table.sort(list, function(a, b) return st(a).seq < st(b).seq end)
    for _, f in ipairs(list) do W.Fire(f, "OnUpdate", dt) end
    if E.afterStep then E.afterStep() end
end

function E.Advance(seconds)
    local steps = math.max(1, math.floor(seconds / E.frameStep + 0.5))
    for _ = 1, steps do E.Step(E.frameStep) end
end

-- Animationen ------------------------------------------------------------------------

local playing = {}

local AnimGroup = W.class("AnimationGroup", "Object")
local Anim = W.class("Animation", "Object")

local ANIM_TYPES = { "Alpha", "Translation", "Scale", "LineScale", "Rotation", "Path", "FlipBook", "TextureCoordTranslation", "VertexColor", "LineTranslation" }
for _, t in ipairs(ANIM_TYPES) do W.class(t, "Animation") end

local regionMethods = W.classes.ScriptRegion.methods
function regionMethods:CreateAnimationGroup(name, template) return W.CreateAnimationGroup(self, name, template) end
function regionMethods:GetAnimationGroups()
    local out = {}
    for _, g in ipairs(st(self).animGroups or {}) do out[#out + 1] = g end
    return unpack(out)
end
function regionMethods:StopAnimating()
    for _, g in ipairs(st(self).animGroups or {}) do g:Stop() end
end
function regionMethods:IsAnimating()
    for _, g in ipairs(st(self).animGroups or {}) do if st(g).playing then return true end end
    return false
end

function W.CreateAnimationGroup(parent, name, template)
    local g, s = W.newObject("AnimationGroup", parent, name)
    s.anims = {}
    s.target = parent
    local ps = st(parent)
    ps.animGroups = ps.animGroups or {}
    table.insert(ps.animGroups, g)
    if template then W.ApplyTemplates(g, template) end
    return g
end
function AnimGroup:CreateAnimation(typ, name, template)
    local s = st(self)
    typ = typ or "Animation"
    if not W.classes[typ] then typ = "Animation" end
    local a, as = W.newObject(typ, self, name)
    as.duration, as.delay, as.order = 0, 0, 1
    as.group = self
    table.insert(s.anims, a)
    if template then W.ApplyTemplates(a, template) end
    return a
end
function AnimGroup:GetAnimations() return unpack(st(self).anims) end
function AnimGroup:Play(reverse, offset)
    local s = st(self)
    s.playing, s.elapsed, s.reverse = true, offset or 0, reverse
    playing[self] = true
    W.Fire(self, "OnPlay")
end
function AnimGroup:Restart() AnimGroup.Stop(self) AnimGroup.Play(self) end
function AnimGroup:Stop()
    local s = st(self)
    if not s.playing then return end
    s.playing = false
    playing[self] = nil
    E.ClearAnimEffects(self)
    W.Fire(self, "OnStop")
end
function AnimGroup:Finish() E.FinishGroup(self) end
function AnimGroup:Pause() st(self).paused = true end
function AnimGroup:IsPlaying() return not not st(self).playing end
function AnimGroup:IsPaused() return not not st(self).paused end
function AnimGroup:IsDone() return not st(self).playing end
function AnimGroup:SetLooping(l) st(self).looping = l end
function AnimGroup:GetLooping() return st(self).looping or "NONE" end
function AnimGroup:SetToFinalAlpha(v) st(self).toFinal = not not v end
function AnimGroup:IsSetToFinalAlpha() return not not st(self).toFinal end
function AnimGroup:GetDuration()
    local total = 0
    for _, a in ipairs(st(self).anims) do
        local as = st(a)
        total = math.max(total, as.delay + as.duration)
    end
    return total
end
function AnimGroup:GetProgress() return 0 end
function AnimGroup:SetPlaying(v) if v then AnimGroup.Play(self) else AnimGroup.Stop(self) end end
function AnimGroup:SetAnimationSpeedMultiplier() end
function AnimGroup:GetAnimationSpeedMultiplier() return 1 end
function AnimGroup:IsReverse() return not not st(self).reverse end
function AnimGroup:IsPendingFinish() return false end
function AnimGroup:RemoveAnimations() st(self).anims = {} end

function Anim:SetDuration(d) st(self).duration = Sec.Unwrap(d) or 0 end
function Anim:GetDuration() return st(self).duration end
function Anim:SetStartDelay(d) st(self).delay = d or 0 end
function Anim:GetStartDelay() return st(self).delay end
function Anim:SetEndDelay(d) st(self).endDelay = d or 0 end
function Anim:SetOrder(o) st(self).order = o or 1 end
function Anim:GetOrder() return st(self).order end
function Anim:SetSmoothing(s) st(self).smoothing = s end
function Anim:SetTarget(t) st(self).target = t end
function Anim:SetTargetKey(k) st(self).targetKey = k end
function Anim:SetChildKey(k) st(self).childKey = k end
function Anim:SetTargetName(n) st(self).target = rawget(_G, n) end
function Anim:SetTargetParent() end
function Anim:GetTarget()
    local s = st(self)
    if s.target then return s.target end
    local owner = st(s.group).target
    if s.childKey and owner then return owner[s.childKey] end
    if s.targetKey and owner then return owner[s.targetKey] end
    return owner
end
function Anim:Play() local g = st(self).group AnimGroup.Play(g) end
function Anim:Stop() end
function Anim:IsPlaying() return st(st(self).group).playing end
function Anim:GetProgress() return 0 end
function Anim:GetElapsed() return 0 end
function Anim:SetFromAlpha(a) st(self).fromAlpha = a end
function Anim:SetToAlpha(a) st(self).toAlpha = a end
function Anim:GetFromAlpha() return st(self).fromAlpha or 0 end
function Anim:GetToAlpha() return st(self).toAlpha or 0 end
function Anim:SetOffset(x, y) st(self).offset = { x or 0, y or 0 } end
function Anim:GetOffset() local o = st(self).offset or { 0, 0 } return o[1], o[2] end
function Anim:SetScaleFrom(x, y) st(self).scaleFrom = { x or 1, y or 1 } end
function Anim:SetScaleTo(x, y) st(self).scaleTo = { x or 1, y or 1 } end
function Anim:SetScale(x, y) st(self).scaleTo = { x or 1, y or 1 } end
function Anim:SetOrigin() end
function Anim:SetDegrees(d) st(self).degrees = d end
function Anim:GetDegrees() return st(self).degrees or 0 end
function Anim:SetRadians(r) st(self).degrees = math.deg(r or 0) end
function Anim:SetFlipBookRows() end
function Anim:SetFlipBookColumns() end
function Anim:SetFlipBookFrames() end
function Anim:SetFlipBookFrameWidth() end
function Anim:SetFlipBookFrameHeight() end
function Anim:SetStartColor() end
function Anim:SetEndColor() end
function Anim:SetFromScale(x, y) st(self).scaleFrom = { x or 1, y or 1 } end
function Anim:SetToScale(x, y) st(self).scaleTo = { x or 1, y or 1 } end
function Anim:SetCurveType() end
function Anim:CreateControlPoint() return W.newObject("Animation", self) end

-- Ein Effekt je Ziel: Alpha-Faktor, Versatz, Skalierung.
function E.ClearAnimEffects(group)
    for _, a in ipairs(st(group).anims) do
        local t = Anim.GetTarget(a)
        if t and rawget(t, 0) then
            local ts = st(t)
            ts.animAlpha, ts.animOffset, ts.animScale = nil, nil, nil
        end
    end
    require("layout").Touch()
end

local function applyAnim(a, p)
    local s = st(a)
    local t = Anim.GetTarget(a)
    if not t or not rawget(t, 0) then return end
    local ts = st(t)
    local typ = s.type
    if typ == "Alpha" then
        local from, to = s.fromAlpha or 0, s.toAlpha or 0
        -- Der animierte Wert ersetzt das eigene Alpha, solange die Gruppe laeuft.
        ts.animAlpha = from + (to - from) * p
    elseif typ == "Translation" then
        local o = s.offset or { 0, 0 }
        ts.animOffset = { o[1] * p, o[2] * p }
    elseif typ == "Scale" then
        local f, to = s.scaleFrom or { 1, 1 }, s.scaleTo or { 1, 1 }
        ts.animScale = f[1] + (to[1] - f[1]) * p
    end
end

function E.FinishGroup(g)
    local s = st(g)
    s.playing = false
    playing[g] = nil
    if s.toFinal then
        for _, a in ipairs(s.anims) do applyAnim(a, 1) end
    else
        E.ClearAnimEffects(g)
    end
    W.Fire(g, "OnFinished", false)
end

function E.AdvanceAnimations(dt)
    local groups = {}
    for g in pairs(playing) do groups[#groups + 1] = g end
    table.sort(groups, function(a, b) return st(a).seq < st(b).seq end)
    for _, g in ipairs(groups) do
        local s = st(g)
        if s.playing and not s.paused then
            s.elapsed = s.elapsed + dt
            local total = AnimGroup.GetDuration(g)
            local tt = s.elapsed
            for _, a in ipairs(s.anims) do
                local as = st(a)
                local p = 0
                if as.duration > 0 then p = math.max(0, math.min(1, (tt - as.delay) / as.duration)) elseif tt >= as.delay then p = 1 end
                if tt >= as.delay then applyAnim(a, p) end
                W.Fire(a, "OnUpdate", dt)
            end
            if s.elapsed >= total then
                if s.looping == "REPEAT" or s.looping == "BOUNCE" then
                    s.elapsed = 0
                    W.Fire(g, "OnLoop", "FORWARD")
                else
                    E.FinishGroup(g)
                end
            end
        end
    end
    if #groups > 0 then require("layout").Touch() end
end

return E
