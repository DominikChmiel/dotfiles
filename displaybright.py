import paho.mqtt.client as mqtt
import time
from dataclasses import dataclass
import os
import json
import asyncio
import pprint

main_loop: asyncio.AbstractEventLoop | None = None

def on_connect(client, userdata, flags, rc):
    print(f"Connected with result code {rc}")
    client.publish("displays/status", "online")

    if client.displays:
        for d in client.displays:
            d.connect_mqtt()

def on_disconnect(client, userdata, rc):
    print("Device disconnected with result code: " + str(rc))

subs: dict[str, "SingleScreen"] = {}

def on_message(client, userdata, msg):  # The callback for when a PUBLISH message is received
    print("Message received-> "
    + msg.topic + " " + str(msg.payload))  # Print a received msg
    if msg.topic in subs:
        subs[msg.topic].on_mqtt(msg.payload)

client = mqtt.Client()

client.displays = []

client.on_connect = on_connect
client.on_disconnect = on_disconnect
client.on_message = on_message
client.will_set('displays/status', 'offline', 0, True)
client.reconnect_delay_set(min_delay=1, max_delay=30)
client.username_pw_set(os.environ["MQTT_USER"], os.environ["MQTT_PASSWORD"])

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
        try:
            get_proc = await asyncio.create_subprocess_exec(
                *["sudo", "ddcutil", "--skip-ddc-checks", "getvcp", "10", "--bus", str(self.i2c_bus)],
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
        except Exception as e:
            print(f"Failed to read brightness for display {self.number}: {e}")

    async def set_brightness(self, value: int, max_retries: int = 5) -> None:
        for attempt in range(max_retries):
            set_proc = await asyncio.create_subprocess_exec(
                *["ddcutil", "--skip-ddc-checks", "setvcp", "10", "--bus", str(self.i2c_bus), str(value)]
            )
            await set_proc.communicate()
            if set_proc.returncode == 0:
                self.last_brightness = value
                return
            await asyncio.sleep(0.5)
            print(f"Retrying due to failure on {self.number} | {set_proc.returncode} (attempt {attempt + 1}/{max_retries})")
        print(f"Failed to set brightness on {self.number} after {max_retries} attempts")

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
                "name": "MainBoot",
                "sa": "work_room",
                "mf": "MainBoot",
            },
            "~": "displays",
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
        asyncio.run_coroutine_threadsafe(self._set_and_update(new_target), main_loop)

    async def _set_and_update(self, value: int):
        await self.set_brightness(value)
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
        *["sudo", "ddcutil", "detect", "--sleep-multiplier=0.5"],
        stdout=asyncio.subprocess.PIPE,
    )
    disp_list, _ = await detect_proc.communicate()
    specs = disp_list.decode().split("\n\n")

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
    global main_loop
    main_loop = asyncio.get_running_loop()

    while True:
        try:
            client.connect(os.environ["MQTT_SERVER"], 1883, 60)
            break
        except Exception as e:
            print(f"MQTT connect failed: {e}, retrying in 5s...")
            await asyncio.sleep(5)
    client.loop_start()

    while True:
        try:
            client.displays = await init_displays()
            if client.displays:
                break
            print("No displays found, retrying in 10s...")
        except Exception as e:
            print(f"Display init failed: {e}, retrying in 10s...")
        await asyncio.sleep(10)

    try:
        last_update = time.time()
        while True:
            await asyncio.sleep(5)
            if time.time() - last_update > 60 * 60:
                print("Hour since last readout. reading screens")
                t_tasks = [d.read_brightness() for d in client.displays]
                await asyncio.gather(*t_tasks)
                last_update = time.time()
            for d in client.displays:
                d.update()
    finally:
        for d in client.displays:
            d.set_offline()
        client.loop_stop()

asyncio.run(run_polling_loop())
