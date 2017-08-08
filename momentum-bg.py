import os
import json
import sqlite3
import datetime
import requests
import shutil

now = datetime.datetime.now()

datestr = now.strftime('%Y-%m-%d')

dbPath = '~/.config/chromium/Default/Local Storage/chrome-extension_laookkfknpbbblfpciffpaejjkokdgca_0.localstorage';
dbPath = os.path.expanduser(dbPath)

print(dbPath)

conn = sqlite3.connect(dbPath)

c = conn.cursor()

query = "SELECT value FROM ItemTable WHERE key=?"

c.execute(query, ("momentum-background-" + datestr,))

dbValue = c.fetchone()

val = dbValue[0].decode('utf-16', errors='ignore')

js = json.loads(val)

print(js)
wallFile = "wallpaper" + os.path.splitext(js['filename'])[1]

r = requests.get(js['filename'], stream=True)

if r.status_code == 200:
    with open(wallFile, 'wb') as f:
        r.raw.decode_content = True
        shutil.copyfileobj(r.raw, f)
    os.system('nitrogen --set-scaled ' + wallFile)
