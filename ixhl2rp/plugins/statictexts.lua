local PLUGIN = PLUGIN

PLUGIN.name = "Static Texts"
PLUGIN.author = "big"
PLUGIN.description = "Добавить летающий текст."

local texts = PLUGIN.texts or {}
PLUGIN.texts = texts

ix.config.Add("staticTextLifeTime", 240, "Время через которое текст будет удален (в минутах)", nil, {
    data = {min = 1, max = 10080},
    category = "Other"
})

CAMI.RegisterPrivilege({
    Name = "Helix - Static Texts",
    MinAccess = "admin"
})

-- Иконка глаза для отображения
PLUGIN.eyeIcon = Material("big_ui/util/eye.png")

do
    local COMMAND = {}
    COMMAND.description = "Добавить летающий текст."
    COMMAND.arguments = ix.type.text
    COMMAND.privilege = "Static Texts"
    COMMAND.alias = {"StaticTextAdd", "SceneTextAdd"}

    function COMMAND:OnRun(client, text)
        local curTime = CurTime()

        if (client.nextStaticText and client.nextStaticText >= curTime) then
            client:NotifyLocalized("notNow")

            return
        end

        if (text == "") then
            return
        end

        local pos = client:GetPos()
        
        for k, v in pairs(texts) do
            if (v.pos:DistToSqr(pos) < 50 * 50) then
                client:Notify("Слишком близко к остальному тексту!")

                return
            end

            if (v.steamid == client:SteamID() and !CAMI.PlayerHasAccess(client, "Helix - Static Texts")) then
                client:Notify("У вас уже есть статический текст, удалите его, прежде чем добавлять новый.")

                return
            end
        end

        local data = {
            pos = pos + Vector(0, 0, 30),
            text = text,
            name = client:GetName(),
            steamid = client:SteamID(),
            time = os.date("%d/%m/%y %X", os.time()),
            showText = false, 
            eyeAlpha = 0, 
            textAlpha = 0, 
            proximityAlpha = 0, 
            lookAlpha = 0 
        }

        PLUGIN:AddStaticText(data)

        client.nextStaticText = curTime + 5
        client:Notify("Текст добавлен.")

        ix.log.Add(client, "staticTextAdded", text)
    end

    ix.command.Add("SceneText", COMMAND)
end

do
    local COMMAND = {}
    COMMAND.description = "Удалить летающий текст."
    COMMAND.privilege = "Static Texts"
    COMMAND.alias = {"StaticTextRemove", "RemoveSceneText"}

    function COMMAND:OnRun(client)
        local trace = client:GetEyeTraceNoCursor()

        if (trace.Hit) then
            local pos = trace.HitPos

            for k, v in pairs(texts) do
                if (v.pos:DistToSqr(pos) < 50 * 50) then
                    if (v.steamid == client:SteamID() or CAMI.PlayerHasAccess(client, "Helix - Static Texts")) then
                        PLUGIN:RemoveStaticText(k)
                        client:Notify("Летающий текст удален.")

                        ix.log.Add(client, "staticTextRemoved", text)
                    else
                        client:Notify("У вас нет разрешения удалять этот текст.")
                    end

                    return
                end
            end
        end
    end

    ix.command.Add("SceneTextRemove", COMMAND)
end

if (CLIENT) then
    local nextCheck = -1
    local EYE_SIZE = 46 -- Размер иконки глаза
    local FADE_SPEED = 5 -- Скорость плавного перехода
    local MAX_VIEW_DISTANCE = 400 -- Максимальное расстояние для плавного появления
    local MIN_VIEW_DISTANCE = 100 -- Минимальное расстояние для полной видимости
    local PROXIMITY_FADE_START = 300 -- Расстояние, с которого начинается появление глаза

    local function CanSee(client, clientPos, data)
        local curTime = CurTime()

        if (nextCheck <= curTime or !data.visible) then
            local trace = util.TraceLine({
                start = clientPos,
                endpos = data.pos,
                mask = MASK_SOLID_BRUSHONLY
            })

            data.visible = !trace.hit
        end

        return data.visible
    end

   
    local function IsLookingAtEye(client, eyePos)
        local eyePos2D = eyePos:ToScreen()
        if (!eyePos2D.visible) then return false end
        
        local mouseX, mouseY = gui.MousePos()
        local cx, cy = ScrW() * 0.5, ScrH() * 0.5
        
        
        local useX, useY = mouseX, mouseY
        if (useX == 0 and useY == 0) then
            useX, useY = cx, cy
        end
        
        local distance = math.Distance(useX, useY, eyePos2D.x, eyePos2D.y)
        return distance <= EYE_SIZE
    end

    -- Расчет альфа-канала в зависимости от расстояния
    local function CalculateProximityAlpha(distance)
        if distance <= MIN_VIEW_DISTANCE then
            return 1.0 -- Полная видимость
        elseif distance <= PROXIMITY_FADE_START then
            -- Плавное уменьшение от 1.0 до 0.0
            return 1.0 - ((distance - MIN_VIEW_DISTANCE) / (PROXIMITY_FADE_START - MIN_VIEW_DISTANCE))
        else
            return 0.0 -- Полная прозрачность
        end
    end

    function PLUGIN:HUDPaint()
        if (texts and !table.IsEmpty(texts)) then
            local client = LocalPlayer()
            local clientPos = client:EyePos()
            local scrW = ScrW()
            local cx, cy = scrW * 0.5, ScrH() * 0.5
            local hasPermission = CAMI.PlayerHasAccess(client, "Helix - Static Texts")
            local frameTime = FrameTime()

            for k, v in pairs(texts) do
                local distance = clientPos:Distance(v.pos)
                
                if (distance <= MAX_VIEW_DISTANCE and CanSee(client, clientPos, v)) then
                    local pos = v.pos:ToScreen()
                    
                    if (pos.visible) then
                        
                        local targetProximityAlpha = CalculateProximityAlpha(distance)
                        
                        
                        v.proximityAlpha = Lerp(frameTime * 2, v.proximityAlpha, targetProximityAlpha)
                        
                        
                        local lookingAtEye = IsLookingAtEye(client, v.pos)
                        
                        if (lookingAtEye and !v.showText) then
                            v.showText = true
                        elseif (!lookingAtEye and v.showText) then
                            v.showText = false
                        end
                        
                        
                        local targetLookAlpha = v.showText and 1 or 0
                        v.lookAlpha = Lerp(frameTime * FADE_SPEED, v.lookAlpha, targetLookAlpha)
                        
                        
                        local eyeAlphaMultiplier = v.proximityAlpha * (1 - v.lookAlpha)
                        
                       
                        local textAlphaMultiplier = v.proximityAlpha * v.lookAlpha
                        
                        
                        local finalEyeAlpha = 255 * eyeAlphaMultiplier
                        local finalTextAlpha = 255 * textAlphaMultiplier
                        
                        
                        v.eyeAlpha = Lerp(frameTime * FADE_SPEED, v.eyeAlpha, finalEyeAlpha)
                        v.textAlpha = Lerp(frameTime * FADE_SPEED, v.textAlpha, finalTextAlpha)
                        
                        
                        if (v.eyeAlpha > 5) then 
                            surface.SetMaterial(self.eyeIcon)
                            surface.SetDrawColor(255, 255, 255, v.eyeAlpha)
                            surface.DrawTexturedRect(pos.x - EYE_SIZE/2, pos.y - EYE_SIZE/2, EYE_SIZE, EYE_SIZE)
                        end
                        
                        
                        if (v.textAlpha > 5) then
                            local camMult = (1 - math.Distance(cx, cy, pos.x, pos.y) / scrW * 1.5)
                            local distanceMult = (1 - distance / MAX_VIEW_DISTANCE)
                            local alpha = v.textAlpha * camMult * distanceMult
                            local col1, col2 = Color(255, 255, 255, alpha), Color(0, 0, 0, alpha)
                            local font = "ixGenericFont"

                            surface.SetFont(font)

                            local lines = ix.util.WrapText(v.text, scrW * 0.25, font)

                            if (input.IsKeyDown(KEY_LALT) and hasPermission) then
                                table.insert(lines, v.name..' ('..v.steamid..')')
                                table.insert(lines, v.time)
                            end

                            local fullH = #lines * 20 
                            local curY = pos.y - fullH / 2

                            for k1, v1 in pairs(lines) do
                                local w, h = surface.GetTextSize(v1)
                                draw.SimpleTextOutlined(v1, font, pos.x - w / 2, curY, col1, nil, nil, 1, col2)
                                curY = curY + h + 4
                            end
                        end
                    end
                else
                    
                    if (v.eyeAlpha > 0 or v.textAlpha > 0) then
                        v.eyeAlpha = Lerp(frameTime * FADE_SPEED * 2, v.eyeAlpha, 0)
                        v.textAlpha = Lerp(frameTime * FADE_SPEED * 2, v.textAlpha, 0)
                        v.proximityAlpha = Lerp(frameTime * 2, v.proximityAlpha, 0)
                        v.lookAlpha = Lerp(frameTime * FADE_SPEED, v.lookAlpha, 0)
                        v.showText = false
                    end
                end
            end
        end
    end

    netstream.Hook("ixStaticTextAdd", function(data)
        table.insert(texts, data)
    end)

    netstream.Hook("ixStaticTextRemove", function(id)
        table.remove(texts, id)
    end)

    netstream.Hook("ixStaticTextSet", function(data)
        texts = data
    end)
else
    ix.log.AddType("staticTextAdded", function(client, text)
        return string.format("%s добавил лелающий текст: %s", client:GetName(), text)
    end)

    ix.log.AddType("staticTextRemoved", function(client, text)
        return string.format("%s удалил летающий текст: %s", client:GetName(), text)
    end)

    function PLUGIN:AddStaticText(data)
        local id = table.insert(texts, data)

        -- Таймер для удаления текста
        timer.Create("ixStaticText"..id, ix.config.Get("staticTextLifeTime", 240) * 60, 1, function()
            self:RemoveStaticText(id)
        end)

        netstream.Start(nil, "ixStaticTextAdd", data)
    end

    function PLUGIN:RemoveStaticText(id)
        if (texts[id]) then
            table.remove(texts, id)

            -- Удаляем таймер
            local timerId = "ixStaticText"..id
            if (timer.Exists(timerId)) then
                timer.Remove(timerId)
            end

            netstream.Start(nil, "ixStaticTextRemove", id)
        end
    end

    function PLUGIN:PlayerInitialSpawn(client)
        timer.Simple(2, function()
            netstream.Start(client, "ixStaticTextSet", texts)
        end)
    end

    function PLUGIN:SaveData()
        for k, v in pairs(texts) do
            local timerId = "ixStaticText"..k
            
            if (timer.Exists(timerId)) then
                v.timeLeft = timer.TimeLeft(timerId)
            end
        end

        ix.data.Set("statictexts", texts)
    end

    function PLUGIN:LoadData()
        local loaded = ix.data.Get("statictexts", {})

        for k, v in pairs(loaded) do
            self:AddStaticText(v)
        end
    end
end