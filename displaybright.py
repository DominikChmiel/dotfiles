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

    if client.lock_sensor:
        client.lock_sensor.connect_mqtt()

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
client.lock_sensor = None

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


async def run_capture(args: list[str]) -> tuple[int, str]:
    proc = await asyncio.create_subprocess_exec(
        *args,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.DEVNULL,
    )
    stdout, _ = await proc.communicate()
    return proc.returncode, stdout.decode().strip()


def ensure_session_bus():
    """systemd --user exports the session bus for us, other session managers may not."""
    if os.environ.get("DBUS_SESSION_BUS_ADDRESS"):
        return
    bus = os.path.join(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"), "bus")
    if os.path.exists(bus):
        os.environ["DBUS_SESSION_BUS_ADDRESS"] = f"unix:path={bus}"
        print(f"DBUS_SESSION_BUS_ADDRESS was unset, using {bus}")

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


LOCK_POLL_INTERVAL = 5

# Session bus screensaver interfaces, in probe order. Plasma owns
# org.freedesktop.ScreenSaver, the rest cover the other desktops.
SCREENSAVER_TARGETS = [
    ("org.freedesktop.ScreenSaver", "/ScreenSaver", "org.freedesktop.ScreenSaver"),
    ("org.freedesktop.ScreenSaver", "/org/freedesktop/ScreenSaver", "org.freedesktop.ScreenSaver"),
    ("org.gnome.ScreenSaver", "/org/gnome/ScreenSaver", "org.gnome.ScreenSaver"),
    ("org.cinnamon.ScreenSaver", "/org/cinnamon/ScreenSaver", "org.cinnamon.ScreenSaver"),
    ("org.xfce.ScreenSaver", "/org/xfce/ScreenSaver", "org.xfce.ScreenSaver"),
    ("org.mate.ScreenSaver", "/org/mate/ScreenSaver", "org.mate.ScreenSaver"),
]

# Processes that only exist while the screen is locked. Lockers that keep a
# daemon running while unlocked (xscreensaver, light-locker) must not be listed.
LOCKER_PROCESSES = [
    "swaylock",
    "hyprlock",
    "waylock",
    "gtklock",
    "i3lock",
    "xsecurelock",
    "slock",
    "xtrlock",
    "physlock",
]


class LockSensor():
    """Publishes whether the graphical session is locked.

    Asks whoever can answer, most reliable first: the screensaver D-Bus
    interface (Plasma and every other desktop implementing it), then logind's
    LockedHint (swaylock, GNOME, anything locked via `loginctl lock-session`),
    then the presence of a bare locker process (i3lock & friends, which report
    nowhere else). D-Bus is authoritative when present; the other two can only
    ever raise "locked", since a session where nothing sets LockedHint looks
    identical to an unlocked one.
    """

    def __init__(self):
        self.locked: bool | None = None
        self.source: str | None = None
        self.dbus_target: tuple[str, str, str] | None = None
        self.session_id: str | None = None

    async def dbus_active(self) -> bool | None:
        targets = SCREENSAVER_TARGETS
        if self.dbus_target:
            targets = [self.dbus_target] + [t for t in targets if t != self.dbus_target]

        for target in targets:
            dest, path, iface = target
            rc, out = await run_capture([
                "gdbus", "call", "--session", "--dest", dest,
                "--object-path", path, "--method", f"{iface}.GetActive",
            ])
            if rc == 0 and ("true" in out or "false" in out):
                self.dbus_target = target
                return "true" in out

        self.dbus_target = None
        return None

    async def logind_session(self) -> str | None:
        if self.session_id:
            return self.session_id
        # A systemd --user service has no XDG_SESSION_ID of its own, so ask
        # logind for the graphical session of this user first.
        rc, out = await run_capture(["loginctl", "show-user", str(os.getuid()), "-p", "Display", "--value"])
        self.session_id = out if rc == 0 and out else os.environ.get("XDG_SESSION_ID")
        return self.session_id

    async def logind_locked_hint(self) -> bool | None:
        session = await self.logind_session()
        if not session:
            return None
        rc, out = await run_capture(["loginctl", "show-session", session, "-p", "LockedHint", "--value"])
        if rc != 0:
            self.session_id = None  # session went away, re-resolve next time
            return None
        return out == "yes" if out in ("yes", "no") else None

    async def locker_process_running(self) -> bool | None:
        rc, _ = await run_capture(["pgrep", "-x", "-u", str(os.getuid()), "|".join(LOCKER_PROCESSES)])
        return rc == 0 if rc in (0, 1) else None

    async def read(self) -> None:
        try:
            active = await self.dbus_active()
            if active is not None:
                self.record(active, f"dbus:{self.dbus_target[0]}")
                return

            hint = await self.logind_locked_hint()
            if hint:
                self.record(True, "logind")
                return

            running = await self.locker_process_running()
            if running:
                self.record(True, "process")
                return

            if hint is False:
                self.record(False, "logind")
            elif running is False:
                self.record(False, "process")
            else:
                self.record(None, None)
        except Exception as e:
            print(f"Failed to read lock state: {e}")

    def record(self, locked: bool | None, source: str | None) -> None:
        if (locked, source) != (self.locked, self.source):
            print(f"Session lock state: {locked} (via {source})")
        self.locked = locked
        self.source = source

    @property
    def state_topic(self):
        return "displays/session/locked"

    @property
    def discovery_json(self):
        return {
            "dev": {
                "ids": [
                    "session"
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
            "name": "Session locked",
            "uniq_id": "displays_session_locked",
            "avty_t": "~/status",
            "stat_t": "~/session/locked",
            "dev_cla": "lock",
            # HA reads a lock binary_sensor as "on == open", hence the inversion
            "pl_on": "unlocked",
            "pl_off": "locked",
        }

    def update(self):
        if self.locked is None:
            return
        client.publish(self.state_topic, "locked" if self.locked else "unlocked")

    def connect_mqtt(self):
        client.publish("homeassistant/binary_sensor/session/lock/config", json.dumps(self.discovery_json))
        self.update()

    async def poll_loop(self):
        while True:
            await self.read()
            self.update()
            await asyncio.sleep(LOCK_POLL_INTERVAL)

    async def watch(self):
        """Push updates for D-Bus sessions, so locking shows up without waiting
        for the next poll. Every other session type relies on polling alone."""
        while True:
            if not self.dbus_target:
                await asyncio.sleep(LOCK_POLL_INTERVAL)
                continue

            dest = self.dbus_target[0]
            monitor = await asyncio.create_subprocess_exec(
                *["gdbus", "monitor", "--session", "--dest", dest],
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL,
            )
            print(f"Watching {dest} for lock changes")
            try:
                async for line in monitor.stdout:
                    if b"Changed" in line:
                        await self.read()
                        self.update()
            finally:
                try:
                    monitor.terminate()
                except ProcessLookupError:
                    pass
            print(f"{dest} monitor exited, restarting in {LOCK_POLL_INTERVAL}s")
            await asyncio.sleep(LOCK_POLL_INTERVAL)


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

    # Announced before display detection, which may keep retrying for a while
    ensure_session_bus()
    client.lock_sensor = LockSensor()
    await client.lock_sensor.read()
    client.lock_sensor.connect_mqtt()
    lock_tasks = [
        asyncio.create_task(client.lock_sensor.poll_loop()),
        asyncio.create_task(client.lock_sensor.watch()),
    ]

    try:
        while True:
            try:
                client.displays = await init_displays()
                if client.displays:
                    break
                print("No displays found, retrying in 10s...")
            except Exception as e:
                print(f"Display init failed: {e}, retrying in 10s...")
            await asyncio.sleep(10)

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
        for task in lock_tasks:
            task.cancel()
        for d in client.displays:
            d.set_offline()
        client.loop_stop()

if __name__ == "__main__":
    asyncio.run(run_polling_loop())
