import os
import json
import asyncio
import subprocess
from dataclasses import dataclass, asdict

STATE_FILE = "display.state.json"


@dataclass
class DisplayInfo:
    name: str
    bus: int | None
    id: str
    max_value: int = 100
    curr_value: int = -1
    lowest_set_value: int = -1
    min_value: int = 0


loaded_modules = (
    subprocess.check_output("lsmod | awk '{print $1}'", shell=True).decode().split("\n")
)

if "i2c_dev" not in loaded_modules:
    print(f"i2c_dev is not loaded. Loading")
    subprocess.check_call(["modprobe", "i2c_dev"])


async def single_display_update(
    key: str, dinfo: DisplayInfo
) -> tuple[str, DisplayInfo]:
    if dinfo.bus:
        busparams = ["--bus", str(dinfo.bus)]
    else:
        busparams = ["-d", dinfo.id]
    get_proc = await asyncio.create_subprocess_exec(
        *["ddcutil", "getvcp", "10", *busparams],
        stdout=asyncio.subprocess.PIPE,
    )
    c_brightness_str_stdout, _ = await get_proc.communicate()
    print(c_brightness_str_stdout)
    c_brightness_str = (
        c_brightness_str_stdout.decode()
        .strip()
        .replace(" value ", "")
        .split(":")[1]
        .split(",")
    )
    curr_value = int(c_brightness_str[0].split("=")[1].strip())
    max_value = int(c_brightness_str[1].split("=")[1].strip())
    dinfo.curr_value = curr_value
    dinfo.max_value = max_value
    if dinfo.lowest_set_value == -1 or dinfo.lowest_set_value > curr_value:
        dinfo.lowest_set_value = dinfo.curr_value
    print(
        type(dinfo.curr_value),
        type(dinfo.lowest_set_value),
        dinfo.curr_value == dinfo.lowest_set_value,
    )

    if dinfo.curr_value == dinfo.lowest_set_value:
        new_val = 70
    else:
        new_val = dinfo.lowest_set_value

    print(f"Setting {dinfo.id} = {new_val}")
    set_proc = await asyncio.create_subprocess_exec(
        *["ddcutil", "setvcp", "10", str(new_val), *busparams]
    )
    await get_proc.communicate()
    return key, dinfo


async def main() -> None:
    displays: dict[str, DisplayInfo] = {}
    loaded_displays: dict[str, DisplayInfo] = {}

    if os.path.exists(STATE_FILE):
        with open(STATE_FILE, "r") as inf:
            dicted_data = json.loads(inf.read())
            for key, dinfo in dicted_data.items():
                if "bus" not in dinfo:
                    dinfo["bus"] = None
                loaded_displays[key] = DisplayInfo(**dinfo)

    print("Loaded:")
    print(loaded_displays)

    current_display = None
    current_bus = None

    for line in (
        subprocess.check_output(
            ["ddcutil", "detect", "--async", "--sleep-multiplier=0.5"]
        )
        .decode()
        .split("\n")
    ):
        if line.startswith("Display"):
            current_display = line.split(" ")[1]
            print(f"Have current display {current_display}")
        if "Model:" in line and current_display:
            mname = line.split("Model:")[1].strip()
            if mname not in loaded_displays:
                displays[mname] = DisplayInfo(
                    name=mname, id=current_display, bus=current_bus
                )
            else:
                displays[mname] = loaded_displays[mname]
                displays[mname].bus = current_bus
            current_display = None
            current_bus = None
        if "I2C bus:" in line and current_display:
            busname = line.split("I2C bus:")[1].strip().replace("/dev/i2c-", "")
            current_bus = busname

    tasks = []

    for key, dinfo in displays.items():
        tasks.append(single_display_update(key, dinfo))

    res = await asyncio.gather(*tasks)

    for key, dinfo in res:
        displays[key] = dinfo

    with open(STATE_FILE, "w") as of:
        dicted_data = {}
        for key, dinfo in displays.items():
            dicted_data[key] = asdict(dinfo)
        of.write(json.dumps(dicted_data, indent=4))


asyncio.run(main())
