local config    = require 'configs.client'
local utils     = require 'modules.client.utils'

local prisonDoc
local prisonDocBlip

local function initPrisonDoctor()
    if DoesEntityExist(prisonDoc) then return end

    local docInfo = config.PrisonDoctor
    prisonDoc = utils.createPed(docInfo.model, docInfo.coords, docInfo.scenario)
    prisonDocBlip = utils.createBlip('Prison Infirmary', docInfo.coords, 61, 0.3, 1)
    if config.useOxtarget then
    exports.ox_target:addLocalEntity(prisonDoc, {
        {
            label = 'Receive Check-Up',
            icon = 'fas fa-stethoscope',
            onSelect = function()
                if lib.progressCircle({
                    label = 'Receiving Checkup...',
                    duration = (docInfo.healLength * 1000),
                    position = 'bottom',
                    useWhileDead = true,
                    canCancel = false,
                    disable = {
                        move = true,
                        car = true,
                        combat = true,
                        sprint = true,
                    },
                }) then
                    lib.notify({ title = 'Healed', description = 'You received a checkup from the doctor!', type = 'success' })
                    config.PlayerHealed()
                end
            end
        }
    })
    elseif config.interact then
        exports.interact:AddLocalEntityInteraction({
            entity = prisonDoc,
            name = 'PlayerHealed', -- optional
            id = 'PlayerHealed', -- needed for removing interactions
            distance = 8.0, -- optional
            interactDst = 3.0, -- optional
            ignoreLos = true, -- optional ignores line of sight
            offset = vec3(0.0, 0.0, 0.0), -- optional
            options = {
                {
                    label = 'Receive Check-Up',
                    icon = 'fas fa-stethoscope',
                    action = function(entity)
                        if lib.progressCircle({
                            label = 'Receiving Checkup...',
                            duration = (docInfo.healLength * 1000),
                            position = 'bottom',
                            useWhileDead = true,
                            canCancel = false,
                            disable = {
                                move = true,
                                car = true,
                                combat = true,
                                sprint = true,
                            },
                        }) then
                            lib.notify({ title = 'Healed', description = 'You received a checkup from the doctor!', type = 'success' })
                            config.PlayerHealed()
                        end
                    end
                },
            },
        })
    else
        exports['qb-target']:AddTargetEntity(prisonDoc, {
            options = {
                {
                    label = 'Receive Check-Up',
                    icon = 'fas fa-stethoscope',
                    action = function(entity)
                        if lib.progressCircle({
                            label = 'Receiving Checkup...',
                            duration = (docInfo.healLength * 1000),
                            position = 'bottom',
                            useWhileDead = true,
                            canCancel = false,
                            disable = {
                                move = true,
                                car = true,
                                combat = true,
                                sprint = true,
                            },
                        }) then
                            lib.notify({ title = 'Healed', description = 'You received a checkup from the doctor!', type = 'success' })
                            config.PlayerHealed()
                        end
                    end
                },
            },
            distance = 2.5,
        })
    end
end

local function removePrisonDoctor()
        if not DoesEntityExist(prisonDoc) and not DoesBlipExist(prisonDocBlip) then
            return
        end

        if config.useOxtarget then
            exports.ox_target:removeLocalEntity(prisonDoc, 'Receive Check-Up')
        elseif config.interact then
            exports.interact:RemoveLocalEntityInteraction(prisonDoc, 'PlayerHealed')
        else
            exports['qb-target']:RemoveTargetEntity(prisonDoc)
        end
        DeletePed(prisonDoc)
    if DoesBlipExist(prisonDocBlip) then
        RemoveBlip(prisonDoc)
    end
    
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    initPrisonDoctor()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    removePrisonDoctor()
end)

AddEventHandler('xt-prison:client:onLoad', function()
    initPrisonDoctor()
end)

AddEventHandler('xt-prison:client:onUnload', function()
    removePrisonDoctor()
end)
