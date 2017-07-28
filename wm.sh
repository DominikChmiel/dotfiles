# Disable KWin and use i3gaps as WM
export KDEWM=/usr/bin/i3

# Compositor (Animations, Shadows, Transparency)
# xcompmgr -C
compton -e 0.4 -r8 -l-12 -t-8  -b  -D1 -I1 --backend glx --glx-no-stencil --glx-no-rebind-pixmap --vsync opengl-swc
