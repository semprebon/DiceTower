SIDES = 8;
/*
    Create a polygonal prism with given circumscribed radius and one side parallel to X axis

    h - height of prism
    r - circumscribed radius
    sides - number of sides
 */
module polygon_prism(h, r, sides=SIDES) {
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
module polygon_pyramid(h, r1, r2, sides=SIDES, center_offset=[0,0], h3) {
    echo("polygon_pyramid:",h=h,r1=r1,r2=r2,sides=sides,center_offfset=center_offset, h3=h3);
    rotate([0,0,180/SIDES]) translate(center_offset*-r2/r1)
        linear_extrude(height=h, scale=r2/r1) translate(center_offset) circle(r1, $fn=SIDES);
}

/*
    The entrance block expands (possibly) the tower shaft.
 */
module create_entrance_block(r1, r2, h1, h2, sides, h3) {
    echo("create_entrance_block:", h1=h1, h2=h2, r1=r1,r2=r2, h3=h3);
    #polygon_pyramid(h=h1, r1=r1, r2=r2, sides=sides, h3=h3);
    translate([0,0,h1]) polygon_prism(h=h2-h1, r=r2, sides);
}

create_entrance_block(h1=5, h2=20, r1=40, r2=45, sides=8, h3=5);
