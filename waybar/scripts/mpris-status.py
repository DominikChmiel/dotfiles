#!/usr/bin/env python3
import subprocess
import json
import unicodedata

PLAY    = ''
PAUSE   = ''
SPOTIFY = ''
BROWSER = ''

IDLE = json.dumps({"text": "", "class": "idle"})


def clean(text):
    """Keep letters, numbers, separators and basic punctuation; drop everything else."""
    return ''.join(
        c for c in text
        if unicodedata.category(c)[0] in ('L', 'N', 'Z')
        or c in " '\"&-.,!?()/:+#@_"
    ).strip()


result = subprocess.run(
    ['playerctl', 'metadata', '--format',
     '{{status}}|||{{playerName}}|||{{title}}|||{{artist}}'],
    capture_output=True, text=True
)

if result.returncode != 0:
    print(IDLE)
    raise SystemExit

parts = result.stdout.strip().split('|||', 3)
if len(parts) < 4:
    print(IDLE)
    raise SystemExit

status, player_name, title, artist = parts

if status not in ('Playing', 'Paused'):
    print(IDLE)
    raise SystemExit

title  = clean(title)[:40]
artist = clean(artist)[:25]

p = player_name.lower()
play_icon = SPOTIFY if 'spotify' in p else BROWSER if any(x in p for x in ('plasma', 'firefox', 'chrome', 'browser')) else PLAY

icon      = PAUSE   if status == 'Paused' else play_icon
css_class = 'paused' if status == 'Paused' else 'playing'

if title and artist:
    text = f"{icon}  {title} - {artist}"
elif title:
    text = f"{icon}  {title}"
else:
    text = ""
print(json.dumps({"text": text, "class": css_class}))
