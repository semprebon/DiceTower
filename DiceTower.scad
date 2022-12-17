
HEIGHT = 140;
RADIUS = 40;

STEP_TREAD = 8;
STEP_THICKNESS = 3;
STEP_RISER = 5;
SIDES = 8;
WALL_THICKNESS = 2.4;
BAR_THICKNESS = WALL_THICKNESS * 8/12;
//INSCRIBED_RADIUS = RADIUS * cos(360/SIDES);
INSCRIBED_RADIUS = RADIUS;
WALL_WIDTH = 2*RADIUS*sin(180/SIDES);
TURRET_HEIGHT = 25;
NOMINAL_BRICK_SIZE = [6,3,3];
ARCH_BORDER = 3;
ARCH_BORDER_THICKNESS = 1;
FAST = false;
STEP_ROTATIONS_DEGREES = 360;
TOP_GAP = 20;
TURRET_SUPPORT_HEIGHT = RADIUS * 0.8;
INNER_RADIUS = 12;
STEP_COUNT = HEIGHT / STEP_RISER;

STEP_SIZE = [STEP_TREAD, RADIUS, STEP_THICKNESS];

function range_upto(n) = [0:(n-1)];

module uncut_steps(height=HEIGHT, angle=360, size=STEP_SIZE, top_gap=0) {
    step_angle = atan2(size.x*1.5, size.y);
    count = ceil(angle / step_angle);
    rise = height / count;
    skipped_steps = ceil(top_gap / rise);
    z0 = rise - size.z;
    echo(count=count, rise=rise, z0=z0, size=size);
    for (i = [0:(count-1-skipped_steps)]) {
        rotate(i*angle/count) translate([-size.x/2,0,z0+i*rise]) cube(STEP_SIZE);
    }
    cylinder(r=STEP_SIZE.x/2, h=height, $fn=60);
}

module polygon_prism(height=HEIGHT, radius=RADIUS, sides=SIDES) {
    //radius = inscribed_radius*sin(360/sides);
    rotate([0,0,180/sides]) cylinder(h=height, r=radius, $fn=sides);
}

module tower_interior_cut(height=HEIGHT, wall_offset=RADIUS, sides=SIDES) {
    rotate([0,0,180/sides]) cylinder(h=height, r=wall_offset, $fn=sides);
}

module arch(size) {
    curve_offset = size.y - size.x*2/sqrt(3);
    translate([0,curve_offset]) intersection() {
        translate([size.x/2,0]) circle(r=size.x, $fn=60);
        translate([-size.x/2,0]) circle(r=size.x, $fn=60);
        translate([-size.x/2,0]) square([size.x,size.x]);
    }
    translate([-size.x/2,0]) square([size.x,curve_offset]);
}

module window_sill(width, height=ARCH_BORDER) {
    w = WALL_THICKNESS;
    t = WALL_THICKNESS + ARCH_BORDER_THICKNESS;
    a = ARCH_BORDER_THICKNESS;
    b = height;
    rotate([0,-90.0]) translate([0,-ARCH_BORDER,0]) linear_extrude(width, center=true) {
        polygon([[0,0],[w,0],[w+a,a],[w+a,b],[0,b]]);
    }
}
module window(size, operation, bars=true) {
    if (operation == "PRECUT") {
        rotate([90, 0, 90]) {
            difference() {
                linear_extrude(WALL_THICKNESS + ARCH_BORDER_THICKNESS) arch(size + [ARCH_BORDER, ARCH_BORDER]);
                linear_extrude(WALL_THICKNESS+ARCH_BORDER_THICKNESS+10) arch(size);
            }
            window_sill(size.x + ARCH_BORDER);
        }
    } else if (operation == "CUT") {
        rotate([90, 0, 90]) linear_extrude(WALL_THICKNESS+ARCH_BORDER_THICKNESS+10) arch(size);
    } else if (operation == "ADD") {
        if (bars) {
            //rotate([90,0,90]) linear_extrude(WALL_THICKNESS) arch(size);
            bar_diameter = BAR_THICKNESS;
            num_bars = floor(size.x/(1.5*bar_diameter));
            gap = (size.x - num_bars*bar_diameter) / (num_bars+1);
            dy = gap + bar_diameter;
            y0 = -size.x/2 + gap + bar_diameter/2;
            //echo(width=size.x, num_bars=num_bars, gap=gap);
            if (num_bars > 1) {
                for (i = range_upto(num_bars)) {
                    translate([WALL_THICKNESS/2,y0+i*dy,0]) cylinder(r=bar_diameter/2, h=size.y, $fn=8);
                }
            }
        }
    } else {
        echo("Invalid window operation: ", operation);
    }
}

module door(size, operation) {
    if (operation == "PRECUT") {
        rotate([90, 0, 90]) {
            difference() {
                linear_extrude(WALL_THICKNESS + ARCH_BORDER_THICKNESS) arch(size + [ARCH_BORDER, ARCH_BORDER]);
                linear_extrude(WALL_THICKNESS+ARCH_BORDER_THICKNESS+10) arch(size);
            }
            translate([0,0.6,0]) window_sill(size.x + ARCH_BORDER, height=ARCH_BORDER-0.6);
        }
    } else if (operation == "CUT") window(size, operation);
}

WINDOW_STYLE_OFFSET = 0;
WINDOW_SIZE_OFFSET = 1;
WINDOW_RELATIVE_POSITION_OFFSET = 2;

function window_position(wall_size, window) =
    let(pos = window[WINDOW_RELATIVE_POSITION_OFFSET])
    [0, wall_size.x*(pos.x+1)/2, wall_size.y*(pos.y+1)/2];

module position_windows(wall_size, windows, operation="CUT") {
    for (w=windows) {
        translate(window_position(wall_size, w)) {
            if (w[WINDOW_STYLE_OFFSET] == "B") window(w[WINDOW_SIZE_OFFSET], operation, true);
            else if (w[WINDOW_STYLE_OFFSET] == "W") window(w[WINDOW_SIZE_OFFSET], operation, false);
            else if (w[WINDOW_STYLE_OFFSET] == "D") door(w[WINDOW_SIZE_OFFSET], operation);
            else crenulation(w[WINDOW_SIZE_OFFSET], operation);
        }
    }
}

function create_window(style="B", position=[0,0], size=[10,20]) = [style, size, position];

module brick_horizontal_groove(width, depth=0.5) {
    side = depth*sqrt(2);
    translate([0,width/2,0]) rotate([0,45,0]) cube([side,width,side], center=true);
}

module brick_vertical_groove(height, depth=0.5) {
    side = depth*sqrt(2);
    translate([0,0,height/2]) rotate([0,0,45]) cube([side,side,height], center=true);
}

module brick_cutter(height, width, depth=0.4, margin=NOMINAL_BRICK_SIZE.x/2) {
    if (FAST == false) {
        brick_layers = round(height / NOMINAL_BRICK_SIZE.z);
        brick_height = height / brick_layers;
        bricks_per_layer = round((width - NOMINAL_BRICK_SIZE.x / 2) / NOMINAL_BRICK_SIZE.x) ;
        brick_width = width / (bricks_per_layer + 0.5);
        echo(nominal_size = NOMINAL_BRICK_SIZE, actual_size = [brick_width, 1, brick_height], layers = brick_layers,
        per_layer = bricks_per_layer);

        for (i = [0:brick_layers]) {
            translate([0, 0, i * brick_height]) brick_horizontal_groove(width, depth);
            if (i < brick_layers) {
                offset = (i % 2 == 0) ? 0 : brick_width / 2;
                for (j = [0:(bricks_per_layer)]) {
                    if ((margin <= offset + j * brick_width) && (offset + j * brick_width <= width - margin)) {
                        translate([0, offset + j * brick_width, i * brick_height]) brick_vertical_groove(brick_height);
                    }
                }
            }
        }
    } else {
        echo("FAST on; skipping brick texture");
    }
}

module wall(height=HEIGHT, width, windows) {
    window_size = [width/2,height/4];
    if (windows != undef) translate([0,-width/2,0]) position_windows([width, height], windows, operation="PRECUT");
    translate([0,-width/2,0]) {
        difference() {
            cube([WALL_THICKNESS, width, height]);
            if (windows != undef) position_windows([width, height], windows, operation="CUT");
            translate([WALL_THICKNESS,0,0]) brick_cutter(height, width, depth=0.4, margin=0.4);
        }
    }
    if (windows != undef) translate([0,-width/2,0]) position_windows([width, height], windows, operation="ADD");
}

module wall_cutter(height=HEIGHT, radius=RADIUS, sides=SIDES) {
    width = 2*radius * sin(180/sides);
    wall_offset = radius*cos(180/sides) - WALL_THICKNESS;
    linear_extrude(h=height) {
        polygon([[-wall_offset,0], [wall_offset, width], [wall_offset, -width]]);
    }
}

module slanted_wall(height=HEIGHT, width, windows, bottom_thickness=3*WALL_THICKNESS) {
    echo(height=HEIGHT, width=width, windows=windows);

    window_size = [width/2,height/4];
    translate([0,-width/2,0]) {
        difference() {
            //cube([WALL_THICKNESS, width, height]);
            x_scale = WALL_THICKNESS / bottom_thickness;
            linear_extrude(height=height, scale=[x_scale,1]) {
                translate([0,-bottom_thickness/2,0]) square([bottom_thickness,width+bottom_thickness]);
            }
            if (windows != undef) position_windows([width, height], windows, operation="CUT");
        }
    }
    if (windows != undef) translate([0,-width/2,0]) position_windows([width, height], windows, operation="ADD");
}

module tower_sides(height=HEIGHT, radius=RADIUS, sides=SIDES, windows=[]) {
    width = 2*radius * sin(180/sides);
    wall_offset = radius*cos(180/sides) - WALL_THICKNESS;
    angle_step = 360/sides;
    for (i=[0:(sides-1)]) {
        rotate([0,0,i*angle_step]) translate([wall_offset, 0, 0]) {
            wall(height, width, (i<len(windows)) ? windows[i] : undef);
        }
    }
}

module tower_interior() {
    intersection() {
        union() {
            uncut_steps(HEIGHT, STEP_ROTATIONS_DEGREES, STEP_SIZE, TOP_GAP);
            rotate([0,0,-180*3/SIDES]) translate([-WALL_THICKNESS/2,0,0]) cube([WALL_THICKNESS,RADIUS-WALL_THICKNESS/2,HEIGHT]);
        }
        polygon_prism(height=HEIGHT, radius=RADIUS, sides=SIDES);
    }
    translate([0,0,-WALL_THICKNESS]) polygon_prism(height=WALL_THICKNESS, radius=RADIUS, sides=SIDES);
}

module crenulation(size, operation="CUT") {
    if (operation == "CUT") translate([0,-size.x/2,-size.y]) cube([WALL_THICKNESS, size.x, size.y]);
}

/*
    Creates a pyramid with a base as a regular polygon with the specified number of
    sides with the base centered on thr origin

    h - height of pyramid
    r1 - circumscribed radius of base
    r2 - circumscribed radius of _top
    sides - number of sides
    center_offset - offset from center of top polygon
 */
module polygon_pyramid(h, r1, r2, sides=SIDES, real_h=1, center_offset=[0,0]) {
    rotate([0,0,180/SIDES]) translate(center_offset*-r2/r1)
        linear_extrude(height=real_h, scale=r2/r1) translate(center_offset) circle(r1, $fn=SIDES);
}

function distribute(extent=22, size=4.5, count=2, margin=0) =
    let(spacing = (extent - count*size) / (count-1 + 2*margin))
    spacing;

module turret_brick_cutter(extension, radius) {
    extension_height = 4*extension;
    incline_angle = atan((extension-0.5)/extension_height);
    side = (radius) * 2 / sqrt(4+2*sqrt(2));
    offset = side*(1+sqrt(2))/2;
    echo(radius=radius, side=side, offset=offset);
    for (i=[0:45:360]) {
        rotate([0,0,45*i]) translate([offset,-radius/2,0]) rotate([0,incline_angle,0]) brick_cutter(2*extension_height, radius, depth=0.4);
    }
}

module arched_support(width) {
    height = 0.8 * width * 2/sqrt(3);
    thickness = WALL_THICKNESS;
    rotate([90,0,0]) linear_extrude(thickness, center=true) difference() {
        translate([0, height/2]) square([width, width], center=true);
        translate([0, 0.21*width]) arch([width*1.02, height]);
    }
}

module turret_supports(size, offset) {
    echo(size=size);
    skip_support = 7;
    rotate([0,0,45/2]) for (i = [0:7]) {
        if (skip_support != i) {
            rotate([0,0,45*i]) translate([size.x/2 + offset,0,0]) resize([size.x, BAR_THICKNESS, size.y]) {
                arched_support(size.x);
            }
        }
    }
}

module turret(height=TURRET_HEIGHT, thickness=WALL_THICKNESS, extension=5, crenulation_height=3, radius=INSCRIBED_RADIUS) {
    extension_height = 4*extension;
    incline_thickness = thickness;
    interior_inset = 0.9*(radius-INNER_RADIUS);
    _thickness = thickness*1.1;
    hole_offset = [-0.28*interior_inset, 0.28*interior_inset];
    offset_scale = radius-_thickness-interior_inset / radius+extension-_thickness;
    hole_radius = 1.1*(radius-_thickness-interior_inset);
    difference() {
        polygon_pyramid(h=extension_height, r1=radius, r2=radius+extension, SIDES, real_h=extension_height);
        translate([0,0,0.8]) polygon_pyramid(h=extension_height2, r1=hole_radius,
            r2=radius+extension-_thickness, SIDES, real_h=extension_height-0.8,
            center_offset=hole_offset);
        translate([0,0,0]) rotate([0,0,180/SIDES]) translate(hole_offset*-2.24) {
            cylinder(r=hole_radius*1.05, h=extension_height, $fn=30);
        }
        turret_brick_cutter(extension, radius);
    }
    cren_num = 4;
    turret_width = 2*(radius+extension) * sin(180/SIDES);
    cren_size = [turret_width/(2*cren_num-1), crenulation_height];
    //dist = distribute(turret_width, cren_size.x, cren_num-1);
    spacing = distribute(turret_width, cren_size.x, cren_num-1, 0.5);
    dx = 2*(spacing+cren_size.x)/turret_width;
    //x_offset = -0.5 + (cren_size.x/2) / turret_width;
    x_offset = -1.0 + 1.8*spacing/turret_width;
    echo(spacing=spacing, dx=dx, size=cren_size.x);
    crenulation_gaps = [ for (i=range_upto(cren_num-1)) create_window(style="C", size=cren_size, position=[x_offset+i*dx,1]) ];
    wall_gaps = [ for (i=range_upto(SIDES)) crenulation_gaps ];
    echo(wall_gaps=wall_gaps);
    translate([0,0,extension_height]) tower_sides(height=height-extension_height, radius=radius+extension, sides=SIDES, windows=wall_gaps);
}

module tower2() {
    window_size = [WALL_WIDTH/3,2*WALL_WIDTH/3];
    small_window_size = [WALL_WIDTH/8,2*WALL_WIDTH/4];
    door_size = [WALL_WIDTH*0.8,WALL_WIDTH*1.25];
    echo(INSCRIBED_RADIUS=INSCRIBED_RADIUS);
    // create_window(size=door_size,   position=[0,-1], style="D")
    tower_sides(radius=INSCRIBED_RADIUS, windows=[
            [create_window(size=window_size, position=[0,-0.74]),
                create_window(size=small_window_size, position=[-0.45,0.66], style="W"),
                create_window(size=small_window_size, position=[0.45,0.66], style="W")],
            [create_window(size=door_size, position=[0,-1], style="D"),
                create_window(size=small_window_size, position=[-0.45,0.66], style="W"),
                create_window(size=small_window_size, position=[0.45,0.66], style="W"),
                create_window(size=window_size, position=[0,0.01])],
            [create_window(size=window_size, position=[0,-0.74]),
                create_window(size=small_window_size, position=[-0.45,0.66], style="W"),
                create_window(size=small_window_size, position=[0.45,0.66], style="W")],
            [create_window(size=window_size, position=[0,0.01]),
                create_window(size=small_window_size, position=[-0.45,0.66], style="W"),
                create_window(size=small_window_size, position=[0.45,0.66], style="W")],
            [create_window(size=small_window_size, position=[-0.45,0.66], style="W"),
                create_window(size=small_window_size, position=[0.45,0.66], style="W")],
            [create_window(size=window_size, position=[0,0.01]),
                create_window(size=small_window_size, position=[-0.45,0.66], style="W"),
                create_window(size=small_window_size, position=[0.45,0.66], style="W")],
            [create_window(size=small_window_size, position=[-0.45,0.66], style="W"),
                create_window(size=small_window_size, position=[0.45,0.66], style="W")],
            [create_window(size=window_size, position=[0,0.01]),
                create_window(size=small_window_size, position=[-0.45,0.66], style="W"),
                create_window(size=small_window_size, position=[0.44,0.66], style="W")]]);
    tower_interior();
    inner_radius = STEP_SIZE.x/2 - 0.5;
    translate([0,0,HEIGHT-TURRET_SUPPORT_HEIGHT-WALL_THICKNESS]) {
        turret_supports([RADIUS-inner_radius-WALL_THICKNESS, TURRET_SUPPORT_HEIGHT], inner_radius);
    }
    translate([0,0,HEIGHT]) turret();
}

module layout_repeat_texture(size, file, repeat=1) {
    repeat_counts = [repeat, ceil(repeat*size.y/size.x)];
    texture_size = [size.x/repeat_counts.x, size.y/repeat_counts.y, size.z];
    for (i=[0:(repeat_counts.x-1)]) {
        for (j=[0:(repeat_counts.y-1)]) {
            translate([i*texture_size.x,j*texture_size.y,0]) resize(texture_size) surface(file);
        }
    }
}

tower2();

//turret();
//brick_cutter(50, 30);

//intersection() {
    //tower2();
    //turret();
//    #translate([-40,-25,0]) cube([100,35,20]);
//}

//arched_support(RADIUS);
//turret_supports([RADIUS, RADIUS*0.6]);

//tower_interior();
//#slanted_wall(100, 30, [["W", [15,25], [0.0, 0.0]]]);

//position_windows(wall_size = [30, 100], windows = [["W", [15, 25], [0, 0]]], operation = "PRECUT");
//position_windows(wall_size = [30, 100], windows = [["W", [15, 25], [0, 0]]], operation = "CUT");
//position_windows(wall_size = [30, 100], windows = [["W", [15, 25], [0, 0]]], operation = "ADD");
