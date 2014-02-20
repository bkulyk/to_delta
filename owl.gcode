G21 ; set units to millimeters
M104 S220 ; set temperature
G28 ; home all axes
M109 S220 ; wait for temperature to be reached
G90 ; use absolute coordinates
G92 E0 ; reset extrusion distance
M82 ; use absolute distances for extrusion


G1 Z0.490 F8400.000 ; move to next layer (0)
G1 X-6.085 Y-15.658 F8400.000 ; move to first skirt point
G1 X11.715 Y-15.648 E1.00401 F600.000 ; skirt
G1 X12.925 Y-15.548 E1.07249 ; skirt

