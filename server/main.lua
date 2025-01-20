lib.locale()
local robbingPlayers = {}
local recentlyRobbedNPCs = {}

---@type fun(source: number, npcId: number)
---@return boolean
lib.callback.register('hajden_npcrobbery:server:canRobNPC', function(source, npcId)
    if recentlyRobbedNPCs[npcId] then
        return false
    end
    return true
end)

---@type fun(npcId: number)
lib.callback.register('hajden_npcrobbery:server:markNPCAsRobbed', function(npcId)
    recentlyRobbedNPCs[npcId] = true

    CreateThread(function()
        Wait(Config.pedCooldown)
        recentlyRobbedNPCs[npcId] = nil
    end)
end)

---@type fun(targetNPC: number)
RegisterNetEvent('hajden_npcrobbery:server:start', function(targetNPC)
    local source = source
    local player = Ox.GetPlayer(source)

    if not player then return end

    robbingPlayers[source] = { 
        target = targetNPC, 
        startTime = os.time()
    }
    TriggerClientEvent('hajden_npcrobbery:client:start', source, targetNPC)
end)

RegisterNetEvent('hajden_npcrobbery:server:success', function()
    local source = source
    local data = robbingPlayers[source]

    if not data then
        -- cheater pravděpodobně
        return
    end

    local elapsedTime = os.time() - data.startTime
    if elapsedTime <= Config.robberyTime-5 then
        return
    end

    local reward = math.random(Config.rewardRange[1], Config.rewardRange[2])
    exports.ox_inventory:AddItem(source, Config.rewardItem, reward)

    TriggerClientEvent('ox_lib:notify', source, { 
        type = 'success', 
        description = locale('rewardinfo', reward)
    })

    robbingPlayers[source] = nil
end)

AddEventHandler('playerDropped', function()
    local source = source
    robbingPlayers[source] = nil
end)