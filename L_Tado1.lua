local TADO_DEBUG = 1

local TADO_DEFAULT_ON_MODE = "COOL"
local TADO_DEFAULT_ON_CELSIUS = "21.00"
local TADO_DEFAULT_ON_FAHRENHEIT = "70.00"
local TADO_DEFAULT_ON_FANSPEED = "AUTO"

local TADO_SCALE = "C"
local HOME_LIST = { }
local ZONE_LIST = { }
local TADO_MYHOMES = { }

local TADO_HOMENAME = ""

local CONN_SID = "urn:fr87-com:serviceId:Tado1"
local CONN_DEVICE = "urn:schemas-fr87-com:device:Tado:1"
local HOME_SID = "urn:fr87-com:serviceId:TadoHome1"
local HOME_DEVICE = "urn:schemas-fr87-com:device:TadoHome:1"
local AC_SID = "urn:fr87-com:serviceId:TadoAC1"
local AC_DEVICE = "urn:schemas-fr87-com:device:TadoAC:1"
local HEAT_SID = "urn:fr87-com:serviceId:TadoHeat1"
local HEAT_DEVICE = "urn:schemas-fr87-com:device:TadoHeat:1"
local HW_SID = "urn:fr87-com:serviceId:TadoHW1"
local HW_DEVICE = "urn:schemas-fr87-com:device:TadoHW:1"

local ZONETHERM_SID = "urn:schemas-upnp-org:serviceId:HVAC_ZoneThermostat1"
local ZONETHERM_DEVICE = "urn:schemas-upnp-org:device:HVAC_ZoneThermostat:1"

local HVAC_SID = "urn:upnp-org:serviceId:HVAC_UserOperatingMode1"
local HVAC_DEVICE = "urn:upnp-org:device:HVAC_UserOperatingMode:1"

local HVAC_FAN_SID = "urn:upnp-org:serviceId:HVAC_FanOperatingMode1"
local HVAC_FAN_DEVICE = "urn:upnp-org:device:HVAC_FanOperatingMode:1"

local FANSPEED_SID = "urn:upnp-org:serviceId:FanSpeed1"
local FANSPEED_DEVICE = "urn:upnp-org:device:FanSpeed:1"

local SETPOINT_SID = "urn:upnp-org:serviceId:TemperatureSetpoint1"    
local SETPOINT_HEAT_SID = "urn:upnp-org:serviceId:TemperatureSetpoint1_Heat"
local SETPOINT_COOL_SID = "urn:upnp-org:serviceId:TemperatureSetpoint1_Cool"


local TEMPSENSOR_SID = "urn:upnp-org:serviceId:TemperatureSensor1"


local child_devices = luup.chdev.start(lul_device)


function Tado_Debug(tado_log_msg)
    if (TADO_DEBUG == 1) then
        luup.log("Tado (" .. tostring(TADO_HOMENAME) .. "): " .. tado_log_msg)
    end
end


function Tado_readVariableOrInit(lul_device, serviceId, name, defaultValue)
    --Tado_Debug("In Tado_readVariableOrInit. Entered with parameters: " .. lul_device or "" .. ", " .. serviceId or "" .. ", " .. name or "" .. ", " .. defaultValue or "")
    local var = luup.variable_get(serviceId, name, lul_device)
    if (var == nil) then
        Tado_Debug("In Tado_readVariableOrInit. Var was equal to nil")
        var = defaultValue
        luup.variable_set(serviceId, name, var, lul_device)
    end
    return var
end


function Tado_readSettings()
    local data = {}

    -- Config variables
    data.username = Tado_readVariableOrInit(lul_device, CONN_SID, "username", "" )
    data.password = Tado_readVariableOrInit(lul_device, CONN_SID, "password", "" )

    -- Internal variables

    return data
end


function Tado_SetHomeVariable(tado_homeid, var_name, value)
    Tado_Debug("In SetHomeVariable")

    for k, v in pairs (HOME_LIST) do
        Tado_Debug("In SetHomeVariable loop. k is: " .. k .. " comparing it to: " .. tado_homeid)
        if (tonumber(k) == tonumber(tado_homeid)) then
            Tado_Debug("Got a match, updating variable for device ID: " .. v .. " with variable: " .. var_name .. " and value: " .. tostring(value))
            luup.variable_set(HOME_SID, var_name, value or "", v)
        end
    end
end


function Tado_RefreshHomes(tado_homeid)
    local data = Tado_readSettings()

    Tado_Debug("Getting Home detail for home: " .. tado_homeid)

    local curlCommand = 'curl -k -L "https://my.tado.com/api/v2/homes/' .. tado_homeid .. '?username=' .. data.username .. '&password=' .. url.escape(data.password) .. '"'
    local stdout = io.popen(curlCommand)
    local tado_home = stdout:read("*a")
    stdout:close()

    local obj, pos, err = tado_json.decode (tado_home, 1, nil)

    if (obj.errors) then
        for i = 1,#obj.errors do
            Tado_Debug("Error: " .. obj.errors[i].title .. " - " .. obj.errors[i].code)
        end
        return 2
    end

    Tado_SetHomeVariable(tado_homeid, "name", obj.name)
    Tado_SetHomeVariable(tado_homeid, "dateTimeZone", obj.dateTimeZone)
    Tado_SetHomeVariable(tado_homeid, "temperatureUnit", obj.temperatureUnit)
    Tado_SetHomeVariable(tado_homeid, "installationCompleted", obj.installationCompleted)
    Tado_SetHomeVariable(tado_homeid, "partner", obj.partner)
    Tado_SetHomeVariable(tado_homeid, "simpleSmartScheduleEnabled", obj.simpleSmartScheduleEnabled)

    if (obj.contactDetails) then
        Tado_SetHomeVariable(tado_homeid, "contactDetailsname", obj.contactDetails.name)
        Tado_SetHomeVariable(tado_homeid, "contactDetailsemail", obj.contactDetails.email)
        Tado_SetHomeVariable(tado_homeid, "contactDetailsphone", obj.contactDetails.phone)
    end

    if (obj.address) then
        Tado_SetHomeVariable(tado_homeid, "addressLine1", obj.address.addressLine1)
        Tado_SetHomeVariable(tado_homeid, "addressLine2", obj.address.addressLine2)
        Tado_SetHomeVariable(tado_homeid, "zipCode", obj.address.zipCode)
        Tado_SetHomeVariable(tado_homeid, "city", obj.address.city)
        Tado_SetHomeVariable(tado_homeid, "state", obj.address.state)
        Tado_SetHomeVariable(tado_homeid, "country", obj.address.country)
    end

    if (obj.geolocation) then
        Tado_SetHomeVariable(tado_homeid, "geolocationlatitude", obj.geolocation.latitude)
        Tado_SetHomeVariable(tado_homeid, "geolocationlongitude", obj.geolocation.longitude)
    end
end


function Tado_RefreshWeather(tado_homeid)    
    local data = Tado_readSettings()

    Tado_Debug("Getting Weather for home: " .. tado_homeid)

    local curlCommand = 'curl -k -L "https://my.tado.com/api/v2/homes/' .. tado_homeid .. '/weather?username=' .. data.username .. '&password=' .. url.escape(data.password) .. '"'
    local stdout = io.popen(curlCommand)
    local tado_weather = stdout:read("*a")
    stdout:close()

    local obj, pos, err = tado_json.decode (tado_weather, 1, nil)

    -- Need to call this here in case we have an error, otherwise our function will not run again in 15 minutes.
    luup.call_delay("Tado_RefreshWeather", 901, tado_homeid)

    if (obj.errors) then
        for i = 1,#obj.errors do
            Tado_Debug("Error: " .. obj.errors[i].title .. " - " .. obj.errors[i].code)
        end
        return 2
    end

    if (obj.solarIntensity) then
        Tado_SetHomeVariable(tado_homeid, "solarIntensitytype", obj.solarIntensity.type)
        Tado_SetHomeVariable(tado_homeid, "solarIntensitypercentage", obj.solarIntensity.percentage)
        Tado_SetHomeVariable(tado_homeid, "solarIntensitytimestamp", obj.solarIntensity.timestamp)
    end

    if (obj.outsideTemperature) then
        Tado_SetHomeVariable(tado_homeid, "outsideTemperaturecelsius", obj.outsideTemperature.celsius)
        Tado_SetHomeVariable(tado_homeid, "outsideTemperaturefahrenheit", obj.outsideTemperature.fahrenheit)
        Tado_SetHomeVariable(tado_homeid, "outsideTemperaturetimestamp", obj.outsideTemperature.timestamp)
        Tado_SetHomeVariable(tado_homeid, "outsideTemperaturetype", obj.outsideTemperature.type)
        Tado_SetHomeVariable(tado_homeid, "outsideTemperatureprecisioncelsius", obj.outsideTemperature.precision.celsius)
        Tado_SetHomeVariable(tado_homeid, "outsideTemperatureprecisionfahrenheit", obj.outsideTemperature.precision.fahrenheit)
    end

    if (obj.weatherState) then
        Tado_SetHomeVariable(tado_homeid, "weatherStatetype", obj.weatherState.type)
        Tado_SetHomeVariable(tado_homeid, "weatherStatevalue", obj.weatherState.value)
        Tado_SetHomeVariable(tado_homeid, "weatherStatetimestamp", obj.weatherState.timestamp)
    end
end


function Tado_RefreshAllZones()
    Tado_Debug("Refreshing All Zones")
    for k, v in pairs (ZONE_LIST) do
        local tado_homeid, tado_zoneid = k:match("([^,]+)_([^,]+)")

        -- Our list contains all Tado devices, so lets see if this HomeID belongs to our instance of this plugin
        if (TADO_MYHOMES[tado_homeid] == 1) then
            -- It does so lets refresh this ZoneID
            Tado_RefreshZone(tado_homeid, tado_zoneid, v)
        else
            Tado_Debug("Skipping HomeID " .. tado_homeid .. " because its not in our MYHOMES list")
        end
    end

    -- Lets schedule this refresh to run again in 1 minutes time
    luup.call_delay("Tado_RefreshAllZones", 61)
end


function Tado_RefreshZone(tado_homeid, tado_zoneid, tado_deviceid)
    local data = Tado_readSettings()

    Tado_Debug("Refreshing Zone state for homeid: " .. tado_homeid .. " and zoneid: " .. tado_zoneid)

    local curlCommand = 'curl -k -L "https://my.tado.com/api/v2/homes/' .. tado_homeid .. '/zones/' .. tado_zoneid .. '/state?username=' .. data.username .. '&password=' .. url.escape(data.password) .. '"'
    local stdout = io.popen(curlCommand)
    local tado_zonestate = stdout:read("*a")
    stdout:close()

    local obj, pos, err = tado_json.decode (tado_zonestate, 1, nil)

    if (obj.errors) then
        for i = 1,#obj.errors do
            Tado_Debug("Error: " .. obj.errors[i].title .. " - " .. obj.errors[i].code)
        end
        return 2
    end

    -- Always good to have HomeID and ZoneID as a variable for easy access in the future
    luup.variable_set(AC_SID, "TadoHomeID", tado_homeid or "", tado_deviceid)
    luup.variable_set(AC_SID, "TadoZoneID", tado_zoneid or "", tado_deviceid)

    -- Save all the data to variables on our child (for future use etc)
    luup.variable_set(AC_SID, "tadoMode", obj.tadoMode or "", tado_deviceid)
    luup.variable_set(AC_SID, "geolocationOverride", obj.geolocationOverride or "", tado_deviceid)
    luup.variable_set(AC_SID, "geolocationOverrideDisableTime", obj.geolocationOverrideDisableTime or "", tado_deviceid)
    luup.variable_set(AC_SID, "preparation", obj.preparation or "", tado_deviceid)
    luup.variable_set(AC_SID, "settingtype", obj.setting.type or "", tado_deviceid)
    luup.variable_set(AC_SID, "settingpower", obj.setting.power or "", tado_deviceid)
    luup.variable_set(AC_SID, "settingmode", obj.setting.mode or "", tado_deviceid)

    local current_setpoint = "Off"
    if (obj.setting.temperature) then
        luup.variable_set(AC_SID, "settingtemperaturecelsius", obj.setting.temperature.celsius or "", tado_deviceid)
        luup.variable_set(AC_SID, "settingtemperaturefahrenheit", obj.setting.temperature.fahrenheit or "", tado_deviceid)

        if (TADO_SCALE == "C") then
            current_setpoint = obj.setting.temperature.celsius
        elseif (TADO_SCALE == "F") then
            current_setpoint = obj.setting.temperature.fahrenheit
        end
    end

    luup.variable_set(SETPOINT_SID, "CurrentSetpoint", current_setpoint or "", tado_deviceid)
    luup.variable_set(SETPOINT_HEAT_SID, "CurrentSetpoint", current_setpoint or "", tado_deviceid)
    luup.variable_set(SETPOINT_COOL_SID, "CurrentSetpoint", current_setpoint or "", tado_deviceid)

    luup.variable_set(AC_SID, "settingfanSpeed", obj.setting.fanSpeed or "", tado_deviceid)

    luup.variable_set(AC_SID, "overlayType", obj.overlayType or "", tado_deviceid)

    if (obj.overlayType == "MANUAL") then
        luup.variable_set(HVAC_SID, "EnergyModeStatus", "Normal", tado_deviceid)
    else
        luup.variable_set(HVAC_SID, "EnergyModeStatus", "EnergySavingsMode", tado_deviceid)
    end

    if (obj.overlay) then
        luup.variable_set(AC_SID, "overlaytype", obj.overlay.type or "", tado_deviceid)

        if (obj.overlay.termination) then
            luup.variable_set(AC_SID, "overlayterminationtype", obj.overlay.termination.type or "", tado_deviceid)
            luup.variable_set(AC_SID, "overlayterminationprojectedExpiry", obj.overlay.termination.projectedExpiry or "", tado_deviceid)
        end

        if (obj.overlay.setting) then
            luup.variable_set(AC_SID, "overlaysettingtype", obj.overlay.setting.type or "", tado_deviceid)
            luup.variable_set(AC_SID, "overlaysettingpower", obj.overlay.setting.power or "", tado_deviceid)
            luup.variable_set(AC_SID, "overlaysettingmode", obj.overlay.setting.mode or "", tado_deviceid)
            luup.variable_set(AC_SID, "overlaysettingfanSpeed", obj.overlay.setting.fanSpeed or "", tado_deviceid)

            if (obj.overlay.setting.temperature) then
                luup.variable_set(AC_SID, "overlaysettingtemperaturecelsius", obj.overlay.setting.temperature.celsius or "", tado_deviceid)
                luup.variable_set(AC_SID, "overlaysettingtemperaturefahrenheit", obj.overlay.setting.temperature.fahrenheit or "", tado_deviceid)
            end
        end
    end

    luup.variable_set(AC_SID, "openWindow", obj.tadoMode or "", tado_deviceid)
    luup.variable_set(AC_SID, "linkstate", obj.link.state or "", tado_deviceid)
    luup.variable_set(AC_SID, "sensorDataPointsinsideTemperaturecelsius", obj.sensorDataPoints.insideTemperature.celsius or "", tado_deviceid)
    luup.variable_set(AC_SID, "sensorDataPointsinsideTemperaturefahrenheit", obj.sensorDataPoints.insideTemperature.fahrenheit or "", tado_deviceid)
    luup.variable_set(AC_SID, "sensorDataPointsinsideTemperaturetimestamp", obj.sensorDataPoints.insideTemperature.timestamp or "", tado_deviceid)
    luup.variable_set(AC_SID, "sensorDataPointsinsideTemperaturetype", obj.sensorDataPoints.insideTemperature.type or "", tado_deviceid)
    luup.variable_set(AC_SID, "sensorDataPointsinsideTemperatureprecisioncelsius", obj.sensorDataPoints.insideTemperature.precision.celsius or "", tado_deviceid)
    luup.variable_set(AC_SID, "sensorDataPointsinsideTemperatureprecisionfahrenheit", obj.sensorDataPoints.insideTemperature.fahrenheit or "", tado_deviceid)
    luup.variable_set(AC_SID, "sensorDataPointshumiditytype", obj.sensorDataPoints.humidity.type or "", tado_deviceid)
    luup.variable_set(AC_SID, "sensorDataPointshumiditypercentage", obj.sensorDataPoints.humidity.percentage or "", tado_deviceid)
    luup.variable_set(AC_SID, "sensorDataPointshumiditytimestamp", obj.sensorDataPoints.humidity.timestamp or "", tado_deviceid)

    -- Convert our data to upnp standards (HVAC Mode)
    local tado_oper_mode = "Unknown"
    if (obj.setting.mode == "COOL") then
        tado_oper_mode = "CoolOn"
    elseif (obj.setting.mode == "HEAT") then
        tado_oper_mode = "HeatOn"
    elseif (obj.setting.mode == "AUTO") then
        tado_oper_mode = "AutoChangeOver"
    elseif (obj.setting.power == "OFF") then
        tado_oper_mode = "Off"
    end

    luup.variable_set(HVAC_SID, "ModeStatus", tado_oper_mode or "", tado_deviceid)

    if (TADO_SCALE == "C") then
        luup.variable_set(TEMPSENSOR_SID, "CurrentTemperature", obj.sensorDataPoints.insideTemperature.celsius or "", tado_deviceid)
    elseif (TADO_SCALE == "F") then
        luup.variable_set(TEMPSENSOR_SID, "CurrentTemperature", obj.sensorDataPoints.insideTemperature.fahrenheit or "", tado_deviceid)
    end

    -- Convert our data to upnp standards (Fan)
    local tado_fan_mode = "PeriodicOn"
    local tado_fan_speed = 0
    if (not obj.setting.fanSpeed) then
        tado_fan_mode = "PeriodicOn"
    elseif (obj.setting.fanSpeed == "AUTO") then
        tado_fan_mode = "Auto"
    elseif (obj.setting.fanSpeed == "LOW") then
        tado_fan_mode = "ContinuousOn"
        tado_fan_speed = "0"
    elseif (obj.setting.fanSpeed == "MIDDLE") then
        tado_fan_mode = "ContinuousOn"
        tado_fan_speed = "50"
    elseif (obj.setting.fanSpeed == "HIGH") then
        tado_fan_mode = "ContinuousOn"
        tado_fan_speed = "100"
    end
    luup.variable_set(HVAC_FAN_SID, "Mode", tado_fan_mode or "", tado_deviceid)

    luup.variable_set(FANSPEED_SID, "FanSpeedTarget", tado_fan_mode or "", tado_deviceid)
    luup.variable_set(FANSPEED_SID, "FanSpeedStatus", tado_fan_mode or "", tado_deviceid)

end


function Tado_HomeListRefresh()
    Tado_Debug("In Home List Refresh")
    HOME_LIST = { }
    for k, v in pairs(luup.devices) do
        if (v.id:find("^TadoHome(.+)$")) then
            Tado_Debug("Found a home with ID: " .. string.gsub(v.id, "TadoHome", "", 1))
            HOME_LIST[string.gsub(v.id, "TadoHome", "")] = k
        end
    end
end


function Tado_ZoneListRefresh()
    Tado_Debug("In Zone List Refresh")
    ZONE_LIST = { }
        for k, v in pairs(luup.devices) do
        if (v.id:find("^TadoZone(.+)$")) then
            Tado_Debug("Found a Zone with ID: " .. string.gsub(v.id, "TadoZone", "", 1))
            ZONE_LIST[string.gsub(v.id, "TadoZone", "")] = k
        end
    end
end


function Tado_CreateZones(tado_homeid)
    local data = Tado_readSettings()

    Tado_Debug("Getting Zones for homeid: " .. tado_homeid)

    local curlCommand = 'curl -k -L "https://my.tado.com/api/v2/homes/' .. tado_homeid .. '/zones?username=' .. data.username .. '&password=' .. url.escape(data.password) .. '"'
    local stdout = io.popen(curlCommand)
    local tado_zones = stdout:read("*a")
    stdout:close()

    local obj, pos, err = tado_json.decode (tado_zones, 1, nil)

    if (obj.errors) then
        for i = 1,#obj.errors do
            Tado_Debug("Error: " .. obj.errors[i].title .. " - " .. obj.errors[i].code)
        end
        return 2
    end

    for i = 1,#obj do

        Tado_Debug("About to apepend child for homeid: " .. tado_homeid .. ", Child is zoneid: " .. tostring(obj[i].id) .. ", name: " .. obj[i].name)

        if (obj[i].type == "AIR_CONDITIONING") then
            tado_xml_file = "D_TadoAC1.xml"
        elseif (obj[i].type == "HEATING") then
            tado_xml_file = "D_TadoHeat1.xml"
        end

        luup.chdev.append(lul_device, child_devices, "TadoZone" .. tado_homeid .. "_" .. tostring(obj[i].id), obj[i].name, ZONETHERM_DEVICE, tado_xml_file, "", ",SID=" .. ZONETHERM_SID, false)

        Tado_Debug("Finished appending children for homeid: " .. tado_homeid)

    end
end


function Tado_CreateChildren()
    local data = Tado_readSettings()

    Tado_Debug("Retrieving all homes on account")

    local curlCommand = 'curl -k -L "https://my.tado.com/api/v2/me?username=' .. data.username .. '&password=' .. url.escape(data.password) .. '"'
    local homes = ""
    local stdout = io.popen(curlCommand)
    local tado_home = stdout:read("*a")
    stdout:close()

    local obj, pos, err = tado_json.decode (tado_home, 1, nil)

    if (obj.errors) then
        for i = 1,#obj.errors do
            Tado_Debug("Error: " .. obj.errors[i].title .. " - " .. obj.errors[i].code)
        end
        return 2
    end

    TADO_HOMENAME = obj.name

    luup.variable_set(CONN_SID, "name", obj.name or "", lul_device)
    luup.variable_set(CONN_SID, "email", obj.email or "", lul_device)
    luup.variable_set(CONN_SID, "locale", obj.locale or "", lul_device)

    for i = 1,#obj.homes do
        Tado_Debug("Appending homeid: " .. tostring(obj.homes[i].id) .. ", with name: " .. obj.homes[i].name)
        luup.chdev.append(lul_device, child_devices, "TadoHome" .. tostring(obj.homes[i].id), obj.homes[i].name, HOME_DEVICE, "D_TadoHome1.xml", "", "", false)

        -- Lets add it to our array so we can later know if this home belongs to this instance of the plugin (in case multiple accounts are used)
        TADO_MYHOMES[tostring(obj.homes[i].id)] = 1
    end

    Tado_Debug("Finished appending homes")

    for i = 1,#obj.homes do
        if (Tado_CreateZones(obj.homes[i].id) == 2) then
            return 2
        end
    end

    Tado_Debug("Finished appending all Zones")

    luup.chdev.sync(lul_device, child_devices)

    Tado_HomeListRefresh()
    Tado_ZoneListRefresh()

    for i = 1,#obj.homes do
        Tado_RefreshHomes(obj.homes[i].id)
        Tado_RefreshWeather(obj.homes[i].id)
    end

    Tado_RefreshAllZones()
end


function Tado_setOverley(bool_status, lul_device)
    local data = Tado_readSettings()

    local curlCommand = ""

    if (bool_status == 1) then
        local json_output = ""
        
        -- Retrieve current values first
        local ModeStatus = luup.variable_get(HVAC_SID, "ModeStatus", lul_device)
        local FanMode = luup.variable_get(HVAC_FAN_SID, "Mode", lul_device)
        local CurrentSetPoint = luup.variable_get(SETPOINT_SID, "CurrentSetpoint", lul_device)

        -- Set the mode to our default first and then convert UPNP values to Tado values
        local tado_fan_mode = TADO_DEFAULT_ON_FANSPEED
        if (FanMode == "PeriodicOn") then
            tado_fan_mode = "LOW"
        elseif (FanMode == "ContinuousOn") then
            tado_fan_mode = "HIGH"
        elseif (FanMode == "Auto") then
            tado_fan_mode = "AUTO"
        end

        -- Do the same for the mode
        local tado_oper_mode = TADO_DEFAULT_ON_MODE
        if (ModeStatus == "Off") then
            tado_oper_mode = "OFF"
        elseif (ModeStatus == "CoolOn") then
            tado_oper_mode = "COOL"
        elseif (ModeStatus == "HeatOn") then
            tado_oper_mode = "HEAT"
        elseif (ModeStatus == "AutoChangeOver") then
            tado_oper_mode = "AUTO"
        end

        -- Now lets find out min and max values that are valid. If they dont exists (for thermostats) then use the hard coded values
        local temp_min, temp_max
        if (TADO_SCALE == "C" and tado_oper_mode == "COOL") then
            temp_min = luup.variable_get(AC_SID, "TadoCoolMinCelcius", lul_device) or "5"
            temp_max = luup.variable_get(AC_SID, "TadoCoolMaxCelcius", lul_device) or "25"
        elseif (TADO_SCALE == "F" and tado_oper_mode == "COOL") then
            temp_min = luup.variable_get(AC_SID, "TadoCoolMinFahrenheit", lul_device) or "41"
            temp_max = luup.variable_get(AC_SID, "TadoCoolMaxFahrenheit", lul_device) or "77"
        elseif (TADO_SCALE == "C" and tado_oper_mode == "HEAT") then
            temp_min = luup.variable_get(AC_SID, "TadoHeatMinCelcius", lul_device) or "5"
            temp_max = luup.variable_get(AC_SID, "TadoHeatMaxCelcius", lul_device) or "25"
        elseif (TADO_SCALE == "F" and tado_oper_mode == "HEAT") then
            temp_min = luup.variable_get(AC_SID, "TadoHeatMinFahrenheit", lul_device) or "41"
            temp_max = luup.variable_get(AC_SID, "TadoHeatMaxFahrenheit", lul_device) or "77"
        end

        
        -- If the requested value is outside the valid range then set it to the closest valid value
        local tado_temperature
        if ( TADO_SCALE == "C" and (tado_oper_mode == "HEAT" or tado_oper_mode == "COOL") ) then
            tado_temperature = '"celsius": ' .. TADO_DEFAULT_ON_CELSIUS
            if (tonumber(CurrentSetPoint)) then
                if (tonumber(CurrentSetPoint) > tonumber(temp_max)) then
                    tado_temperature = '"celsius": ' .. temp_max
                elseif (tonumber(CurrentSetPoint) < tonumber(temp_min)) then
                    tado_temperature = '"celsius": ' .. temp_min
                else
                    tado_temperature = '"celsius": ' .. CurrentSetPoint                                                                  
                end
            end
        elseif ( TADO_SCALE == "F" and (tado_oper_mode == "HEAT" or tado_oper_mode == "COOL") ) then
            tado_temperature = '"fahrenheit": ' .. TADO_DEFAULT_ON_FAHRENHEIT
            if (tonumber(CurrentSetPoint)) then
                if (tonumber(CurrentSetPoint) > tonumber(temp_max)) then
                    tado_temperature = '"fahrenheit": ' .. temp_max
                elseif (tonumber(CurrentSetPoint) < tonumber(temp_min)) then
                    tado_temperature = '"fahrenheit": ' .. temp_min
                else
                    tado_temperature = '"fahrenheit": ' .. CurrentSetPoint                                                                  
                end
            end
        end
        
        
        if (ModeStatus == "Off") then
            -- Off is the same for AC's and Heating
            json_output_part1 = ',"power":"OFF"}}'
        elseif (luup.variable_get(AC_SID, "settingtype", lul_device) == "AIR_CONDITIONING" and ModeStatus == "AutoChangeOver") then
            -- Auto mode does for some reason not take a temperature. Not sure what it actually does
            json_output_part1 = ',"power":"ON","mode":"AUTO"}}'
        elseif (luup.variable_get(AC_SID, "settingtype", lul_device) == "AIR_CONDITIONING" and ModeStatus == "CoolOn") then
            -- Cool mode only exists on the ACs
            json_output_part1 = ',"power":"ON","mode":"COOL","temperature":{' .. tado_temperature .. '},"fanSpeed":"' .. tado_fan_mode .. '"}}'
        elseif (luup.variable_get(AC_SID, "settingtype", lul_device) == "AIR_CONDITIONING" and ModeStatus == "HeatOn") then
            -- Heating exists on both ACs and Heating, but uses a different formatting for each type
            json_output_part1 = ',"power":"ON","mode":"HEAT","temperature":{' .. tado_temperature .. '},"fanSpeed":"' .. tado_fan_mode .. '"}}'
        elseif (luup.variable_get(AC_SID, "settingtype", lul_device) == "HEATING" and ModeStatus == "HeatOn") then
            -- Slight difference here for the Heating systems
            json_output_part1 = ',"power":"ON","temperature":{' .. tado_temperature .. '}}}'
        else
            Tado_Debug("Invalid setting combination. Ignoring request")
            return 1
        end
        

        -- Lets construct our final json statement        
        json_output = '{"type":"MANUAL","setting":{"type":"' .. luup.variable_get(AC_SID, "settingtype", lul_device) .. '"' .. json_output_part1
        
        curlCommand = 'curl -k -L -X PUT "https://my.tado.com/api/v2/homes/' .. luup.variable_get(AC_SID, "TadoHomeID", lul_device) .. '/zones/' .. luup.variable_get(AC_SID, "TadoZoneID", lul_device) .. '/overlay?username=' .. data.username .. '&password=' .. url.escape(data.password) .. '" --data-binary \'' .. json_output .. '\''

        luup.variable_set(HVAC_SID, "EnergyModeStatus", "Normal", lul_device)

    elseif (bool_status == 0) then
         curlCommand = 'curl -k -L -X DELETE "https://my.tado.com/api/v2/homes/' .. luup.variable_get(AC_SID, "TadoHomeID", lul_device) .. '/zones/' .. luup.variable_get(AC_SID, "TadoZoneID", lul_device) .. '/overlay?username=' .. data.username .. '&password=' .. url.escape(data.password) .. '"'

        luup.variable_set(HVAC_SID, "EnergyModeStatus", "EnergySavingsMode", lul_device)
    end

    Tado_Debug("curlCommand sent: " .. curlCommand)

    local stdout = io.popen(curlCommand)
    local curl_output = stdout:read("*a")
    stdout:close()

    local obj, pos, err = tado_json.decode (curl_output, 1, nil)

end

function Tado_setModeTarget(lul_device, NewModeTarget)
    local data = Tado_readSettings()

    Tado_Debug("In setModeTarget, been requested to set mode: " .. NewModeTarget)

    if (NewModeTarget == "Off" or NewModeTarget == "CoolOn" or NewModeTarget == "HeatOn" or NewModeTarget == "AutoChangeOver") then
        luup.variable_set(HVAC_SID, "ModeStatus", NewModeTarget or "", lul_device)

        Tado_setOverley(1, lul_device)
    else
        -- Error
        return 1
    end

end


function Tado_setCurrentSetpoint(lul_device, NewCurrentSetpoint)
    local data = Tado_readSettings()

    Tado_Debug("In setCurrentSetpoint, been requested to set mode: " .. NewCurrentSetpoint)

    luup.variable_set(SETPOINT_SID, "CurrentSetpoint", NewCurrentSetpoint or "", lul_device)

    Tado_setOverley(1, lul_device)
end


function Tado_SetMode(lul_device, NewMode)
    local data = Tado_readSettings()

    Tado_Debug("In setMode (fan), been requested to set mode: " .. NewMode)

    if (NewMode == "PeriodicOn" or NewMode == "ContinuousOn" or NewMode == "Auto") then
        luup.variable_set(HVAC_FAN_SID, "Mode", NewMode, lul_device)

        Tado_setOverley(1, lul_device)
    else
        -- Error
        return 1
    end

end


function Tado_setEnergyModeTarget(lul_device, NewModeTarget)
    local data = Tado_readSettings()

    Tado_Debug("In Tado_setEnergyModeTarget, been requested to set mode: " .. NewModeTarget)

    if (NewModeTarget == "EnergySavingsMode") then
        Tado_setOverley(0, lul_device)
    elseif (NewModeTarget == "Normal") then
        Tado_setOverley(1, lul_device)
    end
end


function Tado_GetTempScale()
    local curlCommand = 'curl -k -L "http://localhost:3480/data_request?id=lu_sdata"'
    local stdout = io.popen(curlCommand)
    local tado_controller = stdout:read("*a")
    stdout:close()

    local obj, pos, err = tado_json.decode (tado_controller, 1, nil)

    TADO_SCALE = obj.temperature
end

function Tado_GetZoneCapabilities(tado_homeid, tado_zoneid, tado_deviceid)
    local data = Tado_readSettings(tado_deviceid)

    Tado_Debug("Refreshing Zone control for homeid: " .. tado_homeid .. " and zoneid: " .. tado_zoneid)

    local curlCommand = 'curl -k -L "https://my.tado.com/api/v2/homes/' .. tado_homeid .. '/zones/' .. tado_zoneid .. '/control?username=' .. data.username .. '&password=' .. url.escape(data.password) .. '"'
    local stdout = io.popen(curlCommand)
    local tado_zonecontrol = stdout:read("*a")
    stdout:close()

    local obj, pos, err = tado_json.decode (tado_zonecontrol, 1, nil)

    if (obj.errors) then
        for i = 1,#obj.errors do
            Tado_Debug("Error: " .. obj.errors[i].title .. " - " .. obj.errors[i].code)
        end
        return 2
    end

    if (obj.userAcCapabilities) then
        if (obj.userAcCapabilities.COOL) then
            luup.variable_set(AC_SID, "TadoCoolMinCelcius", obj.userAcCapabilities.COOL.temperatures.min.celsius or "", tado_deviceid)
            luup.variable_set(AC_SID, "TadoCoolMaxCelcius", obj.userAcCapabilities.COOL.temperatures.max.celsius or "", tado_deviceid)

            luup.variable_set(AC_SID, "TadoCoolMinCFahrenheit", obj.userAcCapabilities.COOL.temperatures.min.fahrenheit or "", tado_deviceid)
            luup.variable_set(AC_SID, "TadoCoolMaxFahrenheit", obj.userAcCapabilities.COOL.temperatures.max.fahrenheit or "", tado_deviceid)

            luup.variable_set(AC_SID, "userAcCapabilitiesCOOLfanSpeeds", obj.userAcCapabilities.COOL.fanSpeeds or "", tado_deviceid)
        end
        if (obj.userAcCapabilities.HEAT) then
            luup.variable_set(AC_SID, "TadoHeatMinCelcius", obj.userAcCapabilities.HEAT.temperatures.min.celsius or "", tado_deviceid)
            luup.variable_set(AC_SID, "TadoHeatMaxCelcius", obj.userAcCapabilities.HEAT.temperatures.max.celsius or "", tado_deviceid)

            luup.variable_set(AC_SID, "TadoHeatMinFahrenheit", obj.userAcCapabilities.HEAT.temperatures.min.fahrenheit or "", tado_deviceid)
            luup.variable_set(AC_SID, "TadoHeatMaxFahrenheit", obj.userAcCapabilities.HEAT.temperatures.max.fahrenheit or "", tado_deviceid)

            luup.variable_set(AC_SID, "userAcCapabilitiesHEATfanSpeeds", obj.userAcCapabilities.HEAT.fanSpeeds or "", tado_deviceid)
        end
    end

    luup.variable_set(AC_SID, "type", obj.type or "", tado_deviceid)
    luup.variable_set(AC_SID, "earlyStartEnabled", obj.earlyStartEnabled or "", tado_deviceid)
    luup.variable_set(AC_SID, "heatingCircuit", obj.heatingCircuit or "", tado_deviceid)
    if (obj.wirelessRemote) then
        luup.variable_set(AC_SID, "wirelessRemotedeviceType", obj.wirelessRemote.deviceType or "", tado_deviceid)
        luup.variable_set(AC_SID, "wirelessRemoteserialNo", obj.wirelessRemote.serialNo or "", tado_deviceid)
        luup.variable_set(AC_SID, "wirelessRemoteshortSerialNo", obj.wirelessRemote.shortSerialNo or "", tado_deviceid)
        luup.variable_set(AC_SID, "wirelessRemotecurrentFwVersion", obj.wirelessRemote.currentFwVersion or "", tado_deviceid)
        if (obj.wirelessRemote.connectionState) then
            luup.variable_set(AC_SID, "wirelessRemoteconnectionStatevalue", obj.wirelessRemote.connectionState.value or "", tado_deviceid)
            luup.variable_set(AC_SID, "wirelessRemoteconnectionStatetimestamp", obj.wirelessRemote.connectionState.timestamp or "", tado_deviceid)
        end
        if (obj.wirelessRemote.characteristics) then
            luup.variable_set(AC_SID, "wirelessRemotecharacteristicscapabilities", obj.wirelessRemote.characteristics.capabilities or "", tado_deviceid)
        end
        if (obj.wirelessRemote.accessPointWiFi) then
            luup.variable_set(AC_SID, "wirelessRemoteaccessPointWiFi", obj.wirelessRemote.accessPointWiFi.ssid or "", tado_deviceid)
        end
        luup.variable_set(AC_SID, "wirelessRemotecommandTableUploadState", obj.wirelessRemote.commandTableUploadState or "", tado_deviceid)
    end

    if (obj.commandConfiguration) then
        if (obj.commandConfiguration.acCommandSet) then
            luup.variable_set(AC_SID, "commandConfigurationacCommandSetcommandType", obj.commandConfiguration.acCommandSet.commandType or "", tado_deviceid)
            luup.variable_set(AC_SID, "commandConfigurationacCommandSetcode", obj.commandConfiguration.acCommandSet.code or "", tado_deviceid)
            luup.variable_set(AC_SID, "commandConfigurationacCommandSetname", obj.commandConfiguration.acCommandSet.name or "", tado_deviceid)
            luup.variable_set(AC_SID, "commandConfigurationacCommandSetorigin", obj.commandConfiguration.acCommandSet.origin or "", tado_deviceid)
            luup.variable_set(AC_SID, "commandConfigurationacCommandSettemperatureUnit", obj.commandConfiguration.acCommandSet.temperatureUnit or "", tado_deviceid)
            luup.variable_set(AC_SID, "commandConfigurationacCommandSetsupportedModes", obj.commandConfiguration.acCommandSet.supportedModes or "", tado_deviceid)
        end
        luup.variable_set(AC_SID, "commandConfigurationdedicatedOnCommand", obj.commandConfiguration.dedicatedOnCommand or "", tado_deviceid)
    end

    if (obj.driver) then
        luup.variable_set(AC_SID, "driverdiscriminator", obj.driver.discriminator or "", tado_deviceid)
        luup.variable_set(AC_SID, "drivertype", obj.driver.type or "", tado_deviceid)
        luup.variable_set(AC_SID, "drivermodes", obj.driver.modes or "", tado_deviceid)
        if (obj.driver.acCommandSet) then
            luup.variable_set(AC_SID, "driveracCommandSetcommandType", obj.driver.acCommandSet.commandType or "", tado_deviceid)
            luup.variable_set(AC_SID, "driveracCommandSetcode", obj.driver.acCommandSet.code or "", tado_deviceid)
            luup.variable_set(AC_SID, "driveracCommandSetname", obj.driver.acCommandSet.name or "", tado_deviceid)
            luup.variable_set(AC_SID, "driveracCommandSetorigin", obj.driver.acCommandSet.origin or "", tado_deviceid)
            luup.variable_set(AC_SID, "driveracCommandSettemperatureUnit", obj.driver.acCommandSet.temperatureUnit or "", tado_deviceid)
            luup.variable_set(AC_SID, "driveracCommandSetsupportedModes", obj.driver.acCommandSet.supportedModes or "", tado_deviceid)
        end
    end

    luup.variable_set(AC_SID, "dedicatedOnCommand", obj.dedicatedOnCommand or "", tado_deviceid)

    if (obj.acSpecs) then
        luup.variable_set(AC_SID, "acSpecsacUnitDisplaysSetPointTemperature", obj.acSpecs.acUnitDisplaysSetPointTemperature or "", tado_deviceid)
        if (obj.acSpecs.remoteControl) then
            luup.variable_set(AC_SID, "acSpecsremoteControlcommandType", obj.acSpecs.remoteControl.commandType or "", tado_deviceid)
            luup.variable_set(AC_SID, "acSpecsremoteControltemperatureUnit", obj.acSpecs.remoteControl.temperatureUnit or "", tado_deviceid)
        end
        if (obj.acSpecs.manufacturer) then
            luup.variable_set(AC_SID, "acSpecsmanufacturerid", obj.acSpecs.manufacturer.id or "", tado_deviceid)
            luup.variable_set(AC_SID, "acSpecsmanufacturername", obj.acSpecs.manufacturer.name or "", tado_deviceid)
        end
    end

    if (obj.duties) then
        luup.variable_set(AC_SID, "dutiestype", obj.duties.type or "", tado_deviceid)
        if (obj.duties.wirelessRemote) then
            luup.variable_set(AC_SID, "dutieswirelessRemotedeviceType", obj.duties.wirelessRemote.deviceType or "", tado_deviceid)
            luup.variable_set(AC_SID, "dutieswirelessRemoteserialNo", obj.duties.wirelessRemote.serialNo or "", tado_deviceid)
            luup.variable_set(AC_SID, "dutieswirelessRemoteshortSerialNo", obj.duties.wirelessRemote.shortSerialNo or "", tado_deviceid)
            luup.variable_set(AC_SID, "dutieswirelessRemotecurrentFwVersion", obj.duties.wirelessRemote.currentFwVersion or "", tado_deviceid)
            if (obj.duties.wirelessRemote.connectionState) then
                luup.variable_set(AC_SID, "dutieswirelessRemoteconnectionStatevalue", obj.duties.wirelessRemote.connectionState.value or "", tado_deviceid)
                luup.variable_set(AC_SID, "dutieswirelessRemoteconnectionStatetimestamp", obj.duties.wirelessRemote.connectionState.timestamp or "", tado_deviceid)
            end
            if (obj.duties.wirelessRemote.characteristics) then
                luup.variable_set(AC_SID, "dutieswirelessRemotecharacteristicscapabilities", obj.duties.wirelessRemote.characteristics.capabilities or "", tado_deviceid)
            end
            if (obj.duties.wirelessRemote.accessPointWiFi) then
                luup.variable_set(AC_SID, "dutieswirelessRemoteaccessPointWiFi", obj.duties.wirelessRemote.accessPointWiFi.ssid or "", tado_deviceid)
            end
            luup.variable_set(AC_SID, "dutieswirelessRemotecommandTableUploadState", obj.duties.wirelessRemote.commandTableUploadState or "", tado_deviceid)
        end
    end
end

function Tado_RefreshZoneCapabilities ()
    Tado_Debug("Refreshing All Zone Capabilities")
    for k, v in pairs (ZONE_LIST) do
        local tado_homeid, tado_zoneid = k:match("([^,]+)_([^,]+)")

        -- Our list contains all Tado devices, so lets see if this HomeID belongs to our instance of this plugin
        if (TADO_MYHOMES[tado_homeid] == 1) then
            -- It does so lets refresh this ZoneIDs capabilities
            Tado_GetZoneCapabilities(tado_homeid, tado_zoneid, v)
        else
            Tado_Debug("Skipping HomeID " .. tado_homeid .. " because its not in our MYHOMES list (RefreshZoneCapabilities)")
        end

    end
end

function tado_init(lul_device)    
    Tado_Debug("Init Start")

    tado_json = require ("dkjson")
    url = require("socket.url")

    Tado_GetTempScale()

    if (Tado_CreateChildren() == 2) then
        -- Got a error here, most likely wrong username password so lets abort our init
        return 2
    end

    Tado_RefreshZoneCapabilities()

    --Tado_StartPollers()
    Tado_Debug("Init Finish")
end

