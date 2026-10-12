# Settings for dmgbuild. Paths come in through -D so CI and a local run share one layout.
import os

app = defines.get("app")  # noqa: F821 — dmgbuild injects `defines`
background = defines.get("background")  # noqa: F821

files = [app]
symlinks = {"Applications": "/Applications"}
badge_icon = app
icon_size = 96
text_size = 12
window_rect = ((100, 120), (660, 400))
icon_locations = {
    os.path.basename(app): (160, 190),
    "Applications": (500, 190),
}
background = background
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
include_icon_view_settings = True
include_list_view_settings = False
arrange_by = None
grid_offset = (0, 0)
grid_spacing = 100
scroll_position = (0, 0)
label_pos = "bottom"
