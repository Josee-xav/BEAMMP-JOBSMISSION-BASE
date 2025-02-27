local M = {}


MISSION_LOCATIONS_JSON = "E:\\beamngserver\\missionLocations.json" 
PLAYER_DATABASE_JSON = "E:\\beamngserver\\playerDatabase.json"
CARPARTS_DATABASE_JSON = "E:\\beamngserver\\carparts.json"
CARDEALER_DATABASE_JSON = "E:\\beamngserver\\carDealership.json"

function readJsonFile(filepath)
    local data = io.open(filepath, "r") 
    if data == nil then
        print("READING JSON FILE :((((((((((((FAILEDDD") 
        return nil
    end
    print("LOADED JSON FILE SUCCESSFULYLYLYL") 
    local jsonn = data:read('*all')
    return Util.JsonDecode(jsonn)
end

mission_points= readJsonFile(MISSION_LOCATIONS_JSON)
playerDatabase = readJsonFile(PLAYER_DATABASE_JSON)
carpartsDatabase = readJsonFile(CARPARTS_DATABASE_JSON)
carDatabase = readJsonFile(CARDEALER_DATABASE_JSON)

activeEventsLogged = {}

-- TODO should use sql
function savePlayerDatabase()
    local file= io.open(PLAYER_DATABASE_JSON, "w") 
    if file == nil then
        print("SAVING JSON FILE :((((((((((((FAILEDDD") 
        return nil
    end
  
    playerDatabase["ignore"] = nil 

    local jsondataa = Util.JsonEncode(playerDatabase)
    if jsondataa ~= "" then
        file:write(jsondataa)
        file:close()
        print("SAVED JSON FILE SUCCESSFULYLYLYL")
    else 
        print("savplayerdata jsondataaafail"..jsondataa)
        print("SAVING PLAYER DATABASE FAILKEDDE")
    end
end

-- load json of mission points and check if user is at correct place 
function getRandomMissionPoint(currentPointName)
    local deliverName = nil
    local name =  nil
    repeat 
        local i = tonumber(math.random(1, #mission_points  ))
        print(tonumber(i)) 
        deliverName = mission_points[i]
        name = deliverName["name"] .. "_trigger" 
        print(name) 
    until(currentPointName ~= name)

    return deliverName
end

-- check if player is at the mission location?
-- assign client a delivery end point via a trigger with data of location for the client to send marker

-- should verify position
-- verify vehid is from the player
-- should send missionpoint name rather than everything else
function sstartMission(playerServerId, data)
    local data_json = Util.JsonDecode(data)
    print("starrtmision"..data)

    -- terry,dave,micheal in x clan will have a clan seed so when requested for a mission they all will go to same delivery end location
    -- very basic and shit but it allows people to deliver together. but if dave is in a starting mission location of b while the rest of the group is a different mission start location they all will still go to the same end point which is bit mid
    --if(player.inclan == true) then
    --    math.randomseed(clanseed + something)

    -- sets the seed for random to epoch time
    math.randomseed(os.time()); 
    local missionPointB_json = getRandomMissionPoint(data_json["MissionName"])
  
    if activeEventsLogged[playerServerId] == nil then
        activeEventsLogged[playerServerId] = {}
    end

    local ae = data_json["MissionName"]:find('_') -- to remove _trigger
    activeEventsLogged[playerServerId][0] = string.sub(data_json["MissionName"],0,ae-1 )
    activeEventsLogged[playerServerId][1] = missionPointB_json["name"] 

    print(activeEventsLogged[playerServerId])
    MP.TriggerClientEvent(playerServerId, 'gotoDelivery',Util.JsonEncode(missionPointB_json))    
end

-- not the best as this algorithm caculates straight line distance from point a to point b
function calculateDistance(x1, y1, z1, x2, y2, z2)
    local dx = x2 - x1
    local dy = y2 - y1
    local dz = z2 - z1
    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
    return distance
end

function giveMoney(jsonLocationA, jsonLocationB )
--  TODO algorithm to caculate
    x1 = jsonLocationA["x"] 
    y1 = jsonLocationA["y"]
    z1 =jsonLocationA["z"]

    x2 = jsonLocationB["x"]
    y2 = jsonLocationB["y"]
    z2 = jsonLocationB["z"]

    dist = calculateDistance(x1, y1, z1, x2, y2, z2)
    print(dist)
-- TODO FIGURE OUT A BETTER FORUMLAR
-- Total Payment=(Base Rate+(Miles Driven×Rate per Mile))×Difficulty Multiplier+Time Bonus+Performance Bonus
    return math.ceil(100 + (dist * 1.2))

end

function verifyPlayerLocation(playerServerId, x, y)
    local vehicleList = MP.GetPlayerVehicles(playerServerId)
    for vehicleID, vehicleData in pairs(vehicleList) do

        print(vehicleData)

        vehPos = MP.GetPositionRaw(playerServerId, vehicleID)["pos"] -- getting position data via this function seems to be more accurate than through the vehicle data 
    
        dist = calculateDistance(vehPos[1], vehPos[2], vehPos[3], x, y, vehPos[3])
        if dist <= 50  then
            return true
        end
    
    -- Could also be used to check how many vehicles a player have
    end
    return false
end

--  data is trigger name
function missionCompleted(playerServerId, data)
    print("missioncompleted " .. data)
    local formId = MP.GetPlayerIdentifiers(playerServerId)["beammp"]
    local player = playerDatabase[formId]
    local i_currentMoney = tonumber(player["money"])

-- this gets mission point infomation from the names  
-- [LUA] [[table: 00000207E1F22EC0]]: {
--        0: [[table: 00000207E1F23A80]]: {
--                1: "SXL",
--                0: "MRW",
--        },
---}
-- 
-- could use hashtable instead?
    print(activeEventsLogged[playerServerId])    

    pointA_json = {}
    pointB_json = {}
    for i=1, #mission_points do
        --doesnt matter which is point a or point b
        if activeEventsLogged[playerServerId][0] == mission_points[i]["name"] then
            pointA_json = mission_points[i]
        elseif activeEventsLogged[playerServerId][1]  == mission_points[i]["name"] then
            print(mission_points[i])
            pointB_json = mission_points[i]
            local bool = verifyPlayerLocation(playerServerId, mission_points[i]["x"], mission_points[i]["y"])
        
            if bool ~= true then
                MP.SendChatMessage(playerServerId, "You were found to not be at the location you said u were" )
                return
            end
        end

    end


    local i_paycheck = tonumber(giveMoney(pointA_json,pointB_json))


    local i_money = i_paycheck + i_currentMoney
    
    player["money"] = tostring(i_money) 

    MP.SendChatMessage(playerServerId, "NOW HERES YOUR MONEY £" ..  tostring(i_money) .. ". You made £" .. i_paycheck)
    savePlayerDatabase()
end

--TODO NEEDS A EAVY REFACTOR
function buyVehicle(player_id, str_formId, data_table )
    print("buyvehicle")
    local playerTable = playerDatabase[str_formId]
    local i_currentMoney = tonumber(playerTable["money"])

    local carname = data_table["jbm"]
    local configFileName = data_table["vcf"]["partConfigFilename"]
    print(carname)
    print(configFileName)

    if(carname == "boxutility") then
        return 0
    end

    -- IF car config not owned thennn
    -- if carname is not in table then of course player doesnt own config 
    -- but if player does own the car and but not the config then he still needs to pay
    if playerTable[carname] == nil or playerTable[carname][configFileName] == nil then
        if carDatabase[carname] ~= nil and carDatabase[carname][configFileName] ~= nil then
            i_cost_of_car =  tonumber(carDatabase[carname][configFileName])
             
            print(i_cost_of_car) 
            -- IF user has more of equal to the amount of car then proceed to buy
            if i_currentMoney >= i_cost_of_car then
                -- TODO what you couldddd do is put this in an variable where playerid -> warned for x car keys to given
                -- then have user write /confirm   when its confirmed the server deduct money and give car to player database
                playerTable["money"] = tostring(i_currentMoney - i_cost_of_car)      
                -- totally new so gotta add it like this
                if playerTable[carname] == nil then
                    playerTable[carname] = {}
                end
                
                -- add the vehicle parts as well as it comesss with the car duh
                for key, value in pairs(data_table.vcf.parts )do 
                    playerTable[carname][value] = true    
                end

                playerTable[carname][configFileName] = true 
                MP.SendChatMessage(player_id, "You bought " .. carname .. " for £" .. i_cost_of_car.. " congrats!!!")
                savePlayerDatabase()
            else
                -- return 1 -- crashes my game
                MP.SendChatMessage(player_id, "You do not own this vehicle! And you cannot afford to buy it : vehicle cost:" .. i_cost_of_car)
            end
        else
            MP.SendChatMessage(player_id, "Couldnt seem to find this car or config? Report this issue")
            return 1
        end
    end

end

-- TODO
-- ./vehicle/partCondition.lua
-- caculates % of damage the car has. then uses that amount to caculate how much player needs to pay
function caculateVehicleDamageAmount(vehicle_id, data)
    return 200 
end -- need to name this function better

-- NEEDS REFACTOR
-- not cancelable
--
-- The data here seems to only be rot and pos
function onVehicleReset(player_id, vehicle_id, data)
    print("onVehicleReset  ")

    local str_formId = MP.GetPlayerIdentifiers(player_id)["beammp"]
    local playerTable = playerDatabase[str_formId]
    local i_currentMoney = tonumber(playerTable["money"])
  
    -- getActiveVehicle(player_id)
    -- IF car config not owned thennn
    -- if carname is not in table then of course player doesnt own config 
    -- but if player does own the car and but not the config then he still needs to pay
    --buyVehicle(player_id, str_formId, data_table )
--    if playerTable[carname] == nil or playerTable[carname][configFileName] == nil then
--        if buyVehicle(player_id, str_formId, data_table) == 1 then
            -- retur1
--        end
        -- could do return buyvehicle but canceling actions seem to crash my beam  
--        return 0
--    end


    local i_repairCost = tonumber(caculateVehicleDamageAmount(1,1))
    playerTable["money"] = tostring(i_currentMoney -   i_repairCost)
    MP.SendChatMessage(player_id, "Repair cost" .. tostring(i_repairCost).." Current Money: £" ..  tostring(playerTable["money"]))
    savePlayerDatabase()
end

function userBoughtCarPart(s_carPartName, s_carName, str_formId , player_id)
    local playerTable = playerDatabase[str_formId]
    local i_currentMoney = tonumber(playerTable["money"])

    if carpartsDatabase[s_carPartName] == nil then
        MP.SendChatMessage(player_id, "This part has not been registered on the server. Please report to admin to fix " .. s_carPartName)
        return 1
    end

    if playerTable[s_carName][s_carPartName] == nil then
        -- TODO should put this mess in another function as too many indentationss
        if i_currentMoney < 0 then
            MP.SendChatMessage(player_id, "You cannot buy " .. tostring(value) .. " as you are in debt!!!!")
            return 1
        else
            -- get the cost of this via the json file
            print(s_carPartName)
            print(s_carName)
            i_cost_of_part = tonumber(carpartsDatabase[s_carPartName])
           -- cost_of_part = 650   -- TODO CAR PART NEEDS TO BE RETRIEVED FROM JSON 

            if i_currentMoney >= i_cost_of_part then
                -- buy and give to player database
                playerTable["money"] = tostring(i_currentMoney - i_cost_of_part)      
                playerTable[s_carName][s_carPartName] = true    
                MP.SendChatMessage(player_id, "You just bought " .. s_carPartName.. " for £" .. i_cost_of_part)
                savePlayerDatabase()
            else
                MP.SendChatMessage(player_id, "You cannot afford " .. s_carPartName.. " for £" .. i_cost_of_part)
                return 1
            end
        end

    end
    return 0
end

-- can be canceled
function onVehicleEdited(player_id, vehicle_id, data)
    print("onVehicleEdited")
    local dp = data:find('%{')
    local data = data:sub(dp) -- "The data argument contains the car's config as json" i guess this will be fixed someday
    local data_table = Util.JsonDecode(data)
    local str_formId = MP.GetPlayerIdentifiers(player_id)["beammp"]
    local player = playerDatabase[str_formId]
    
    local carname = data_table["jbm"]
    --TODO able to see what changed easily?
      -- get the parts thats installed
    if player[tostring(carname)] ~= nil then -- owns the car
        for key, value in pairs(data_table.vcf.parts )do 
            if value ~= "" then
                if userBoughtCarPart(value, carname, str_formId , player_id) == 1 then
                    return 1
                end
            end
        end
    else
        MP.SendChatMessage(player_id, "You do not own this vehicle! You will get kicked out of this vehicle soon. (cant kick him on onVehicleEdited)")
        return 1
    end
end

  --  playerDatabase[str_formId][carname] = partsinstalled
-- can be canceled
function onVehicleSpawn(player_id, vehicle_id, data)
    print("onVehicleSpawn" )
    local dp = data:find('%{')
    local data = data:sub(dp) -- "The data argument contains the car's config as json" i guess this will be fixed someday
    local data_table = Util.JsonDecode(data)
    local str_formId = MP.GetPlayerIdentifiers(player_id)["beammp"]
    
    print(data_table)


    if buyVehicle(player_id, str_formId, data_table) == 1 then
-- supposed to return 1 but seems to crash my game
-- TODO
    end


    return 0  
end

-- TODO need to include vehicle parts installed, color and such....
function spawnLastLocation(player_id)
    print(player_id .. "spawnAtLocation")

    local str_formId = MP.GetPlayerIdentifiers(player_id)["beammp"]
    local playerTable = playerDatabase[str_formId]
        
    if playerTable == nil then
        return 0
    end
    
    local lastlocationData = playerTable["lastLocation"]

    local send = { x=lastlocationData["x"], y=lastlocationData["y"],z=lastlocationData["z"] }
    MP.TriggerClientEvent(player_id, 'spawnAtLocation',Util.JsonEncode(send))
end


function handlePlayerAuth(player_name, player_role, is_guest,  identifiers)
    if is_guest then
        return 'Sorry, no guests allowed on this server'
    end

    -- CANNOT allow guests due to them not being assigned beammp form id which makes sense.
    local player = nil
    local id = identifiers["beammp"]

    if playerDatabase ~= nil then
        player = playerDatabase[id]
    else
        playerDatabase = {}
    end
    -- if found find player. still gotta update ip
    if player ~= nil then
        if  player["ip"] ~= identifiers["ip"] then -- if its a new ip
            player["ip"] = identifiers["ip"] -- TODO should save old ips as well? mabye in array but gotta check if its already been added or not
        end
    else --- didnt find player
        local new_player = {
            ip = identifiers["ip"],
            money = "5000",
            lastLocation = {x = -1777.63, y = -96.48, z = 152.6, vehicle="autobello"},
        }
        print("new player ") 
        playerDatabase[id] = new_player
    end
    savePlayerDatabase()
end

function onPlayerDisconnect(player_id)
    local str_formId = MP.GetPlayerIdentifiers(player_id)["beammp"]
    local player = playerDatabase[str_formId]

    -- should rly put this block in its own function
    local vehPos =nil
    local carName  = "autobello" -- default
    local carParts = ""

    local vehicleList = MP.GetPlayerVehicles(player_id)
    for vehicleID, vehicleData in pairs(vehicleList) do
        local dp = vehicleData:find('%{')
        local data = vehicleData:sub(dp) -- "The data argument contains the car's config as json" i guess this will be fixed someday
        local data_table = Util.JsonDecode(data)
            
        carName = data_table["jbm"]
        carparts = data_table["vcf"]
        print(data_table)
        print(carparts)
        

        vehPos = MP.GetPositionRaw(player_id, vehicleID)["pos"] -- getting position data via this function seems to be more accurate than through the vehicle data 
    end

    if vehPos == nil then
        print("VEH POS IS NIL!") 
    else
        player["lastLocation"] = {x = vehPos[1], y = vehPos[2], z = vehPos[3], jbm=carName, vcf=carparts}
        print(player["lastLocation"])
        print("disconncetbg")
    end
    activeEventsLogged[player_id] = nil -- so shit doesnt get muddled up with someone else
    savePlayerDatabase()
end
function onShutdown()
    print("SAVING DATABASE BEFORE SHUTGTONGDOWN") 
    savePlayerDatabase()
end

function playerFullyLoaded(player_id)

    print(player_id.." Fully loadeded!!")
    spawnLastLocation(player_id)
end

function onInit()
    MP.RegisterEvent('onPlayerAuth', 'handlePlayerAuth')
    MP.RegisterEvent('onPlayerDisconnect', 'onPlayerDisconnect')
    MP.RegisterEvent("onPlayerJoin", "onPlayerJoin")
    MP.RegisterEvent("startMission","sstartMission")
    MP.RegisterEvent("onVehicleReset","onVehicleReset")
    MP.RegisterEvent("onVehicleEdited","onVehicleEdited")
    MP.RegisterEvent("onVehicleSpawn","onVehicleSpawn")
    MP.RegisterEvent("triggerMissionCompleted","missionCompleted")
    MP.RegisterEvent("playerFullyLoaded","playerFullyLoaded")
end



return M
