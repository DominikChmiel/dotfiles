#!/bin/bash

SS_FILES=simplescreen*mkv
for f in $SS_FILES
do
	ffmpeg -y -i $f -vf fps=10,scale=1800:-1:flags=lanczos,palettegen palette.png
	ffmpeg -i $f -i palette.png -filter_complex "fps=10,scale=1800:-1:flags=lanczos[x];[x][1:v]paletteuse" $f.gif
done
