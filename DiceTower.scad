
include <BOSL/shapes.scad>

// OVERALL
HEIGHT = 165;       // Total height of tower
RADIUS = 40;        // Circumscribed radius of Circle containing tower base
SIDES = 8;          // Number of sides

// FUNDEMENTALS
CLEARANCE = 28;         // Clearance needed for a die (25mm is fine for a single standard d20)
WALL_THICKNESS = 2.0;   // Wall thickness
LAYER_HEIGHT = 0.2;
TOLERANCE = 0.25;

// ENTRANCE
ENTRANCE_HEIGHT = 25;   // Height of turret
ENTRANCE_TYPE = "funnel";   // [funnel, open]

// BAFFlE CHAMBER
STEP_THICKNESS = 3;     // Thickness of step
STEP_RISER = 5;         // Height of step
INNER_RADIUS = 8;       //  Used to compute offset of entry hole - replace
STEP_ROTATIONS_DEGREES = 315;   // angles steps turn through over their full height

// EXIT
EXIT_RAMP_HEIGHT = 25;               // Gap between top of steps and turret
EXIT_RAMP_INSET = 5;

// OUTER WALLS
BAR_THICKNESS = WALL_THICKNESS * 8/12;  // Diameter of bars on windows/doors
OPENING_DEFAULTS = associate(["border", 2, "thickness", 1]);
ARCH_BORDER = 2;        // Width of arch border from opening
ARCH_BORDER_THICKNESS = 1;  // Offset of arch border from
FAST = false;                // Skip texturing og walls
NOMINAL_BRICK_SIZE = [8,3,4];   // Brick pattern size (only x and z used - make 2d?)
ENTRANCE_SUPPORT_HEIGHT = RADIUS * 0.8;   // Height of entrance supports

STEP_SIZE = [INNER_RADIUS, RADIUS, STEP_THICKNESS];

CHAMBER_HEIGHT = HEIGHT - ENTRANCE_HEIGHT;   // Height of tower without turret
STAIR_HEIGHT = CHAMBER_HEIGHT;
WALL_WIDTH = 2*RADIUS*sin(180/SIDES);   // Side length of polygon defining outer walls
TOP_GAP = CLEARANCE;    // Gap between top of steps and turret

$FN = 60;

/*******************************
    SUPPORT FUNCTIONS/MODULES
*******************************/

function range_upto(n) = [0:(n-1)];
function range_for(a) = range_upto(len(a));


/*
    Create an associative array
 */
function associate(values) =
    let (count = len(values)/2)
    [ for (i = [0:2:len(values)-1]) [values[i], values[i+1]] ];

/*
    Get value from association
 */
function get(assoc, key, default=undef) =
    let (p = [ for (pair = assoc) if (pair[0] == key) pair[1] ])
    (p[0] == undef) ? default : p[0];

/*
    Merge two associations, giving the second preference
 */
function merge_associations(a, b) = concat(b,a);

/*
    Compute the distance between evenly spaced objects of a given size
 */
function distribute(extent=22, size=4.5, count=2, margin=0) =
    let(spacing = (extent - count*size) / (count-1 + 2*margin))
    spacing;

/*
    Compute the apothem of a regular polygon with given circumscribed radius and sides
*/
function apothem(r, n) = r*cos(180/n);

/*
    Compute the side length of a regular polygon with given circumscribed radius and sides
*/
function chord(r,n) = 2 * r * sin(180/n);

/*
    Create a polygonal prism with given circumscribed radius and one side parallel to X axis

    h - height of prism
    r - circumscribed radius
    sides - number of sides
 */
module polygon_prism(h, r, sides) {
    rotate([0,0,180/sides]) cylinder(h=h, r=r, $fn=sides);
}

/*
    Creates a pyramid with a base as a regular polygon with the specified number of
    sides with the base centered on threorigin

    h - height of pyramid
    r1 - circumscribed radius of base
    r2 - circumscribed radius of _top
    sides - number of sides
    center_offset - offset from center of top polygon
 */
module polygon_pyramid(h, r1, r2, sides=SIDES, center=[0,0]) {
    translate(center * r2/r1)
        linear_extrude(height=h, scale=r2/r1) {
            translate(-center) rotate([0,0,180/sides]) circle(r1, $fn=sides);
        }
}

//dx = 2;
//r1 = 3;
//r2 = 7;
//x1 = (dx+r1) * r2/r1;
//x2 = (dx-r1) * r2/r1;
//c = (x1 + x2) / 2;
//c = 2*dx * (r2/r1) / 2;
//s = dx * (r2/r1 - 1);
//
//difference() {
//    translate([0,0,0.2]) polygon_pyramid(h=4, r1=r1, r2=r2, sides=SIDES, center=[dx, 0]);
//    #translate([s, 0])  cylinder(h=100, r = 0.2, center=true);
//
//}
//echo(x1=x1,x2=x2,c=c,s=s);

/*
    Create a 2d equilateral arch with base on X axis
 */
module arch(size) {
    curve_offset = size.y - size.x*2/sqrt(3);
    translate([0,curve_offset]) intersection() {
        translate([size.x/2,0]) circle(r=size.x, $fn=60);
        translate([-size.x/2,0]) circle(r=size.x, $fn=60);
        translate([-size.x/2,0]) square([size.x,size.x]);
    }
    translate([-size.x/2,0]) square([size.x,curve_offset]);
}

/*******************
    OBJECTS
********************/

/*
    Defines data for tower as a whole

    h - total height
    r - radius of circumscribed circle (i.e., maximum diagonal)
    sides - number of sides
    turret - data defining turret
 */
function define_tower(h=HEIGHT, r=RADIUS, sides=SIDES, center_radius=0, entrance=[], exit=[], baffle=[],
        windows=[])
    = associate(["h", h, "r", r, "sides", sides, "center_radius", center_radius, "entrance", entrance,
        "exit", exit, "baffle", baffle, "windows", windows,
        "chamber_height", h - get(entrance, "h"),
        "outer_wall_width", 2*r*sin(180/sides),
        "inner_wall_width", 2*(r-WALL_THICKNESS)*sin(180/sides)]);

/*
    Defines data for entrance

    h - entrance height
    extension - amount entrance extends outward from walls TODO: use entrance radius intead?
    crenulation_height - height of crenulations TODO: hardcode?
    relative_offset - offset of center of entry hole relative to radius of entrance
    relative_size - size of entry hole relative to radius of entrance
    angle - angle of offset of entry hole
 */
function define_entrance(type="funnel", h=ENTRANCE_HEIGHT, extension=5,
        crenulation_count=3, crenulation_height=3, circular, wall_height=0,
        relative_offset=0, relative_size=0.5, angle=0, sacrificial_floor=true,
        support_count=0, support_angle_0, support_angle_delta, support_type)
    = associate(["type", type, "h", h, "extension", extension,
        "crenulation_count", crenulation_count, "crenulation_height", crenulation_height, "circular", circular,
        "wall_height", wall_height,
        "relative_offset", relative_offset, "relative_size", relative_size, "angle", angle,
        "sacrificial_floor", sacrificial_floor, "support_type", support_type,
        "support_count", support_count, "support_angle_0", support_angle_0, "support_angle_delta", support_angle_delta]);

function define_exit(type="circular", h=EXIT_RAMP_HEIGHT, steps=10, angle=undef, top_radius=CLEARANCE/2,
        outer_inset=CLEARANCE/2, relative_offset=1)
    = associate(["type", type, "h", h, "steps", steps, "angle", angle, "top_radius", top_radius,
        "outer_inset", outer_inset, "relative_offset", relative_offset]);

function define_interrupter_baffle(levels=3, zmin=ENTRANCE_HEIGHT+CLEARANCE, zmax=CHAMBER_HEIGHT-CLEARANCE,
        count_per_level=undef, tiers=2, column_radius=0, top_gap=0)
    = associate(["type", "interrupter", "levels", levels, "zmin", zmin, "zmax", zmax, "tiers", tiers,
        "count_per_level", count_per_level, "column_radius", column_radius, "top_gap", top_gap,]);

function define_baffle(type="interrupter", column_radius=0, options=[])
    = associate(["type",type, "column_radius", column_radius]);

function define_stairway_baffle(column_radius=INNER_RADIUS, rotation=360, step_thickness=STEP_THICKNESS,
        step_riser=STEP_RISER, top_gap=TOP_GAP)
    = merge_associations(define_baffle(type="stairway", column_radius=column_radius),
        associate(["rotation", rotation, "step_thickness", step_thickness, "step_riser", step_riser,
            "top_gap", top_gap]));


/*******************
    ENTRANCE
********************/

/*
    Create crenulations cutter
 */
module crenulation(size, operation="CUT") {
    if (operation == "CUT") translate([0,-size.x/2,-size.y]) cube([WALL_THICKNESS, size.x, size.y]);
}

/*
    Cut entrance bricks
    TODO: Merge with regual brick cutter?
 */
module entrance_brick_cutter(tower) {
    entrance = get(tower, "entrance");
    height = get(entrance, "h");
    extension = get(entrance, "extension");
    crenulation_height = get(entrance, "crenulation_height");
    sides = get(tower,"sides");
    cren_num = 3;
    wall_width = get(tower, "outer_wall_width");
    radius = get(tower,"r");

    extension_height = extension;
    incline_angle = atan((extension-0.5)/extension_height);
    side = (radius) * 2 / sqrt(4+2*sqrt(2));
    offset = side*(1+sqrt(2))/2;
    for (i=[0:45:360]) {
        rotate([0,0,45*i]) translate([offset,-radius/2,0]) {
            rotate([0,incline_angle,0]) brick_cutter(2*extension_height, radius, depth=0.4);
        }
    }
}

/*
    Create a support arch - used to support entrance floor
 */
module arched_support(width) {
    height = 0.8 * width * 2/sqrt(3);
    thickness = WALL_THICKNESS;
    rotate([90,0,0]) linear_extrude(thickness, center=true) difference() {
        translate([0, height/2]) square([width, width], center=true);
        translate([0, 0.21*width]) arch([width*1.02, height]);
    }
}

module basic_support(width) {
    height = width;
    thickness = WALL_THICKNESS;
    rotate([90,0,0]) linear_extrude(thickness, center=true) {
        translate([width, 0]) polygon([[0,0],[width,-height],[width,0]]);
    }
}

module bar_support(radius) {
    translate([0,-WALL_THICKNESS/2,-WALL_THICKNESS]) cube([radius, WALL_THICKNESS,WALL_THICKNESS]);
}

/*
    Create the entrance floor support
 */
//module entrance_supports(size, offset) {
//    skip_support = 7;
//    rotate([0,0,45/2]) for (i = [0:7]) {
//        if (skip_support != i) {
//            rotate([0,0,45*i]) translate([size.x/2 + offset,0,0]) resize([size.x, BAR_THICKNESS, size.y]) {
//                arched_support(size.x);
//            }
//        }
//    }
//}

module create_entrance_supports(tower) {
    entrance = get(tower,"entrance");
    radius = get(tower,"r");
    sides = get(tower,"sides");
    count = get(entrance,"support_count");
    angle_0 = get(entrance,"support_angle_0", 180/sides);
    angle_delta = get(entrance,"support_angle_delta", 360/sides);
    type = get(entrance,"support_type","bar");
    hole_radius = get(entrance, "relative_size") * radius;

    echo("create_entrance_supports:", count=count, type=type, angle_0=angle_0);
    if (count> 0) {
        for (i = range_upto(count)) {
            rotate([0,0,angle_0 + i*angle_delta]) {
                if (type == "bar") bar(support(radius));
                else if (type == "basic") basic_support(radius - hole_radius - WALL_THICKNESS/2);
                else echo("Invalid support type:", type);
            }
        }
    }
}

/*
    The entrance block expands (possibly) the tower shaft.
 */
module create_entrance_block(r1, r2, h1, h2, sides) {
    //echo("create_entrance_block:", h1=h1, h2=h2, r1=r1,r2=r2);
    polygon_pyramid(h=h1, r1=r1, r2=r2, sides=sides);
    translate([0,0,h1]) polygon_prism(h=h2-h1, r=r2-WALL_THICKNESS, sides=sides);
}

/*
    Create entrance walls
 */
module create_entrance_walls(tower) {
    entrance = get(tower, "entrance");
    height = get(entrance, "h");
    extension = get(entrance, "extension");
    crenulation_height = get(entrance, "crenulation_height");
    wall_height = get(entrance,"wall_height",0);
    sides = get(tower,"sides");
    cren_num = 3;
    wall_width = get(tower, "outer_wall_width");
    radius = get(tower,"r");
    _thickness = WALL_THICKNESS * 1.1;



    extension_radius = radius + extension - _thickness;
    entrance_width = 2*(extension_radius+WALL_THICKNESS) * sin(180/sides);
    cren_size = [entrance_width/(2*cren_num), crenulation_height] / entrance_width;
    //dist = distribute(entrance_width, cren_size.x, cren_num-1);
    x_offset = -1+cren_size.x*2;
    //x_offset = 1.0-cren_size.x;
    dx = 4*cren_size.x;

    crenulation_gaps = [
        for (i = range_upto(cren_num))
            define_opening(type="C", size=cren_size, position=[x_offset+i*dx,1]) ];

    wall_gaps = [ for (i = range_upto(sides)) crenulation_gaps ];
    //echo("create_entrance_walls", wall_gaps=wall_gaps);
    echo("create_entrance_walls", height=height, extension=extension, net=height-extension);
    translate([0,0,extension]) {
        tower_sides(tower, height=height-extension+wall_height, radius=radius+extension, width=entrance_width,
            windows=wall_gaps);
    }
}

module create_entrance_funnel(tower) {
    entrance = get(tower, "entrance");
    echo("create_entrance:", entrance=entrance);
    height = get(entrance, "h");
    radius = get(tower,"r");
    sides = get(tower,"sides");
    circular = get(entrance,"circular", true);
    extension = get(entrance, "extension");
    angle = get(entrance, "angle");
    min_hole_thickness = 0.8;
    floor_height = height - extension;
    wall_height = get(entrance,"wall_height", 0);
    stairway_width = radius - get(tower, "center_radius");
    thickness = WALL_THICKNESS*1.1;
    extension_radius = radius + extension - thickness;
    hole_z_offset = (get(entrance,"sacrificial_floor") ? LAYER_HEIGHT : -LAYER_HEIGHT);
    hole_offset = get(entrance, "relative_offset") * stairway_width  * [cos(angle), sin(angle), 0];
    hole_radius = get(entrance, "relative_size") * stairway_width;
    scaled_hole_offset = -hole_offset * (extension_radius/hole_radius - 1);

    if (hole_radius < CLEARANCE/2) echo(str("***** ENTRANCE HOLE RADIUS", hole_radius, " TOO SMALL"));
    difference() {
        create_entrance_block(r1=radius, r2=extension_radius+thickness,
            h1=extension, h2=floor_height, sides=sides);
        translate([0,0,min_hole_thickness]) {
            polygon_pyramid(h=floor_height-min_hole_thickness, r1=hole_radius,
                r2=extension_radius, sides=sides, center=-hole_offset);
        }
        translate(scaled_hole_offset + [0,0,hole_z_offset]) {
            rotate([0,0,180/sides]) cylinder(r=hole_radius, h=floor_height*2, $fn=circular ? 30 : sides);
        }
    }
}

/*
    Create the entrance
 */
module create_entrance(tower=undef) {
    entrance = get(tower, "entrance");
    extension = get(entrance, "extension");
    radius = get(tower,"r");

    difference() {
        union() {
            create_entrance_funnel(tower);
            create_entrance_walls(tower);
        }
        if (extension > 0) {
            entrance_brick_cutter(tower);
        }
    }
}

/********************
    OPENINGS
********************/

/*
    Create window/door sill - basically a rectangle with a bottom that slants at 45 degrees to eliminate supports
 */
module window_sill(width, height=ARCH_BORDER) {
    w = WALL_THICKNESS;
    t = WALL_THICKNESS + ARCH_BORDER_THICKNESS;
    a = ARCH_BORDER_THICKNESS;
    b = height;
    rotate([0,-90.0]) translate([0,-ARCH_BORDER,0]) linear_extrude(width, center=true) {
        polygon([[0,0],[w,0],[w+a,a],[w+a,b],[0,b]]);
    }
}

module frame_archway(size) {
    rotate([90, 0, 90]) {
        difference() {
            linear_extrude(WALL_THICKNESS + ARCH_BORDER_THICKNESS) arch(size + [ARCH_BORDER, ARCH_BORDER]);
            linear_extrude(WALL_THICKNESS + ARCH_BORDER_THICKNESS + 10) arch(size);
            // since this will be cut, it is redundant?
        }
    }
}

/*
    Used by position_openings() to creates a window on a wall.

    This is done in 3 operations in order:

    PRECUT  - parts are added via union() that will then be cut during the cut operation
    CUT     - The opening is cut using difference
    ADD     - Additional parts are added into the opening (currently, bars)

    TODO: make this more general to make additional openings easy to implement
 */
module window(size, operation, bars=true) {
    if (operation == "PRECUT") {
        frame_archway(size);
        rotate([90, 0, 90]) {
            window_sill(size.x + ARCH_BORDER);
        }
    } else if (operation == "CUT") {
        rotate([90, 0, 90]) linear_extrude(WALL_THICKNESS+ARCH_BORDER_THICKNESS+10) arch(size);
    } else if (operation == "ADD") {
        if (bars) {
            bar_diameter = BAR_THICKNESS;
            num_bars = floor(size.x/(2*bar_diameter));
            gap = (size.x - num_bars*bar_diameter) / (num_bars+1);
            dy = gap + bar_diameter;
            y0 = -size.x/2 + gap + bar_diameter/2;
            if (num_bars > 1) {
                for (i = range_upto(num_bars)) {
                    translate([WALL_THICKNESS/2,y0+i*dy,0]) cylinder(r=bar_diameter/2, h=size.y, $fn=8);
                }
            }
        }
    } else {
        echo("window: Invalid window operation: ", operation);
    }
}

/*
    Used by position_openings() to create a door - basically, like a window with no ADD operation
 */
module door(size, operation) {
    //echo("door:", size=size);
    if (operation == "PRECUT") {
        frame_archway(size);
//        rotate([90, 0, 90]) {
//            translate([0,0.6,0]) window_sill(size.x + ARCH_BORDER, height=ARCH_BORDER-0.6);
//        }
    } else if (operation == "CUT") window(size, operation);
}

/*
    Create a slotted panel with bevels on the y sides
 */
module slotted_panel(size, bevel) {
    echo("slotted_panel", size=size, bevel=bevel);
    translate([0,0,size.z/2]) hull() {
        cube([size.x, size.y-2*bevel, size.z], center=true);
        cube([0.001, size.y, size.z], center=true);
    }
    translate([0,0,size.z/2]) {
        cube([size.x, size.y, size.z], center=true);
    }
}

module grooved_support(size) {
    t = size.x / 2;
    profile = [[-t,t],[t,-t],[t,-size.y],[-t,-size.y],[-t,t]];
    linear_extrude(height=size.z) polygon(profile);
}

module back_door(size, operation) {
    door_thickness = 2;
    overlap = door_thickness/2;
    frame_thickness = door_thickness + TOLERANCE;
    door_size = size + [2*overlap, 0];
    slot_size = door_size + [TOLERANCE,0];
    frame_size = slot_size + [door_thickness, 0];
    bottom_extension = WALL_THICKNESS;

    echo("back door", door_size=door_size, thickness=door_thickness);

    if (operation == "PRECUT") {
        // arch frame
        frame_archway(size);

        // runners for door panel
        translate([-WALL_THICKNESS/2, -slot_size.x/2, -WALL_THICKNESS])
            grooved_support([frame_thickness+0.001, frame_thickness, frame_size.y]);
        mirror([0,1,0]) translate([-WALL_THICKNESS/2, -slot_size.x/2, -WALL_THICKNESS])
            grooved_support([frame_thickness+0.001, frame_thickness, frame_size.y]);

        // stop
        //translate([-WALL_THICKNESS,-frame_size.x/2,frame_size.y-WALL_THICKNESS]) cube([WALL_THICKNESS,frame_size.x,WALL_THICKNESS]);

    } else if (operation == "CUT") {
        // doorway
        translate([-frame_thickness,0,0]) rotate([90, 0, 90])
            linear_extrude(WALL_THICKNESS+ARCH_BORDER_THICKNESS+10) arch(size);
    };


}

module create_dice_door_slot(tower, side) {
    angle = side * 360/get(tower,"sides");
    min_radius = get(tower,"outer_wall_width")/2 * (2/sqrt(2) + 1);
    width = get(tower,"inner_wall_width");
    x_offset2 = min_radius - WALL_THICKNESS*2;
    x_offset = apothem(get(tower,"r"),get(tower,"sides")) - 2*WALL_THICKNESS;
    echo("create_dice_door_slot:", min_radius=min_radius, x_offset=x_offset);

    // slot for door panel
    #rotate([0,0,angle]) translate([x_offset,-width/2,-WALL_THICKNESS]) cube([WALL_THICKNESS,width,WALL_THICKNESS]);
}

/*
    Create the dice door piece
    todo: Use tower data to compute door size
 */
module back_door_panel(tower, door_size) {
    t = door_size.x / 2;
    w = door_size.y / 2;
    poly = [ [-t,w+t], [t,w-t], [t,-w+t],[-t,-w-t] ];
    min_radius = get(tower,"outer_wall_width")/2 * (2/sqrt(2) + 1);
    window_size = [CLEARANCE/2, (1)*CLEARANCE];

    #difference() {
        translate([-min_radius+WALL_THICKNESS*1.5,0,0]) linear_extrude(height=door_size.z) polygon(poly);
        translate([-min_radius,0,(door_size.y+t)/2]) rotate([90, 0, 90])
            linear_extrude(WALL_THICKNESS*2) arch(window_size);

    }
}

WINDOW_STYLE_OFFSET = 0;
WINDOW_SIZE_OFFSET = 1;
WINDOW_RELATIVE_POSITION_OFFSET = 2;


/*
    Conpute the actual position of an opening on the wall
 */
function opening_position(wall_size, window) =
    let(pos = get(window,"position"))
    [0, wall_size.x*(pos.x+1)/2, wall_size.y*(pos.y+1)/2];

/* todo:
    Process the specified operation for all openings
 */
module position_openings(wall_size, windows, operation="CUT") {
    //echo("position_openings:", windows=windows);
    for (w = windows) {
//        if (operation=="CUT") echo("position_openings: cutting", w);
        translate(opening_position(wall_size, w)) {
            if (get(w,"type") == "B") window(get(w,"size"), operation, true);
            else if (get(w,"type") == "W") window(get(w,"size"), operation, false);
            else if (get(w,"type") == "D") door(get(w,"size"), operation);
            else if (get(w,"type") == "S") back_door(get(w,"size"), operation);
            else crenulation(get(w,"size"), operation);
        }
    }
}

function define_opening(type="hole", position=[0,0], size=[10,20], border=2, thickness=1) =
    associate(["type",type, "size",size, "position",position, "border",border, "thickness",thickness]);

/********************
    BRICK TEXTURE
********************/

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
    }
}

module brick_texture_plane(r_offset, angle=0, height, width) {
    difference() {
        children(0);
        children([1:($children-1)]);
        rotate([0,0,angle]) translate([r_offset,0,0]) brick_cutter(height, width, depth=0.4, margin=0.4);
    }
}

/*
    Create a wall with openings and texture
 */
module wall(height, width, windows) {
    //echo("wall:", height=height, width=width, windows=windows);
    sized_windows = (windows == undef)
        ? []
        : [ for (w=windows) merge_associations(w, associate(["size", get(w, "size")*width])) ];

    translate([0,-width/2,0]) {
        if (sized_windows != undef) {
            position_openings([width, height], sized_windows, operation="PRECUT");
        }

        brick_texture_plane(r_offset=WALL_THICKNESS, height=height, width=width) {
            cube([WALL_THICKNESS, width, height]);
            if (sized_windows != undef) position_openings([width, height], sized_windows, operation="CUT");
        }
//        difference() {
//            cube([WALL_THICKNESS, width, height]);
//            if (sized_windows != undef) position_openings([width, height], sized_windows, operation="CUT");
//            translate([WALL_THICKNESS,0,0]) brick_cutter(height, width, depth=0.4, margin=0.4);
//        }

        if (sized_windows != undef) position_openings([width, height], sized_windows, operation="ADD");
    }
}

/*
    Create a slanted wall, as for the entrance
 */
module slanted_wall(height=CHAMBER_HEIGHT, width, windows, bottom_thickness=3*WALL_THICKNESS) {

    window_size = [width/2,height/4];
    translate([0,-width/2,0]) {
        difference() {
            //cube([WALL_THICKNESS, width, height]);
            x_scale = WALL_THICKNESS / bottom_thickness;
            linear_extrude(height=height, scale=[x_scale,1]) {
                translate([0,-bottom_thickness/2,0]) square([bottom_thickness,width+bottom_thickness]);
            }
            if (windows != undef) position_openings([width, height], windows, operation="CUT");
        }
    }
    if (windows != undef) translate([0,-width/2,0]) position_openings([width, height], windows, operation="ADD");
}

/*
    Create tower exterior
 */
module tower_sides(tower, height, width, radius, sides, windows) {
    _h = is_undef(height) ? get(tower, "chamber_height") : height;
    _r = is_undef(radius) ? get(tower, "r") : radius;
    _sides = is_undef(sides) ? get(tower, "sides") : sides;
    _width = is_undef(width) ? get(tower, "outer_wall_width") : width;
    _windows = is_undef(windows) ? get(tower, "widows") : windows;
    wall_offset = _r*cos(180/_sides) - WALL_THICKNESS;
    angle_step = 360/_sides;
    echo("tower_sides:", _width=_width);
    for (i = range_upto(_sides)) {
        rotate([0,0,i*angle_step]) translate([wall_offset, 0, 0]) {
            wall(height=_h, width=_width, windows=_windows[i]);
        }
    }
}

/*************************
    EXIT
*************************/

module slice_exit_ramp(tower) {
    exit = get(tower,"exit");
    echo("slice_exit_ramp:",exit=exit);
    height = get(exit,"h");
    steps = get(exit,"steps");
    radius = get(tower,"r") - WALL_THICKNESS;
    inner_radius = get(exit,"top_radius", default=CLEARANCE/2);
    outer_inset = get(exit,"outer_inset", CLEARANCE/2);
    tower_angle = 360 / get(tower,"sides");
    angle = get(exit,"angle", tower_angle);
    rise = height/steps;

    tread = (radius-outer_inset-inner_radius) / (steps+1);
    r0 = radius - outer_inset;

    echo("slice_exit_ramp:", inner_radius=inner_radius, outer_inset=outer_inset, r0=r0, tread=tread);
    rotate([0,0,-tower_angle/2]) for (i = range_upto(steps)) {
        pie_slice(r=r0 - i*tread, ang=angle, h=(i+1)*rise);
    }
    rotate([0,0,-1*180/SIDES]) {
        translate([0,-WALL_THICKNESS,0]) cube([RADIUS-WALL_THICKNESS/2,WALL_THICKNESS,height]);
        rotate([0,0,angle]) translate([0,0,0]) cube([RADIUS-WALL_THICKNESS/2,WALL_THICKNESS,height]);
    }
}

module turned_steps(tower) {
    step_size = [radius, 2*column_radius, get(baffle,"step_thickness")];
    step_angle = 2 * asin(step_size.y/(2*step_size.x));
    count = ceil(get(baffle,"rotation") / step_angle);
    rise = (height - step_size.z) / count;

    uncut_steps(height=height, sides=sides, step_angle=step_angle, count=count, rise=rise, size=step_size);

}

/*
    Create a stepped cone with bottom radius r0, top radius r2, heigth h, and
    a specified number of steps.
 */
module stepped_cone(r0, r1, h, steps, $fn=60) {
    dh = h / steps;
    dr = (r1 -r0) / steps;
    for (i = range_upto(steps)) {
        rotate  ([0,0,180/$fn]) cylinder(r = r0 + i*dr, h = (i+1)*dh, $fn=$fn);
    }
}

module circular_exit_ramp(tower) {
    exit = get(tower,"exit");
    height = get(exit, "h");
    r = get(tower,"r");
    steps = get(exit,"steps");
    sides = get(tower,"sides");
    r_offset = get(exit,"relative_offset") * r;
//    d = 2*r;
    rise = height/steps;
    tread = 2*r / (steps + 2);
    //r0 = get(tower, "inner_wall_width")/2;
    r_max = r_offset + r - tread;
    r_min = r_offset - apothem(r,sides) + tread;
    //r0 = d-tread;


    //tread = (2*r - r0) / steps;

    difference() {
        cylinder(r=r, h=height);
//        translate([r,0,height]) mirror([0,0,1]) stepped_cone(r0=2*r, r1=r0*(steps-1)/steps, h=height, steps=steps,
//            $fn=get(tower,"sides"));
        echo(r_offset=r_offset)
        translate([r_offset,0,height]) mirror([0,0,1]) stepped_cone(r0=r_max, r1=r_min, h=height, steps=steps);
    }
}

/*
    Create interrputer
 */
module interrupter(length, count) {
    d_angle = 360 / count;
    for (i = range_upto(count)) rotate([0,0,i*d_angle])
        translate([length/2,0,WALL_THICKNESS/2]) cube([length, WALL_THICKNESS, WALL_THICKNESS], center=true);
    //translate([0,0,WALL_THICKNESS]) cube([WALL_THICKNESS, 2*RADIUS, WALL_THICKNESS], center=true);
}

/*
    Create interrepters
 */
module create_interrupter_baffle(tower) {
    baffle = get(tower,"baffle");
    stages = get(baffle,"tiers") - 1;
    zmin = get(baffle,"zmin", get(get(tower, "exit"), "h") + CLEARANCE);
    zmax = get(baffle,"zmax", get(tower, "chamber_height") - CLEARANCE);
    dz = (zmax - zmin) / stages;
    angle_between_interrupters = 720/get(tower,"sides");
    angle_0 = 180/get(tower,"sides");
    d_angle = angle_between_interrupters / 2;
    length = get(tower,"r") - WALL_THICKNESS/2;
    echo("create_interrupter_baffle:", stages=stages, zmin=zmin, zmax=zmax,
        angle_between_interrupters=angle_between_interrupters, d_angle=d_angle,
    count_per_level=get(baffle,"count_per_level"));
    for (i = range_upto(stages)) {
        rotate(angle_0 + i*d_angle) translate([0,0,zmin+i*dz]) {
            interrupter(length, get(baffle,"count_per_level"));
        }
    }

}

/*
    Create steps, including central column
 */
module uncut_steps(height, sides, step_angle, count, rise, size=STEP_SIZE, dr=0) {
    //    step_angle = atan2(size.y, size.x*1.5);
    //    count = ceil(angle / step_angle);
    //    rise = distribute(height, size.z, count);
    //    angle_0 = -180/SIDES + step_angle/2 - atan2(WALL_THICKNESS, RADIUS);
    angle_0 = step_angle/4;
    //z0 = rise - size.z;
    z0 = 0;
    echo(angle_0=angle_0, step_angle=step_angle, count=count, z0=z0,rise=rise);
    rotate(angle_0) for (i = [0:count]) {
        rotate(angle_0 + i*step_angle) translate([0,0,z0+i*rise]) {
            translate([0,-size.y/2,0]) cube(size + [dr,0,0]);
        }
    }
}

/*
    Create stairway baffle
*/
module create_stairway_baffle(tower, height) {
    baffle = get(tower,"baffle");
    radius = get(tower,"r");
    sides = get(tower,"sides");
    column_radius = get(baffle,"column_radius");
    top_gap = get(baffle, "top_gap");
    rotation = get(baffle,"rotation");
    stair_height = height - top_gap;
    // steps
    step_size = [radius, 2*column_radius, get(baffle,"step_thickness")];
    step_angle = 2 * asin(step_size.y/(2*step_size.x));
    count = ceil(rotation / step_angle);
    rise = (stair_height - step_size.z) / count;
    tower_angle = 360/sides;
    exit_angle = get(get(tower,"exit"), "angle", tower_angle);
    start_angle = exit_angle - tower_angle/2;

    echo("create_stairway_baffle:", baffle=baffle, stair_height=stair_height, angle=get(baffle,"rotation"),
        step_size=step_size, height=height);

    rotate([0,0,start_angle]) {
        // top wall
        if (top_gap > 0) {
            wall_base =  rotation * rise/step_angle + WALL_THICKNESS;
            echo("create_stairway_baffle:", wall_base=wall_base);
            rotate([0,0,rotation+1*180/sides]) translate([0,-WALL_THICKNESS,wall_base]) {
                cube([radius-2*WALL_THICKNESS, WALL_THICKNESS, height-wall_base]);
            }
        }

        uncut_steps(height=stair_height, sides=sides, step_angle=step_angle, count=count, rise=rise,
                size=step_size);
    }

    // landing wall
    wall_height =  360*(sides-1.5)/sides * rise/step_angle;
    rotate([0,0,-1*180/sides]) translate([0,-WALL_THICKNESS,0]) {
        cube([radius-WALL_THICKNESS/2, WALL_THICKNESS, wall_height]);
    }
}

/*
    Create baffle
 */
module create_baffle(tower, height) {
    baffle = get(tower,"baffle");
    radius = get(tower,"r");
    sides = get(tower,"sides");
    if (get(baffle, "type") == "stairway") {
        create_stairway_baffle(tower, height);
    } else if (get(baffle,"type") == "interrupter") {
        create_interrupter_baffle(tower);
    } else if (get(baffle,"type") == "open") {
        ;
    } else {
        echo("baffle: Invalid baffle type:", get(baffle,"type"));
    }
}

function side_has_dice_door(windows) = len([ for (w = windows) if (get(w,"type") == "S") w ]) > 0;

function dice_door_side(sides) =
    [ for (i = range_for(sides)) if (side_has_dice_door(sides[i])) i ][0];

/*
    Create tower interior (steps, central column, etc
 */
module tower_interior(tower) {
    //echo(tower=tower);
    chamber_height = get(tower, "chamber_height");
    radius = get(tower, "r");
    sides = get(tower, "sides");
    inner_radius = get(tower, "center_radius");
    entrance = get(tower, "entrance");
    baffle = get(tower, "baffle");
    echo(baffle=baffle);
    column_radius = get(baffle,"column_radius");
    exit = get(tower,"exit");
    exit_ramp_height = get(exit,"h");
    entrance_support_count = get(entrance, "entrance_support_count");
    windows = get(tower,"windows");
    top_gap = get(baffle,"top_gap",0);

    // floor
    difference() {
        translate([0,0,-WALL_THICKNESS]) polygon_prism(h=WALL_THICKNESS, r=radius, sides=sides);
        s = dice_door_side(windows);
        echo("tower_interior:", s=s, side=side_has_dice_door(windows[4]), side=windows[4]);
        if (s) create_dice_door_slot(tower, s);
    }

    intersection() {
        union() {
            // entrance supports
            #translate([0,0,chamber_height]) create_entrance_supports(tower);

            // stairs/baffle
            translate([0,0,exit_ramp_height]) {
                #create_baffle(tower, chamber_height - get(exit, "h"));
            }

            echo("tower_interior:", exit_ramp_height=exit_ramp_height);
            // exit ramp
            if (exit_ramp_height != 0) {
                if (get(exit,"type") == "circular") circular_exit_ramp(tower);
                else if (get(exit,"type") == "slice") slice_exit_ramp(tower);
                else echo("tower_interior: Invalid parameter", type=get(exit,"type"));
            }

            // column
            if (column_radius > 0) {
                cylinder(r=column_radius, h=chamber_height-top_gap, $fn=60);
            }
        }
        polygon_prism(h=chamber_height, r=radius-WALL_THICKNESS/2, sides=sides);
    }
}

/***********************
    OPENING PLACEMENT FUNCTIONS
***********************/

/*
    Determine if an item is in a vector
 */
function is_in(v, list) = len(search(v, list)) > 0;

function arrange_openings_in_tier(y, count, size, margin=0, type="W") =
    let(
        separation = (2.0 - count * size.x - 2*margin) / (count+1),
        x0 = -1.0 + margin + separation + size.x/2,
        dx = size.x + separation)
    [ for (i = range_upto(count)) define_opening(size=size, position=[x0+i*dx, y], type="W") ];

/*
    Return a function to decide whether to place a door on a given side
 */
function define_door(sides=[0], size=[0.9,1.25], type="D") =
    function (side, tier, y) (is_in(side,sides) && tier == 0)
        ? [ define_opening(size=size, position=[0,-1], type=type) ]
        : [];

/*
    Return a function to decide how many arched wi999ndows to place on a given side/tier
 */
function define_arch_windows(sides=undef, tiers=undef, count=1, size=[0.4,0.5], dy=0, margin=0) =
    function (side, tier, y)
//        echo("define_arch_windows:", side=side, tier=tier, y=y, dy=dy)
        (is_in(side,sides) && is_in(tier, tiers))
            ? arrange_openings_in_tier(y=y+dy, count=count, size=size, margin=margin)
            : [];

function concat_each(result, i, lists) =
    (i == len(lists)) ? result : concat_each(concat(result, lists[i]), i+1, lists);

function arrange_openings(sides, tiers, functors, y0=-1) =
    let (dy = (1.0-y0) / tiers)
    echo("arrange_openings:", sides, tiers, y0=y0, dy=dy)
    [ for (side = range_upto(sides))
        concat_each([], 0,
            [ for (tier = range_upto(tiers))
              concat_each([], 0, [ for (f = functors) f(side, tier, y0+tier*dy) ]) ] ) ];

function define_array_of_windows(rows=3, cols=3, size=[0.2, 0.6], margin=2, y0=0.1) =
    let(dx = distribute(2.0, size.x, cols, margin))
    let(x0 = margin + dx)
    let(dy = distribute(2.0, size.y, rows, 0))
    [ for (r=range_upto(rows)) for (c=range_upto(cols))
        let(x = x0 + c*dx)
        let(y = y0 + r*dy)
        define_opening(type="W", size=size, position=[x,y]) ];
/*
[ Wall = [
    [["type", "D"], ["size", [0.8, 1.25]], ["position", [0, -1]], ["border", 2], ["thickness", 1]],
    [["type", "W"], ["size", [0.4, 0.66]], ["position", [5.55112e-17, -0.333333]], ["border", 2], ["thickness", 1]]],
  Wall 2= [],
    [[["type", "W"], ["size", [0.33, 0.66]], ["position", [-2.77556e-17, -0.8]], ["border", 2], ["thickness", 1]], [["type", "W"], ["size", [0.4, 0.66]], ["position", [5.55112e-17, -0.333333]], ["border", 2], ["thickness", 1]]], [], [[["type", "W"], ["size", [0.4, 0.66]], ["position", [5.55112e-17, -0.333333]], ["border", 2], ["thickness", 1]]], [], [[["type", "W"], ["size", [0.4, 0.66]], ["position", [5.55112e-17, -0.333333]], ["border", 2], ["thickness", 1]]], [[["type", "W"], ["size", [0.33, 0.66]], ["position", [-2.77556e-17, -0.8]], ["border", 2], ["thickness", 1]]]]
 */

function renessance_openings(sizes, sides, floors=4, dx=0.65, dy=0.8, y0=0.0) =
    let(
        front_openings = concat(
            [ for (i=range_upto(floors-1)) define_opening(size=sizes[1], position=[-dx, y0+i*dy], type="W") ],
            [ for (i=range_upto(floors-1)) define_opening(size=sizes[1], position=[0,   y0+i*dy], type="W") ],
            [ for (i=range_upto(floors-1)) define_opening(size=sizes[1], position=[dx,  y0+i*dy], type="W") ],
            [define_opening(size=sizes[0], position=[0,-1], type="D")]),
        side_openings = concat(
            [ for (i=range_upto(floors-1)) define_opening(size=sizes[1], position=[-dx, y0+i*dy], type="W") ],
            [ for (i=range_upto(floors-1)) define_opening(size=sizes[1], position=[0,   y0+i*dy], type="W") ],
            [ for (i=range_upto(floors-1)) define_opening(size=sizes[1], position=[dx,  y0+i*dy], type="W") ]))

    concat([front_openings], [ for (i=range_upto(sides-1)) side_openings ]);

function simple_openings(sizes, sides) =
    let(
        front_openings = [
            define_opening(size=sizes[0], position=[0,-1], type="D"),
            define_opening(size=sizes[1], position=[0,0.66], type="W")],
        side_openings = [ for (i = range_upto(sides)) define_array_of_windows() ])
    concat([ front_openings ], [ for (i=range_upto(sides-1)) side_openings ]);

function just_a_door(size=[0.8,1.0]) = [[define_opening(size=size, position=[0,-1], type="D")]];

/*
    Create a simple tower with a few windows
 */

module create_tower(tower) {
    tower_sides(tower,  windows=get(tower, "windows"));
    tower_interior(tower);
    translate([0,0,get(tower,"chamber_height")]) create_entrance(tower);
}

module gate(size) {
    echo("gate:", size=size);
    door_size = size -4*WALL_THICKNESS*[2, 2];
    union() {
        linear_extrude(height=2*WALL_THICKNESS, center=false) {
            difference() {
                arch(size);
                translate([0,WALL_THICKNESS]) arch(door_size);
            }
        }
        bar_radius = WALL_THICKNESS*0.75;
        separation = (door_size.x - 4*2*bar_radius) / 5;
        dx = 2*bar_radius + separation;
        x0 = -door_size.x/2 + separation * bar_radius;
        rotate([-90,0,0]) for (i=range_upto(4)) {
            h = size.y*0.65;
            translate([x0+i*dx,-WALL_THICKNESS,0]) cylinder(r=bar_radius,h=h,$fn=12);
        }
    }
}

module oval_prism(r, h, l, sides, sides2) {
    d = is_undef(l) ? 0 : l - 2*apothem(r, sides) + WALL_THICKNESS;
    _sides2 = is_undef(sides2) ? sides : sides2;
    a = 180/sides;
    a2 = 180/_sides2;
    echo("oval_prism:", d=d)
    translate([-d/2,0,0]) hull() {
        rotate([0,0,a]) cylinder(r=r, h=h, $fn=sides);
        if (d > 0) translate([d,0,0]) rotate([0,0,a2]) cylinder(r=r, h=h, $fn=_sides2);
    }
}

module coffin_base(r, h, l, sides) {
    a = 180/sides;
    width = chord(r,sides);
    y_offset = h*tan(360/sides);
    width_at_height = width + 2*y_offset;
    echo(h=h, y_offset=y_offset, r=r,l=l,width_at_height=width_at_height);
    r_min = apothem(r,sides);
    l2 = l - r_min;
    hull() {
        translate([apothem(r,sides)-l/2,0,0]) rotate([0,0,a]) cylinder(r=r, h=h, $fn=sides);
        #translate([0,0,h/2]) cube([l,width_at_height,h], center=true);
    }
}

module base(type, r, h, l, sides) {
    if (type == "coffin") coffin_base(r,h,l,sides);
    else if (type == "oval") oval_prism(r,h,l,sides);
    else echo("Invalid base type:", type=type);
}

/*
    Create enclosing tray
 */
module create_enclosing_tray(tower, length, h=15, back_door=false, type="coffin", gate=false) {
    r = get(tower,"r");
    sides = get(tower,"sides");
    tower_wall_width = get(tower,"outer_wall_width");
    wall_width = tower_wall_width + 3*WALL_THICKNESS;
    r0 = r + TOLERANCE;
    r1 = r0 + WALL_THICKNESS;
    separation = length - 2*apothem(r0, sides);
    l0 = 2*r0 + separation;
    echo("create_tray:",r0=r0,r1=r1);

    //%cube([length,r0,r0], center=true);
    difference() {
        //oval_prism(r=r1, h=h, sides=sides, sides2=8, d=separation);
        base(type, r=r1, h=h, sides=sides, l=length+2*WALL_THICKNESS);
        //#translate([0,0,2*LAYER_HEIGHT]) base(type, r=r0, h=h, sides=sides, l=length);
        x_offset = apothem(r0,sides);
        translate([-length/2,0,x_offset+WALL_THICKNESS]) rotate([0,90,0])
            polygon_prism(r=r0, h=length, sides=sides);
        translate([-(length/2)+apothem(r0,sides),0,WALL_THICKNESS]) polygon_prism(r=r0, h=length-2*WALL_THICKNESS, sides=sides);
//        #translate([length/2,-wall_width/2,0]) cube([WALL_THICKNESS, wall_width, h]);
        if (back_door) {
            translate([-apothem(r1, sides),-tower_wall_width/2,WALL_THICKNESS]) cube([WALL_THICKNESS,tower_wall_width,h]);
        }

    }
    if (gate) {
        translate([length/2-WALL_THICKNESS/2,0,0]) rotate([90,0,90]) {
            gate([wall_width, 2*apothem(r,sides)]);
        }
    }

//    difference() {
//        oval_prism(r=r1, h=h, sides=sides, d=0);
//        translate([0,0, 2*LAYER_HEIGHT]) {
//            oval_prism(r = r0, h = h, sides = sides, d = 0);
//            translate([apothem(r0,sides), -wall_width/2, 0]) cube([WALL_THICKNESS, wall_width, h]);
//            translate([-apothem(r1, sides),-tower_wall_width/2,WALL_THICKNESS]) cube([WALL_THICKNESS,tower_wall_width,h]);
//        }
//    }


}

/*
    Create simple tray
 */
module create_simple_tray(tower, length, h=15, back_door=true, type="oval", gate=false) {
    r = get(tower,"r");
    sides = get(tower,"sides");
    tower_wall_width = get(tower,"outer_wall_width");
    wall_width = tower_wall_width + 3*WALL_THICKNESS;
    r0 = r + TOLERANCE;
    r1 = r0 + WALL_THICKNESS;
    separation = length - 2*apothem(r0, sides);
    l0 = 2*r0 + separation;
    echo("create_tray:",r0=r0,r1=r1);

    //%cube([length,r0,r0], center=true);
    difference() {
        base(type, r=r1, h=h, sides=sides, l=length+2*WALL_THICKNESS);
        translate([0,0,WALL_THICKNESS]) base(type, r=r0, h=h, sides=sides, l=length);
        x_offset = apothem(r0,sides);
        translate([-(length/2)+apothem(r0,sides),0,WALL_THICKNESS]) polygon_prism(r=r0, h=length-2*WALL_THICKNESS, sides=sides);

        // gate opening
        if (gate) {
            translate([(length+WALL_THICKNESS)/2,-wall_width/2,0]) cube([WALL_THICKNESS, wall_width, h]);
        }

        // backdoor opening
        if (back_door) {
            translate([-length/2-1.5*WALL_THICKNESS,-tower_wall_width/2,WALL_THICKNESS]) cube([WALL_THICKNESS,tower_wall_width,h]);
        }

    }
    if (gate) {
        translate([(length-WALL_THICKNESS)/2,0,0]) rotate([90,0,90]) {
            gate([wall_width, 2*apothem(r,sides)]);
        }
    }

    translate([apothem(r1,sides)-length/2-1.5*WALL_THICKNESS,0,0]) difference() {
        oval_prism(r=r1, h=h, sides=sides);
        translate([0,0, 2*LAYER_HEIGHT]) {
            oval_prism(r=r0, h=h, sides=sides);
            translate([apothem(r0,sides), -wall_width/2, 0]) cube([WALL_THICKNESS, wall_width, h]);
            translate([-apothem(r1, sides),-tower_wall_width/2,WALL_THICKNESS]) cube([WALL_THICKNESS,tower_wall_width,h]);
        }
    }


}

/*
    Test Models
 */
module half_plane(axis, max) {
    translate(max*axis) cube([2*max,2*max,2*max], center=true);
}

module exit_test_model(tower, angle, x_offset, z_offset, slice=true) {
    r = get(tower,"r");
    h = get(tower,"h");
    sides = get(tower,"sides");
    exit = get(tower,"exit");
    _angle = is_undef(angle) ? 180/sides : angle;
    _x_offset = is_undef(x_offset) ? -WALL_THICKNESS/sin(_angle/2) : x_offset;
    _z_offset = is_undef(z_offset) ? get(tower,"outer_wall_width")*1.5 : z_offset;
    difference() {
        children();
        //tower_sides(tower);
        if (slice) translate([_x_offset,0,0]) {
            rotate([0, 0, -_angle]) half_plane([0,-1,0], h);
            rotate([0, 0, _angle]) half_plane([0,1,0], h);
        }
        translate([0,0,_z_offset]) half_plane([0,0,1], h);
    }
}

module dice_door_test_model(tower, z_cut=60) {
    r = get(tower,"r");
    h = get(tower,"h");
    sides = get(tower,"sides");
    exit = get(tower,"exit");
    angle = 180/sides;
    w = get(tower,"outer_wall_width");
    min_radius = w/2 * (2/sqrt(2) + 1);

    echo(r=r, w=w, min_radius=min_radius);
    difference() {
        create_tower(tower);
        translate([-min_radius+5*WALL_THICKNESS,0,0]) {
            half_plane([1,0,0], h);
        }
        #translate([0,0,z_cut]) half_plane([0,0,1], h);
    }
}

phi=0.5*(sqrt(5)+1); // golden ratio

// create an icosahedron by intersecting 3 orthogonal golden-ratio rectangles
module icosahedron(edge_length) {
    st=0.0001;  // microscopic sheet thickness
    hull() {
        cube([edge_length*phi, edge_length, st], true);
        rotate([90,90,0]) cube([edge_length*phi, edge_length, st], true);
        rotate([90,0,90]) cube([edge_length*phi, edge_length, st], true);
    }
}

module d20() {
    translate([0,0,13*phi/2]) icosahedron(13);
}

echo("********************* STARTING RUN ********************************");
//tower_entrance = define_entrance(type="funnel", entrance_support_height=0);
//tower = define_tower(h=120, r=40, sides=8, entrance=tower_entrance, center_radius=8);
//echo(tower=tower);
//simple_tower(tower);

//tower_interior(tower);

//original_tower();
// zmin = 50, zmax = 115

watchtower_openings = arrange_openings(tiers=3, sides=8, y0=-1.2,
        functors = [
            define_door(sides=[0], size=[0.8,1.6]),
            define_door(sides=[4], size=[0.8,1.6], type="S"),
            define_arch_windows(sides=[1,7], tiers=[0], size=[0.3,0.6], dy=0.3),
            define_arch_windows(sides=[0,2,4,6], tiers=[1], size=[0.4,0.8], dy=0.20),
            define_arch_windows(sides=[0,1,2,3,4,5,6,7], tiers=[2], size=[0.3,0.6], count=2, dy=0.42, margin=-0.2) ]);

watch_tower = define_tower(h=165, r=40, sides=8, center_radius=4,
        entrance = define_entrance(type="funnel",
                support_count=4, support_angle_0=30, support_angle_delta=100, extension=8,
                relative_size=0.4, relative_offset=0.26, angle=0, h=25, sacrificial_floor=false,
                crenulation_count=3),
        exit = define_exit(type="slice", steps=8, h=10, angle=45*1.5, outer_inset=5, top_radius=15),
        baffle = define_stairway_baffle(column_radius=4, step_thickness=5.5, step_riser=5, rotation=180,
                top_gap=20),
        windows = watchtower_openings);

//create_tower(watch_tower);
create_simple_tray(tower=watch_tower, length=165, h=30, back_door=true);
//back_door_panel(watch_tower, [1.8, 26.3, 69]);
//exit_test_model(watch_tower);

/*
r2/r1 = extension_radius/hole_radiu = 45.8/16 = 229/80 ~ 229/80 = 2*3*19/16*5
actual scale factor = ~1.87 = 187/100 = 911*17/100
hole_radius = rel_hol_w * starway+size =0.4*32=12.8


relative_size=0.5 r2/r1 = 45.8/16 scale =  ~1.87 = 187/100 = 11*17/100
relative_size=0.4 r2/r1 = 45.8/12.8 scale = 83/32


stairway_width = 32, ratio = 45.8/16 = 229/80
rel_offset = 0, hole_offset = [0, 0, 0], scaled_hole_offset = [0, 0, 0]; obs 0 err 0
rel_offset = 0.2, hole_offset = [6.4, 0, 0], scaled_hole_offset = [7.68, 0, 0] obs ~11 err ~3.3
rel_offset = 0.4, h6ole_offset = [12.8, 0, 0], scaled_hole_offset = [15.36, 0, 0] oba=24 err=8.6 s=1.85
rel_offset = 0.5, hole_offset = [16, 0, 0], scaled_hole_offset = [19.2, 0, 0] obs~29  err ~
rel_offset = 1, hole_offset = [32, 0, 0], scaled_hole_offset = [38.4, 0, 0]
 */
//simple_tower = define_tower(h=100, r=30, sides=6, center_radius=0,
//    entrance=define_entrance(type="funnel", extension=0,
//        relative_size=0.5, h=10),
//    exit = define_exit(type="circular", steps=8),
//    baffle = define_interrupter_baffle(tiers=3, zmin=59.5, zmax=107),
//    windows = simple_openings(sizes=[[0.9,1.4], /* door */, [0.33,0.66]], sides=6));

portable_tower = define_tower(h=120, r=30, sides=6, center_radius=0,
    entrance=define_entrance(type="funnel", extension=0, support_type="basic", support_count=6,
        relative_size=0.5, h=10),
    exit = define_exit(type="circular", steps=8),
    baffle = define_interrupter_baffle(tiers=3, zmin=59.5, zmax=107),
    windows = renessance_openings(sizes=[[0.9,1.4], /* door */, [0.21,0.75]],
        sides=6, floors=4, dx=0.65, dy=0.43, y0 = -0.3));

// todo: margin shouldn't be needed for centering multiple windows with even spacing
aerie_tower_openings = arrange_openings(tiers=4, sides=6, y0=-0.90,
    functors = [
        define_door(sides=[0], size=[0.8,1.2]),
        define_arch_windows(sides=[1,5], tiers=[0], size=[0.35,0.6], count=2, dy=0.15, margin=-0.2),
        define_arch_windows(sides=[0,1,2,3,4,5], tiers=[1,2,3], size=[0.35,0.84], count=2, dy=0.03, margin=-0.2)]);

aerie_tower = define_tower(h=150, r=35, sides=6, center_radius=3,
    entrance=define_entrance(type="funnel", extension=0, relative_size=0.5, h=10, wall_height=5,
        crenulation_height=0, circular=false, support_type="basic", support_count=6),
    exit = define_exit(type="circular", steps=12, h=26),
    baffle = define_interrupter_baffle(tiers=4, zmin=13.5, zmax=113.5, column_radius=3, count_per_level=3,
            top_gap=CLEARANCE),
    windows = aerie_tower_openings);

//create_tower(aerie_tower);
//tower_interior(aerie_tower);
//exit_test_model(aerie_tower, slice=true, z_offset=42, angle=30) {
//    rotate([0,0,120]) create_tower(aerie_tower);
//}
//translate([18,0,16]) d20();

//stepped_cone(r0=50, r1=10, h= 30, steps=5);
//create_tray(tower=watch_tower, length=158, h=20, back_door=false);
//back_door_panel(watch_tower, [1.8, 26.3, 69]);
//exit_test_model(watch_tower);


//mini_tower = define_tower(h=100, r=15, sides=4, center_radius=0,
//    entrance=undef,
//    exit = define_exit(type="circular", steps=8),
//    baffle = define_side_baffles(tiers=3, zmin=45, zmax=90));
//create_tower(mini_tower);

//circular_exit_ramp(simple_tower);

//exit_ramp();
//tower_open_interior();
//tower_interior(tower);

//entrance(relative_offset=0);
//brick_cutter(50, 30);

//intersection() {
    //tower();
    //entrance();
//    #translate([-40,-25,0]) cube([100,35,20]);
//}

//arched_support(RADIUS);
//entrance_supports([RADIUS, RADIUS*0.6]);

//#slanted_wall(100, 30, [["W", [15,25], [0.0, 0.0]]]);

//position_openings(wall_size = [30, 100], windows = [["W", [15, 25], [0, 0]]], operation = "PRECUT");
//position_openings(wall_size = [30, 100], windows = [["W", [15, 25], [0, 0]]], operation = "CUT");
//position_openings(wall_size = [30, 100], windows = [["W", [15, 25], [0, 0]]], operation = "ADD");
