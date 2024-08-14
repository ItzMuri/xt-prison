local playerState           = LocalPlayer.state
local config                = require 'configs.client'
local prisonBreakcfg        = require 'configs.prisonbreak'
local prisonBreakModules    = require 'modules.client.prisonbreak'
local utils                 = require 'modules.client.utils'

local inJail = false

local mainBlip
local PrisonZone
local CheckOutZone

local prisonModules = {}

-- Set Jail Time --
function prisonModules.setJailTime(jailTime)
    if playerState.jailTime == jailTime then
        return true
    end

    playerState:set('jailTime', jailTime, true)
    Wait(100)

    return (playerState.jailTime == jailTime)
end

function prisonModules.createCheckoutLocation()
    if config.XTPrisonJobs then
        exports['xt-prisonjobs']:SetupPrisonJobs()
    else
        local checkoutInfo = config.CheckOut

        if config.useOxtarget then
            CheckOutZone = exports.ox_target:addBoxZone({
                coords = checkoutInfo.coords,
                size = checkoutInfo.size,
                rotation = checkoutInfo.rotation,
                debug = config.DebugPoly,
                drawsprite = true,
                options = {
                    {
                        label = 'Check Time',
                        icon = 'fas fa-hourglass-start',
                        onSelect = function()
                            local timeLeft = lib.callback.await('xt-prison:server:checkJailTime', false)
                            if timeLeft <= 0 then
                                prisonModules.exitPrison(true)
                            end
                        end
                    }
                }
            })
        elseif config.interact then
            CheckOutZone = exports.interact:AddInteraction({
                coords = checkoutInfo.coords,
                distance = 8.0, -- optional
                interactDst = 3.0, -- optional
                id = 'CheckOutZone', -- needed for removing interactions
                name = 'CheckOutZone', -- optional
                ignoreLos = false, -- optional ignores line of sight
                offset = vec3(0.0, 0.0, 0.0), -- optional
                options = {
                     {
                        label = 'Check Time',
                        event = "checkTime",
                        action = function()
                            local timeLeft = lib.callback.await('xt-prison:server:checkJailTime', false)
                            if timeLeft <= 0 then
                                prisonModules.exitPrison(true)
                            end
                        end
                    },
                }
            })
            
        else
            CheckOutZone = exports['qb-target']:AddBoxZone("CheckOutZone", checkoutInfo.coords, checkoutInfo.size[1], checkoutInfo.size[2], {
                name = "CheckOutZone",
                heading = checkoutInfo.rotation,
                debugPoly = config.DebugPoly,
                minZ = checkoutInfo.minZ,
                maxZ = checkoutInfo.maxZ,
            }, {
                options = {
                    {
                        type = "client",
                        event = "checkTime",
                        icon = "fas fa-hourglass-start",
                        label = "Check Time",
                        action = function()
                            local timeLeft = lib.callback.await('xt-prison:server:checkJailTime', false)
                            if timeLeft <= 0 then
                                prisonModules.exitPrison(true)
                            end
                        end
                    },
                },
                distance = 2.5
            })
        end
    end
end

function prisonModules.removeCheckoutLocation()
    if config.XTPrisonJobs then
        exports['xt-prisonjobs']:CleanupPrisonJobs()
    else
        if config.useOxtarget then
            exports.ox_target:removeZone(CheckOutZone)
        elseif config.interact then
            exports.interact:RemoveInteraction('CheckOutZone')
        else
            exports['qb-target']:RemoveZone("CheckOutZone")
        end
    end
end


-- Create Prison Zone for Prison Break Distance Checks --
function prisonModules.createPrisonZone()
    PrisonZone = lib.points.new({
        coords = prisonBreakcfg.Center,
        distance =  prisonBreakcfg.Radius,
    })

    function PrisonZone:onExit()
        if inJail then
            inJail = false
            local alarm = lib.callback.await('xt-prison:server:setPrisonAlarms', false, true)
            if alarm then
                lib.notify({ title = 'You escaped prison!', type = ' error' })
                local breakout = lib.callback.await('xt-prison:server:triggerBreakout', false)
            end
        end
    end

    local mainBlip = utils.createBlip('Prison', prisonBreakcfg.Center, 60, 0.7, 3)
end

-- Removes All Prison Zones, Blips, etc --
function prisonModules.prisonCleanup()
    local saveJailTime = lib.callback.await('xt-prison:server:saveJailTime', false)
    PrisonZone:remove()
    prisonModules.removeCheckoutLocation()
    prisonBreakModules.removeBlip()
    prisonBreakModules.removeHackZones()

    if DoesBlipExist(mainBlip) then
        RemoveBlip(mainBlip)
    end
end

-- Sets Player's Coords --
function prisonModules.setPlayerCoords(coords)
    SetEntityCoords(cache.ped, coords.x, coords.y, coords.z - 0.9, 0, 0, 0, false)
    SetEntityHeading(cache.ped, coords.w)
    local dist = #(vec3(coords.x, coords.y, coords.z - 0.9) - GetEntityCoords(cache.ped))
    return (dist <= 5)
end

-- Entering Prison --
function prisonModules.enterPrison(setTime)
    if config.RemoveJob then
        local removed = lib.callback.await('xt-prison:server:removeJob', false)
        if not removed then
            return false
        end
    end

    local setJailTime = prisonModules.setJailTime(setTime)
    if setJailTime then
        local removeItems = lib.callback.await('xt-prison:server:removeItems', false)
        local isLifer = lib.callback.await('xt-prison:server:liferCheck', false)

        DoScreenFadeOut(2000)
        while not IsScreenFadedOut() do Wait(25) end

        local RandomSpawn = config.Spawns[math.random(1, #config.Spawns)]
        lib.waitFor(function()
            if prisonModules.setPlayerCoords(RandomSpawn.coords) then
                if config.EnablePrisonOutfits then
                    prisonModules.applyPrisonUniform()
                end
                return true
            end
        end, 'your pc is dogshit', 10000)

        TriggerServerEvent("InteractSound_SV:PlayOnSource", "jail", 0.5)

        inJail = true
        config.Emote(RandomSpawn.emote)
        prisonModules.createCheckoutLocation()

        DoScreenFadeIn(2000)
        while not IsScreenFadedIn() do Wait(25) end

        if config.EnterPrisonAlert.enable and not isLifer then
            local alertInfo = config.EnterPrisonAlert
            local alert = lib.alertDialog({
                header = alertInfo.header,
                content = ('**Prison Sentence:** %s  \n%s'):format(setTime, alertInfo.content),
                centered = true,
                labels = { confirm = 'Close' }
            })
        elseif config.EnterPrisonAlert.enable and isLifer then
            lib.notify({ title = 'You\'re a lifer!', type = 'error' })
        end

        if not isLifer then
            prisonModules.timeReductionLoop()
        end

        return true
    end

    return false
end

-- Exiting Prison --
function prisonModules.exitPrison(isUnjailed)
    if playerState.jailTime > 0 and not isUnjailed then
        lib.notify({ title = ('You still have %s months left!'):format(playerState.jailTime), type = 'error' })
        return false
	elseif playerState.jailTime <= 0 or isUnjailed then
        local setJailTime = prisonModules.setJailTime(0)
        if setJailTime then
            inJail = false

            DoScreenFadeOut(2000)
            while not IsScreenFadedOut() do Wait(25) end

            if config.EnablePrisonOutfits then
                config.ResetClothing()
            end

            prisonModules.setPlayerCoords(config.Freedom)

            Wait(500)
            DoScreenFadeIn(2000)
            while not IsScreenFadedIn() do Wait(25) end

            local returnItems = lib.callback.await('xt-prison:server:returnItems', false)

            return true
        end
	end

    return false
end

-- Reduce Jail Time Loop --
function prisonModules.timeReductionLoop()
    CreateThread(function()
        while true do
            if playerState.jailTime > 0 and inJail then
                local newTime = (playerState.jailTime - 1)
                prisonModules.setJailTime(newTime)
            elseif playerState.jailTime <= 0 and inJail then
                lib.notify({
                    title = 'Your time is up! Go checkout!',
                    icon = 'fas fa-unlock',
                    type = 'success'
                })
                break
            end
            Wait(60000)
        end
    end)
end

function prisonModules.applyPrisonUniform()
    local outifitInfo = IsPedModel(cache.ped, 'mp_m_freemode_01') and config.PrisonOufits.male or config.PrisonOufits.female
    SetPedComponentVariation(cache.ped, 1, outifitInfo.mask.item, outifitInfo.mask.texture)                 -- Mask
    SetPedComponentVariation(cache.ped, 3, outifitInfo.arms.item, outifitInfo.arms.texture)                 -- Arms
    SetPedComponentVariation(cache.ped, 4, outifitInfo.pants.item, outifitInfo.pants.texture)               -- Pants
    SetPedComponentVariation(cache.ped, 6, outifitInfo.shoes.item, outifitInfo.shoes.texture)               -- Shoes
    SetPedComponentVariation(cache.ped, 7, outifitInfo.accessories.item, outifitInfo.accessories.texture)   -- Accessory
    SetPedComponentVariation(cache.ped, 8, outifitInfo.shirt.item, outifitInfo.shirt.texture)               -- Shirt
    SetPedComponentVariation(cache.ped, 11, outifitInfo.jacket.item, outifitInfo.jacket.texture)            -- Jacket
end

return prisonModules