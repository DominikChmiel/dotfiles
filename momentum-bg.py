import os
import sys
import time
import json
import shutil
import sqlite3
import requests
import datetime


dbPath = '~/.config/chromium/Default/Local Storage/chrome-extension_laookkfknpbbblfpciffpaejjkokdgca_0.localstorage';
dbPath = os.path.expanduser(dbPath)

def getTodaysImagePath():
    now = datetime.datetime.now()
    datestr = now.strftime('%Y-%m-%d')

    conn = sqlite3.connect('file:' + dbPath + '?mode=ro', uri=True)
    c = conn.cursor()
    query = "SELECT value FROM ItemTable WHERE key=?"

    c.execute(query, ("momentum-background-" + datestr,))

    dbValue = c.fetchone()
    conn.close()

    if dbValue:
        val = dbValue[0].decode('utf-16', errors='ignore')
        js = json.loads(val)

        return js['filename']

    return None

while True:
    pt = getTodaysImagePath()

    if pt:
        wallFile = "wallpaper" + os.path.splitext(pt)[1]

        r = requests.get(pt, stream=True)

        if r.status_code == 200:
            with open(wallFile, 'wb') as f:
                r.raw.decode_content = True
                shutil.copyfileobj(r.raw, f)
            os.system('nitrogen --set-scaled ' + wallFile)
        sys.exit(0)
    # Check every minute
    time.sleep(60)
