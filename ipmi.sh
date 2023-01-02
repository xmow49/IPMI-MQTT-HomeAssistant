#!/bin/bash
SHELL=/bin/sh PATH=/bin:/sbin:/usr/bin:/usr/sbin
MQTT_IP='XXX'
MQTT_USER='XXX'
MQTT_PW='XXX'

HA_SENSOR_TOPIC='homeassistant/sensor'
SERVER_TOPIC='TRUENAS'

createConfig(){ # $1 = sensor name, $2 = sensor id, $3 = unit of measurement, $4 = device_class, $5 = icon
    JSON="{ \"name\":\"$1\",\"unique_id\": \"${SERVER_TOPIC}_$2\",\"object_id\": \"${SERVER_TOPIC}_$2\",\"state_topic\":\"$HA_SENSOR_TOPIC/$SERVER_TOPIC/$2/state\",\"unit_of_measurement\":\"$3\",\"device\": {\"identifiers\": [\"$SERVER_TOPIC\"], \"name\": \"$SERVER_TOPIC\", \"model\": \"R730\", \"manufacturer\": \"DELL\"}"
    
    if [ "$4" != "NULL" ];
    then
        JSON=$JSON",\"device_class\":\"$4\""
    fi
    
    if [ "$5" != "NULL" ];
    then
        JSON=$JSON",\"icon\":\"$5\""
    fi
    echo $JSON"}"
}

createConfigTopic(){
    echo "$HA_SENSOR_TOPIC/$SERVER_TOPIC/$1/config"
}

createStateTopic(){
    echo "$HA_SENSOR_TOPIC/$SERVER_TOPIC/$1/state"
}

postMQTT(){
    mosquitto_pub -r -t "$1" -m "$2" -h "$MQTT_IP" -u "$MQTT_USER" -P "$MQTT_PW"
}

init(){
    postMQTT "$(createConfigTopic 'CPU1')" "$(createConfig 'CPU1' 'CPU1' '°C' 'temperature' 'NULL')"
    postMQTT "$(createConfigTopic 'CPU2')" "$(createConfig 'CPU2' 'CPU2' '°C' 'temperature' 'NULL')"
    postMQTT "$(createConfigTopic 'Inlet')" "$(createConfig 'Entrée air' 'Inlet' '°C' 'temperature' 'NULL')"
    postMQTT "$(createConfigTopic 'Exhaust')" "$(createConfig 'Sortie air' 'Exhaust' '°C' 'temperature' 'NULL')"
    
    postMQTT "$(createConfigTopic 'Fan1')" "$(createConfig 'Ventilateur 1' 'Fan1' 'RPM' 'NULL' 'mdi:fan')"
    postMQTT "$(createConfigTopic 'Fan2')" "$(createConfig 'Ventilateur 2' 'Fan2' 'RPM' 'NULL' 'mdi:fan')"
    postMQTT "$(createConfigTopic 'Fan3')" "$(createConfig 'Ventilateur 3' 'Fan3' 'RPM' 'NULL' 'mdi:fan')"
    postMQTT "$(createConfigTopic 'Fan4')" "$(createConfig 'Ventilateur 4' 'Fan4' 'RPM' 'NULL' 'mdi:fan')"
    postMQTT "$(createConfigTopic 'Fan5')" "$(createConfig 'Ventilateur 5' 'Fan5' 'RPM' 'NULL' 'mdi:fan')"
    postMQTT "$(createConfigTopic 'Fan6')" "$(createConfig 'Ventilateur 6' 'Fan6' 'RPM' 'NULL' 'mdi:fan')"
    
    
    postMQTT "$(createConfigTopic 'Current1')" "$(createConfig 'Courant 1' 'Current1' 'A' 'current' 'NULL')"
    postMQTT "$(createConfigTopic 'Current2')" "$(createConfig 'Courant 2' 'Current2' 'A' 'current' 'NULL')"
    postMQTT "$(createConfigTopic 'Power')" "$(createConfig 'Puissance' 'Power' 'W' 'power' 'NULL')"

    postMQTT "$(createConfigTopic 'FanSpeed')" "$(createConfig 'Vitesse ventilateurs' 'FanSpeed' '%' 'NULL' 'mdi:fan')"
    
}

if [ "$1" == "i" ]; then 
    echo "init"
    init
fi

TEMPS=$(ipmitool sdr type temperature | cut -d '|' -f 5 | awk '{print $1}' | tr '\n' ' ') # récupère les températures (20 30 40 50)
read -r Inlet Exhaust CPU1 CPU2 <<< "$TEMPS" # les stocke dans des variables (Inlet=20, Exhaust=30, CPU1=40, CPU2=50)

FANS=$(ipmitool sdr type fan | cut -d '|' -f 5 | awk '{print $1}' | tr '\n' ' ') # récupère les vitesses des ventilateurs (1000 2000 3000 4000)
read -r Fan1 Fan2 Fan3 Fan4 Fan5 Fan6 R <<< "$FANS" # les stocke dans des variables (Fan1=1000, Fan2=2000, Fan3=3000, Fan4=4000)

CURRENT=$(ipmitool sdr type current | cut -d '|' -f 5 | awk '{print $1}' | tr '\n' ' ') # récupère les courants (0.4 0.4 140)
read -r Current1 Current2 Power <<< "$CURRENT" # les stocke dans des variables (Current1=0.4, Current2=0.4, Power=140)
echo "Inlet: $Inlet Exhaust: $Exhaust CPU1: $CPU1 CPU2: $CPU2 Fan1: $Fan1 Fan2: $Fan2 Fan3: $Fan3 Fan4: $Fan4 Fan5: $Fan5 Fan6: $Fan6 Current1: $Current1 Current2: $Current2 Power: $Power"

postMQTT $(createStateTopic 'CPU1') "$CPU1"
postMQTT $(createStateTopic 'CPU2') "$CPU2"
postMQTT $(createStateTopic 'Inlet') "$Inlet"
postMQTT $(createStateTopic 'Exhaust') "$Exhaust"

postMQTT $(createStateTopic 'Fan1') "$Fan1"
postMQTT $(createStateTopic 'Fan2') "$Fan2"
postMQTT $(createStateTopic 'Fan3') "$Fan3"
postMQTT $(createStateTopic 'Fan4') "$Fan4"
postMQTT $(createStateTopic 'Fan5') "$Fan5"
postMQTT $(createStateTopic 'Fan6') "$Fan6"

postMQTT $(createStateTopic 'Current1') "$Current1"
postMQTT $(createStateTopic 'Current2') "$Current2"
postMQTT $(createStateTopic 'Power') "$Power"


setFanSpeed(){
        MAX_TEMP=$(( $CPU1 > $CPU2 ? $CPU1 : $CPU2 ))
        # echo "CPU 1: "$CPU1"°C | CPU2: "$CPU2"°C | MAX TEMP: "$MAX_TEMP"°C"
        if [ $MAX_TEMP -ge 80 ] ; then
                echo "75"
                ipmitool raw 0x30 0x30 0x02 0xff 0x48
        elif [ $MAX_TEMP -ge 70 ] ; then
                echo "50"
                ipmitool raw 0x30 0x30 0x02 0xff 0x32
        elif [ $MAX_TEMP -ge 60 ] ; then
                echo "15"
                ipmitool raw 0x30 0x30 0x02 0xff 0x0f
        elif [ $MAX_TEMP -ge 55 ] ; then
                echo "10"
                ipmitool raw 0x30 0x30 0x02 0xff 0x0a
        elif [ $MAX_TEMP -ge 54 ] ; then
                echo "5"
                ipmitool raw 0x30 0x30 0x02 0xff 0x05
        else
                echo "1"
                ipmitool raw 0x30 0x30 0x02 0xff 0x01
        fi
}

FAN_SPEED=$(setFanSpeed)
postMQTT $(createStateTopic 'FanSpeed') "$FAN_SPEED"
echo "Fan speed: $FAN_SPEED%"