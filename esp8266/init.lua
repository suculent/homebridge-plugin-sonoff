-- Timers
-- 0 = WiFi status + mqtt connect
-- 1 = MQTT offline
-- 2 = Free
-- 3 = Free
-- 4 = Free
-- 5 = MQTT activity
-- 6 = Button debounce

dofile("config.lua")

mqttBroker = mqtt_broker 
 
-- Pin which the relay is connected to
relayPin = 6
gpio.mode(relayPin, gpio.OUTPUT)
gpio.write(relayPin, gpio.HIGH) -- enabled by default! Turns on light ASAP.
 
-- Connected to switch with internal pullup enabled
buttonPin = 3
buttonDebounce = 250
gpio.mode(buttonPin, gpio.INPUT, gpio.PULLUP)
 
-- MQTT led
mqttLed=7
gpio.mode(mqttLed, gpio.OUTPUT)
gpio.write(mqttLed, gpio.LOW)

wifi.setmode(wifi.STATION)
wifi.sta.config (wifi_ssid, wifi_password)

deviceID = node.chipid();
 
-- Make a short flash with the led on MQTT activity
function mqttAct()
    if (gpio.read(mqttLed) == 1) then gpio.write(mqttLed, gpio.HIGH) end
    gpio.write(mqttLed, gpio.LOW)
    tmr.alarm(5, 50, 0, function() gpio.write(mqttLed, gpio.HIGH) end)
end
 
m = mqtt.Client("Sonoff-" .. deviceID, 180, mqtt_user, mqtt_pass)
m:lwt("/lwt", "Sonoff " .. deviceID, 0, 0)
m:on("offline", function(con)
    ip = wifi.sta.getip()
    print ("MQTT reconnecting to " .. mqttBroker .. " from " .. ip)
    tmr.alarm(1, 10000, 0, function()
        node.restart();
    end)
end)
 
-- Pin to toggle the status
buttondebounced = 0
gpio.trig(buttonPin, "down",function (level)
    if (buttondebounced == 0) then
        buttondebounced = 1
        tmr.alarm(6, buttonDebounce, 0, function() buttondebounced = 0; end)
      
        --Change the state
        if (gpio.read(relayPin) == 1) then
            gpio.write(relayPin, gpio.LOW)
            print("Was on, turning off")
        else
            gpio.write(relayPin, gpio.HIGH)
            print("Was off, turning on")
        end
         
        mqttAct()
        mqtt_update()
    end
end)
 
-- Update status to MQTT
function mqtt_update()
    if (gpio.read(relayPin) == 0) then
        m:publish(mqtt_channel .. "/state","OFF",0,0)
    else
        m:publish(mqtt_channel .. "/state","ON",0,0)
    end
end
  
-- On publish message receive event
m:on("message", function(conn, topic, data)
    pwm.stop(mqttLed)
    mqttAct()
    print("Recieved:" .. topic .. ":" .. data)
        if (data=="ON") then
        print("Enabling Output")        
        gpio.write(relayPin, gpio.HIGH)
        gpio.write(mqttLed, gpio.LOW)
    elseif (data=="OFF") then
        print("Disabling Output")        
        gpio.write(mqttLed, gpio.HIGH)
        gpio.write(relayPin, gpio.LOW)
    else
        print("Invalid command (" .. data .. ")")
    end
    mqtt_update()
end)
 
-- Subscribe to MQTT
function mqtt_sub()
    mqttAct()
    m:subscribe(mqtt_channel,0, function(conn)
        print("MQTT subscribed to " .. mqtt_channel )
        pwm.setup(mqttLed, 1, 512)
        pwm.start(mqttLed)
    end)
end

tmr.alarm(0, 1000, 1, function()
    if wifi.sta.status() == 5 and wifi.sta.getip() ~= nil then  
        tmr.stop(0)
        m:connect(mqttBroker, 1883, 0, function(conn)
            print("MQTT connected to:" .. mqttBroker)
            mqtt_sub()
        end)
    end
 end)
