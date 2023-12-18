import paho.mqtt.client as mqtt
import time
from dataclasses import dataclass
import os
import json
import asyncio
import subprocess
import pprint
from dataclasses import dataclass, asdict

def on_connect(client, userdata, flags, rc):
    print(f"Connected with result code {rc}")

def on_disconnect(client, userdata, rc):
    print("Device disconnected with result code: " + str(rc))

def on_log(client, userdata, level, buf):
    print(f"SYSTEM: {buf}")

subs: dict[str, "SingleScreen"] = {}

def on_message(client, userdata, msg):  # The callback for when a PUBLISH 
    print("Message received-> " 
    + msg.topic + " " + str(msg.payload))  # Print a received msg
    if msg.topic in subs:
        subs[msg.topic].on_mqtt(msg.payload)

client = mqtt.Client()
client.on_connect = on_connect
client.on_disconnect = on_disconnect
client.on_message = on_message
client.on_log = on_log
client.will_set('displays/status', 'offline', 0, True)
client.username_pw_set(os.environ["MQTT_USER"], os.environ["MQTT_PASSWORD"])
client.connect(os.environ["MQTT_SERVER"], 1883, 60)
client.publish(f"displays/status", "online")

async def get_device_mac() -> str:
    get_proc = await asyncio.create_subprocess_shell(
        *["cat /sys/class/net/$(ip route show default | awk '/default/ {print $5}')/address"],
        stdout=asyncio.subprocess.PIPE,
    )
    output, _ = await get_proc.communicate()
    return output.decode()


DEV_MAC = asyncio.run(get_device_mac())
print("Starting on device " + DEV_MAC)

@dataclass()
class SingleScreen():
    number: int
    i2c_bus: int
    name: str

    last_brightness: int = -1

    async def read_brightness(self):
        get_proc = await asyncio.create_subprocess_exec(
            *["sudo", "ddcutil", "getvcp", "10", "--bus", str(self.i2c_bus)],
            stdout=asyncio.subprocess.PIPE,
        )
        c_brightness_str_stdout, _ = await get_proc.communicate()
        c_brightness_str = (
            c_brightness_str_stdout.decode()
            .strip()
            .replace(" value ", "")
            .split(":")[1]
            .split(",")
        )
        curr_value = int(c_brightness_str[0].split("=")[1].strip())
        self.last_brightness = curr_value

    async def set_brightness(self, value: int) -> None:
        while True:
            set_proc = await asyncio.create_subprocess_exec(
                *["ddcutil", "setvcp", "10", "--bus", str(self.i2c_bus), str(value)]
            )
            await set_proc.communicate()
            if set_proc.returncode == 0:
                break
            await asyncio.sleep(0.5)
            print(f"Retrying due to failure on {self.number} | {set_proc.returncode}")
        self.last_brightness = value

    @property
    def set_topic(self):
        return f"displays/{self.number}/brightness/set"

    @property
    def discovery_json(self):
        return {
            "dev": {
                "ids": [
                    f"screen_{self.number}"
                ],
                "cns": [
                    [
                        "mac",
                        DEV_MAC
                    ]
                ],
                "name": "Screen Controller Mainboot",
                "sa": "work_room",
                "mf": "MainBoot",
            },
            "~": f"displays",
            "name": f"Display {self.name} brightness",
            "uniq_id": f"displays_{self.number}_brightness",
            "avty_t": "~/status",
            "stat_t": f"~/{self.number}/brightness",
            "cmd_t": f"~/{self.number}/brightness/set",
            "unit_of_meas": "%",
            "min": 0,
            "max": 100,
            "step": "1",
            "entity_category": "config"
        }

    def on_mqtt(self, msg):
        print(self.number, msg)
        new_target = int(msg)
        asyncio.run(self.set_brightness(new_target))
        self.update()

    def update(self):
        client.publish(f"displays/{self.number}/brightness", self.last_brightness)

    def connect_mqtt(self):
        self.update()
        client.subscribe(self.set_topic)
        subs[self.set_topic] = self
        client.publish(f"homeassistant/number/screen_{self.number}/brightness/config", json.dumps(self.discovery_json))

    def set_offline(self):
        client.publish(f"displays/{self.number}/status", "offline")

    @staticmethod
    async def from_output(output: str) -> "SingleScreen":
        assert output.startswith('Display')
        data = {}
        lines = output.split('\n')
        for line in lines:
            line = line.strip()
            if line.startswith("Display "):
                assert "number" not in data
                data["number"] = int(line.rsplit(" ", 1)[1])
            if line.startswith("Display "):
                data["number"] = int(line.rsplit(" ", 1)[1])
            if "I2C bus:" in line:
                busname = line.split("I2C bus:")[1].strip().replace("/dev/i2c-", "")
                data["i2c_bus"] = int(busname)
            if "Model:" in line:
                data["name"] = line.split("Model:")[1].strip()
        disp = SingleScreen(**data)
        await disp.read_brightness()
        disp.connect_mqtt()
        return disp

async def init_displays():
    detect_proc = await asyncio.create_subprocess_exec(
        *["sudo", "ddcutil", "detect", "--async", "--sleep-multiplier=0.5"],
        stdout=asyncio.subprocess.PIPE,
    )
    disp_list, _ = await detect_proc.communicate()
    specs = disp_list.decode().split("\n\n")

    all_displays = []
    tasks = []
    for spec in specs:
        if spec.strip() and "Display" in spec:
            spec = 'Display' + spec.split('Display')[1]
            print(spec)
            print("=======")
            tasks.append(SingleScreen.from_output(spec))
            
    all_displays = await asyncio.gather(*tasks)

    pprint.pprint(all_displays)
    for disp in all_displays:
        print(disp.discovery_json)

    return all_displays

async def run_polling_loop():
    displays = await init_displays()
    client.loop_start()
    try:
        last_update = time.time()
        while True:
            await asyncio.sleep(5)
            if time.time() - last_update > 60*60:
                print("Hour since last readout. reading screens")
                for d in displays:
                    d.read_brightness()
                last_update = time.time()
            for d in displays:
                d.update()
    finally:
        for d in displays:
            d.set_offline()
        client.loop_stop()

asyncio.run(run_polling_loop())