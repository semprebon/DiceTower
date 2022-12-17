SEGMENT_HEIGHT = 5;
TREAD = 5;      // 1/2 size of smallest die
PASSAGE_RADIUS = 30; // greater than size of largest die
WALL_THICKNESS = 2;


SEGMENT_RADIUS = PASSAGE_RADIUS + WALL_THICKNESS;
SEGMENT_OFFSET = SEGMENT_RADIUS - 2*TREAD;
CENTER_RADIUS = SEGMENT_RADIUS / 2;
TOWER_RADIUS = SEGMENT_RADIUS + SEGMENT_OFFSET;
ANGLE_DELTA = asin(TREAD/SEGMENT_RADIUS);
ROTATIONS = 1;
SEGMENT_COUNT = ROTATIONS*360 / ANGLE_DELTA;

FUDGE = 0.01;

module helix_from_segments(n=20, rotation=ANGLE_DELTA) {
    echo(TOWER_RADIUS=TOWER_RADIUS, SEGMENT_OFFSET=SEGMENT_OFFSET, SEGMENT_RADIUS=SEGMENT_RADIUS);
    for (i = [0:(n-1)]) {
        factor =  0;
        radius = SEGMENT_RADIUS + SEGMENT_OFFSET * factor;
        echo(factor=factor, radius=radius);
        translate([0,0,SEGMENT_HEIGHT*i]) rotate([0,0,rotation*i]) simple_segment(radius=radius);
    }
}

module simple_segment(radius=SEGMENT_RADIUS) {
    local_tread = radius*sin(ANGLE_DELTA);
    hole_size = [2*(radius-WALL_THICKNESS), 2*(radius-local_tread), SEGMENT_HEIGHT+FUDGE];
    offset = TOWER_RADIUS - radius;
    translate([offset,0,SEGMENT_HEIGHT/2]) {
        difference() {
            cylinder(r=radius, h=SEGMENT_HEIGHT, center=true);
            resize(hole_size) cylinder(r=radius, h=SEGMENT_HEIGHT+FUDGE, center=true);
        }
    }
}

module double_segment() {
    translate([SEGMENT_OFFSET,0,SEGMENT_HEIGHT/2]) {
        difference() {
            cylinder(r=SEGMENT_RADIUS, h=SEGMENT_HEIGHT, center=true);
            cylinder(r=SEGMENT_RADIUS-WALL_THICKNESS, h=SEGMENT_HEIGHT+FUDGE, center=true);
        }
        translate([-SEGMENT_RADIUS,0,0]) cylinder(r=CENTER_RADIUS, h=SEGMENT_HEIGHT, center=true);
    }
}

helix_from_segments(n=SEGMENT_COUNT, rotation=ANGLE_DELTA) simple_segment();