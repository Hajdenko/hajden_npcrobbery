lib.locale()
local isRobbing = false

---@type fun(pPed: number, animDict: string, animName: string, duration: number|nil, flags: number|nil)
---@param flag number|nil
---0/nil Žádny flag
---1 Loop
---49 Movement
---51 Movement&Loop
---Víc si nepamatuju :D
local function playAnim(pPed, animDict, animName, dur, flag)
    CreateThread(function()
        lib.requestAnimDict(animDict)
        TaskPlayAnim(pPed, animDict, animName, 8.0, 8.0, dur or -1, flag or 0, 0.0, false, false, false)
        if dur and dur > 0 then
            Wait(dur)
            ClearPedTasks(pPed)
            RemoveAnimDict(animDict)
        end
    end)
end

---@type fun(npc: number)
---@return boolean
local function canRobEntity(npc)
    if IsPedDeadOrDying(npc, true) then
        lib.notify({
            title = locale('robbery'),
            description = locale("deadordying"),
            type = 'error'
        })
        return false
    end

    local npcId = NetworkGetNetworkIdFromEntity(npc)
    local result = lib.callback.await("hajden_npcrobbery:server:canRobNPC", false, npcId)
    if not result then
        lib.notify({
            title = locale('robbery'),
            description = locale('cooldown'),
            type = 'error'
        })
        return false
    end

    return true
end

print("cs")
exports.ox_target:addGlobalPed({
    {
        name = 'robbery_ped',
        icon = 'fa-solid fa-male',
        label = locale('rob_action'),

        ---@type fun(entity: number)
        ---@return boolean
        canInteract = function(entity)
            return IsPedArmed(cache.ped, 7)
        end,

        ---@type fun(d: table)
        ---@param d table info ohledne targetu (coords resource entity distance self...)
        onSelect = function(d)
            if d.distance <= Config.interactDistance then
                TriggerServerEvent('hajden_npcrobbery:server:start', d.entity)
            end
        end
    }
})

---@type fun(target: number)
---@param target number npc co hrac okrada
RegisterNetEvent('hajden_npcrobbery:client:start')
AddEventHandler('hajden_npcrobbery:client:start', function(target)
    if isRobbing then return end
    isRobbing = true
    rbrTime = Config.robberyTime*1000

    local npcId = NetworkGetNetworkIdFromEntity(target)
    lib.callback.await("hajden_npcrobbery:server:markNPCAsRobbed", npcId)

    local ped = cache.ped

    SetBlockingOfNonTemporaryEvents(target, true)
    SetPedFleeAttributes(target, 0, false)
    SetPedCombatAttributes(target, 17, true)
    SetEntityInvincible(target, false)

    -- whistle, upoutá pozornost a pedi se na sebe otočí
    playAnim(ped, 'taxi_hail', 'hail_taxi', rbrTime/40)
    TaskTurnPedToFaceEntity(ped, target, 2000)
    TaskTurnPedToFaceEntity(target, ped, 2000)
    Wait(rbrTime/20)

    -- znehybní pedy
    FreezeEntityPosition(ped, true)
    FreezeEntityPosition(target, true)
    playAnim(ped, 'mini@triathlon', 'want_some_of_this', rbrTime/15)

    Wait(rbrTime/15)
    FreezeEntityPosition(ped, false)
    TaskAimGunAtEntity(ped, target, -1, true) -- pokus o namíření automaticky na peda, ale nějak to u mě přestalo fungovat, není tak podstatné :P
    FreezeEntityPosition(ped, true)

    CreateThread(function()
        -- scared/pomalu zvedající ruce animace :D
        playAnim(target, 'anim@mp_player_intuppersurrender', 'idle_a_fp', rbrTime/40)
        Wait(1000)
        -- classic handsup animace
        playAnim(target, 'missminuteman_1ig_2', 'handsup_base', rbrTime-1000, 1)
    end)

    local robFailed = math.random(1, 4) == 1 -- 25%

    CreateThread(function()
        if robFailed then
            Wait(math.random(1000, 19000))
            if lib.progressActive() then lib.cancelProgress() end
            FreezeEntityPosition(ped, false)
            FreezeEntityPosition(target, false)

            TaskSmartFleePed(target, ped, 100.0, -1, false, false) -- uteče

            Config.callPolice()
            lib.notify({
                title = locale('robbery'),
                description = locale('runaway'),
                type = 'warning'
            })
            playAnim(target, 'cellphone@', 'cellphone_call_listen_base', rbrTime/10, 51)
            playAnim(ped, 'anim@am_hold_up@male', 'shoplift_mid', rbrTime/20, 51)
        end
    end)

    if not lib.progressBar({
        duration = rbrTime,
        label = locale("robbing"),
        useWhileDead = false,
        canCancel = true
    }) then
        if robFailed then return end

        -- https://forum.cfx.re/t/peds-attack-players/3467
        local weaponHash = GetHashKey(Config.NameWeaponNPC)
        GiveWeaponToPed(target, weaponHash, 200, false, true)
        SetPedRelationshipGroupHash(target, GetHashKey("ENEMY"))
        FreezeEntityPosition(ped, false)
        FreezeEntityPosition(target, false)
        TaskCombatPed(target, ped, 0, 16)
        
        Config.callPolice()
        isRobbing = false
        return
    end

    if not robFailed then
        TriggerServerEvent('hajden_npcrobbery:server:success')
    end

    FreezeEntityPosition(ped, false)
    FreezeEntityPosition(target, false)
    TaskSmartFleePed(target, ped, 100.0, -1, false, false) -- uteče
    isRobbing = false
end)