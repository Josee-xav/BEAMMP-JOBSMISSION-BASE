local M = {}

local gui_module = require("ge/extensions/editor/api/gui")
local gui = {setupEditorGuiTheme = nop}
local im = ui_imgui
local ffi = require('ffi')

local nametagsBlocked = false

local trailer = nil; -- TODO

inMission = { active = false, missionA = nil, missionB = nil, currentlyOnTrigger = nil }
    
-- this shit is so messy
function getMapMissionPoints()
        -- get mission name aka italy, and shit
        --
        -- concat it
end

missionLocations = jsonReadFile("/fffresources/json/italy_missionLocations.json")

function spawnAtLocation(data)
    local location = jsonDecode(data)

    local configfile = "settings/funS/savedvehicle.pc" 

    if FS:fileExists(configfile) then
        local data = jsonReadFile(configfile)
        core_vehicles.spawnNewVehicle(data.model, {config = configfile, licenseText = data.licenseName, pos = vec3(location["x"], location["y"], location["z"])})
    else
        core_vehicles.spawnNewVehicle("pickup", {pos = vec3(location["x"], location["y"], location["z"])})
    end

end

-- json data needs x, y, z
-- vim ./vehicle/controller/beamNavigator.lua
function markGps(data)
    local location = jsonDecode(data)
    log("D", "markgps", dumps(data))
    -- remove previous gps shit
    local trigger = scenetree.findObject("GPSTrigger")
    if trigger ~= nil then
        trigger:delete()
    end
    local marker = scenetree.findObject("GPSMarker")
    if marker ~= nil then
        marker:delete()
    end

    if location ~= nil then
        log("D", "markgps", "create")
        core_groundMarkers.setFocus(vec3(location["x"],location["y"],location["z"]))
        return true
    else
        core_groundMarkers.setFocus(nil)
    end

    return false
end


function createMissionGroup(missionGroupName)
    if scenetree[missionGroupName] then
        return
    end --already exists
    if not scenetree.MissionGroup then
        log("E", "createmissiongroup", "does not exist")
        return
    end 

    
    local simGroupObject = createObject("SimGroup")
    simGroupObject:registerObject(missionGroupName)
    simGroupObject.canSave = false

    scenetree.MissionGroup:addObject(simGroupObject.obj)
    log("I", "createmissiongroup", "Created : " .. missionGroupName)
end

function createMarker(sceneTreeGroupName, markername, markerPosition)
    local marker = createObject("TSStatic")
    local position = Point3F(markerPosition)
    position.z = position.z
    marker.shapeName = "art/shapes/interface/checkpoint_marker_base.dae"
    marker:setPosition(position)
    marker.scale = Point3F(3, 3, 3)
    marker.useInstanceRenderData = 1
    --marker.instanceColor =
    marker:registerObject(markername .. "_icon")


    -- check
    if sceneTreeGroupName and scenetree[sceneTreeGroupName] and marker.obj then
        scenetree[sceneTreeGroupName]:addObject(marker.obj)
        log("I", "createMarker", "added marker " )
    end

    return marker
end

function stringToPoint3f(string_pos)
    local coords = stringToTable(string_pos, ",")
    return Point3F(tonumber(coords[1]), tonumber(coords[2]), tonumber(coords[3]) + 0.6)
end

-- TODO BeamNG-FuelStations:https://docs.beammp.com/beamng/snippets/#drawing-a-marker-vehicle-detection
-- why would u loop on onupdate rather than setup a trigger?
function getCurrentVehicle()
    local vehCount = be:getObjectCount()
    -- TODO NEEDS TO BE FIXED	
    -- if user has more than one car... find the currently active
    if vehCount > 1 then
        for i=0, vehCount do
            local vehicle = be:getObject(i)
            if vehicle:getActive() then
                log("I", "getCurrentVehicle", "multi?"..dumps(vehicle)  )
                return vehicle
            end
        end
    end


    -- user only has one vehicle
    local playerVehicleID= be:getPlayerVehicleID(0)
    local vehicleData = map.objects[playerVehicleID]
    -- TODO need error checkingnnnnnnnnnnnnnnn 

    log("I", "getCurrentVehicle", " oneveh"..dumps(vehicleData)  )
    return vehicleData
end

function startMission()
    -- if your not in a mission , and if actually on a mission trigger
    if inMission["active"] == false and inMission["currentlyOnTrigger"] ~= nil then
        local data = string.format("{\"MissionName\":\"%s\"  }", inMission["currentlyOnTrigger"])
        TriggerServerEvent("startMission", data)
        
        local veh = getCurrentVehicle();
        local send = { config = "vehicles/boxutility/loaded_200.pc", autoEnterVehicle = false};

        -- if u dont add the x y z positions it just spawns nearby player.
         trailer = core_vehicles.spawnNewVehicle("boxutility", send);

        --spawnAtLocation();
    end
    log("D", "startMission", " your in a mission already or not at a mission location " )
    log("D", "startMission", dumps(inMission))
end

function getRandomMissionPoint()
    local i = math.random(1, #missionLocations )
    return missionLocations[i]
end

function findMission()
    -- TODO this shouldnt be "random" should get the closest mission n
    local mp = getRandomMissionPoint()

    markGps(jsonEncode(mp))
end

function isNearby(pos1, pos2, threshold)
    local dx = pos2.x - pos1.x
    local dy = pos2.y - pos1.y
    local dz = pos2.z - pos1.z
    local distanceSquared = dx * dx + dy * dy + dz * dz
    log('D', "distanceee", distanceSquared )
    return distanceSquared <= threshold * threshold
end

-- trigger mission point where user parks on it and itll send server completed!
-- then SERVER needs to check if the player is at the mission
function onTriggerLocation(data )
    -- makes sure player is not moving!
    -- checks if their is a mission active. techniquely if this function gets called when theirs mission is not active then theirs a problem :p
    --  just good to make sure
    if inMission["active"] == true and be:getPlayerVehicle(0):getVelocity():length() == 0 then
        if trailer ~= nil then
            local t = isNearby(trailer:getPosition(), be:getPlayerVehicle(0):getPosition(), 20);

            -- TODO good idea to do this server sided instead?
            -- trailer no where near the car.
            if t == false then
                guihooks.trigger('toastrMsg', {type = "info", title = "Info Message:", msg = "Trailer is no where near car... go back and get it or reset.", config = {timeOut = 5000}})
                return;
            end
        else
            -- TODO -- WHERE HAPPENED TO THE TRAILER THEN
        end


        TriggerServerEvent("triggerMissionCompleted", data.triggerName)
        core_groundMarkers.setFocus(nil)
        inMission["active"] = false
        local missionTrigger = scenetree.findObject(data.triggerName)
        missionTrigger:delete()
        
        trailer:delete();

    end
end

function createMissionTrigger(data, onCallFunctionString, i_tickingperiod, tag)
    log('D', "createMissionTrigger", dumps(data) )
    local location = jsonDecode(data)
    local name =  location["name"]

    if name == nil then
        TriggerServerEvent("debug", "createMissionTrigger has failed which means you sent something wrong!!!!!!!!!!!!!" )   
         log("E", "createMissionTrigger",  "createMissionTrigger has failed which means you sent something wrong!!!!!!!!!!!!!")   
    end

    local trigger = createObject("BeamNGTrigger") -- This is the class, there's many other things you can create here
    trigger.loadMode = 1 -- I don't remember exactly what this one is, I think it's so it enables itself by default.
    trigger.name = name .. tag
    trigger.scale = Point3F(0.05,0.05,20)

    trigger:setPosRot(location["x"], location["y"], location["z"], 0, 0, 3, 3)

    -- Set some of the fields, you can view these in the editor, find what works, and then change them here
    trigger:setField("triggerMode", 0, "Contains")
    trigger:setField("triggerType", 0, "Sphere")
    trigger.luaFunction = String(onCallFunctionString)
    trigger.tickperiod = i_tickingperiod
    trigger.ticking = true 

    trigger.Debug = false-- So it's visible in the world
    trigger.debugInEditor = true
    trigger:registerObject(name .. tag) -- Register the object, important! :D
end

-- data has x y z json and other
function gotoDelivery(data)
    log("I", "gotodelivery",  data  )
    if markGps(data) == true then
        createMissionTrigger(data, "onTriggerLocation", 1000, "_mission" )
        inMission["active"] = true
    else
        log("I", "gotodelivery", "something wrong happened" .. data  )
        inMission["active"] = false
    end
end


function onMissionTrigger(data)
    -- makes sure player is still, not in a mission so they cannot start two missions, and on enter event
    if data.event ~= 'exit' and inMission["active"] == false then
        inMission["currentlyOnTrigger"] = data.triggerName  
        log("I", "onmissiontrtrigger", "setting triggername"  )
    else
        inMission["currentlyOnTrigger"] = nil
        log("I", "onmissiontrtrigger", "off trigger"  )
    end

end

function createMissionLocations(groupName)
    for key in pairs(missionLocations) do
        local missionL = missionLocations[key]
        local pointpos = Point3F(tonumber(missionL["x"]), tonumber(missionL["y"]), tonumber(missionL["z"]) + 0.6)
        createMissionGroup(groupName)
        createMarker(groupName, missionL["name"], pointpos)
        local missionData = jsonEncode(missionL) 

        createMissionTrigger(missionData , "onMissionTrigger", 1000 , "_trigger" )
    end
end



function drawGui()
    gui.setupWindow("MGUI")
    im.Begin("Nametags")
    im.Indent()
    im.Indent()
    if nametagsBlocked then
        if im.SmallButton("Show") then
            nametagsBlocked = false
        end
    else
        if im.SmallButton("Hide") then
            nametagsBlocked = true
        end
    end

    if im.SmallButton("Mission") then
        startMission()
    elseif im.SmallButton("mark mission") then
        findMission()
    elseif im.SmallButton("Save vehicle") then
      core_vehicle_partmgmt.save("settings/funS/savedvehicle.pc")
        -- TODO send the server this file to save it on the server or else if the player removes beamng then reinstalls, they will lose their config
        -- or you could just send the partmgnt file format data directly to server as a string
        -- local function savePartConfigFileStage2_Format2(partsCondition, filename)
        -- this function in beamng makes the config file for cars
    end


    im.Unindent()
    im.Unindent()
    im.End()
end

local checked = false
local function onUpdate()
    if worldReadyState == 2 then
        drawGui()
        if not checked then
            TriggerServerEvent("playerFullyLoaded", "")
            checked = true
        end
    end
end

local function onPreRender()
    if nametagsBlocked then
        MPVehicleGE.hideNicknames(true)
    else
        MPVehicleGE.hideNicknames(false)
    end
end

local function onExtensionLoaded()

    gui_module.initialize(gui)
    gui.registerWindow("MGUI", im.ImVec2(100, 56))
    gui.showWindow("MGUI")
    log('W', "onExtensionLoaded", "loadedd")
    createMissionLocations("Traders")
    AddEventHandler("gotoDelivery", gotoDelivery)
    AddEventHandler("spawnAtLocation", spawnAtLocation)
end

local function onExtensionUnloaded()
    log('W', "ad", "-=$=- NAMETAG BUTTON UNLOADED -=$=-")
end

M.dependencies = {"ui_imgui"}

M.onUpdate = onUpdate
M.onPreRender = onPreRender

M.onWorldReadyState = onWorldReadyState

M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded

M.onTriggerLocation = onTriggerLocation

return M
