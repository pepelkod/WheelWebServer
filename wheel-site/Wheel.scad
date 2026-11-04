// =====================================================================
// Parametric bicycle wheel  ->  STL
//
// Every value in the parameter section below can be overridden from
// the command line or the web page:
//   openscad --backend=manifold -D spoke_count=32 -D part=\"rim\" -o out.stl Wheel.scad
//
// The /* [Group] */ headers and "// [min:step:max]" comments are
// OpenSCAD Customizer annotations. The web page reads them to build
// its form, so a new parameter added here shows up on the site with
// no HTML changes.
//
// Changes from the original are marked "CHANGED:".
// =====================================================================

// Included for spokes and centerlock threads (only used when no_threads=false)
use <thread.scad>

/* [Wheel] */
// Which part to build
part = "wheel"; // [wheel:Whole wheel, hub:Hub only, rim:Rim only, spokes:Spokes and nipples]
// Total number of spokes
spoke_count = 24; // [16:4:48]
// Crossings per spoke (0 = radial)
num_crosses = 3; // [0:1:4]

/* [Rim] */
// Rim cross-section source
rim_source = "svg"; // [svg:Rim profile from rim.svg, points:Generated profile]
// Effective rim diameter (mm)
erd = 610; // [400:0.5:660]
// Bead seat diameter (mm) - 622 = 700c, 584 = 650b, 559 = 26in
bsd = 622; // [406:1:635]
// Outside width (mm)
external_width = 26.3; // [15:0.1:45]
// Inside width (mm)
internal_width = 23.0; // [10:0.1:40]
// Depth from spoke bed to bead hook (mm)
depth = 15.8; // [8:0.1:65]

/* [Hub] */
// Front or rear hub
hub_type = "rear"; // [rear:Rear, front:Front]
// Hub body source
hub_source = "generated"; // [generated:Generated flanges, svg:Profile SVG (HopePro4Rear.svg / front_hub.svg)]
// Over-locknut distance (mm) - 100/110 front, 130/135/142/148 rear
// Normal are 130 for old road, 135 for mtb. 142 modern road and mtb. 148 for boost.
old = 142; // [90:1:157]
// Hub center to non-drive (left) flange (mm)
// Less than 1/2 the old, see manufacture spec sheet
nds_dist = 39; // [10:0.5:60]
// Hub center to drive (right) flange (mm)
// Less than 1/2 the old, probably about 1/4 old
ds_dist = 19; // [10:0.5:60]
// Non-drive flange pitch circle diameter (mm)
nds_pcd = 57; // [30:0.5:80]
// Drive flange pitch circle diameter (mm)
ds_pcd = 57; // [30:0.5:80]
// Freehub length (rear only)
freehub_speed = 11; // [10:8-10 speed, 11:11 speed]
// Disc brake mount
brake_mount = "centerlock"; // [none:None, 6bolt:6-bolt (six_bolt.svg), centerlock:Centerlock (centerlock.svg)]

/* [Spokes] */
// Spoke diameter (mm)
spoke_diameter = 2.0; // [1.5:0.1:2.6]
// Use nipple.stl / elbow.stl (true) or the parametric versions (false)
use_stl_parts = false;
// Hub flange thickness (mm)
flange_thickness = 2; // [1.5:0.1:5]
// Flange hole diameter (mm) - used for the order-length estimate
flange_hole = 2.5; // [2:0.1:3]

/* [Quality] */
// Circle smoothness (lower renders faster)
detail = 48; // [16:8:96]

/* [Hidden] */
$fn = detail;
FN = detail;          // CHANGED: was fixed at 80
no_threads = true;    // threads are slow and hidden by the nipple anyway
spoke_head_logo = false; // the "W" needs fonts; leave off for the web build

// ---------------------------------------------------------------------
// VALIDATION                                     CHANGED: was a broken assert
// ---------------------------------------------------------------------
assert(spoke_count % 4 == 0, "spoke_count must be a multiple of 4");
assert(nds_dist < old/2, "nds_dist must be less than half the OLD");
assert(ds_dist  < old/2, "ds_dist must be less than half the OLD");
assert(erd > max(nds_pcd, ds_pcd) + 50, "ERD is too small for the hub flanges");
assert(internal_width < external_width, "internal_width must be less than external_width");

cross_theta = (360 / (spoke_count/2)) * num_crosses;
if (cross_theta >= 90)
    echo(str("WARNING: ", num_crosses, "-cross on ", spoke_count,
             " spokes puts each spoke ", cross_theta,
             " deg around the flange - heads will likely overlap the neighboring spoke."));

// Spoke length as the model builds it, and an order-length estimate
// using the standard formula (subtracts half the flange hole).
function spoke_len(pcd, dist) =
    let(A = erd/2, B = pcd/2,
        C = sqrt(A*A + B*B - 2*A*B*cos(cross_theta)))
    sqrt(C*C + dist*dist);

echo(str("SPOKE_LENGTH_NDS=", spoke_len(nds_pcd, nds_dist)));
echo(str("SPOKE_LENGTH_DS=",  spoke_len(ds_pcd,  ds_dist)));
echo(str("ORDER_LENGTH_NDS=", spoke_len(nds_pcd, nds_dist) - flange_hole/2));
echo(str("ORDER_LENGTH_DS=",  spoke_len(ds_pcd,  ds_dist)  - flange_hole/2));


// ROTATE_ABOUT_PT
// rotate as per a, v, but around point pt
// a: angle to rotate in degrees
// v: vector to rotate about [x,y,z]
// pt: center point of rotation [x,y,z]
module rotate_about_pt(a, v, pt) {
    translate(pt)
        rotate(a,v)
            translate(-pt)
                children();
}


////////////////////////////////////////////////////////////////////////////////////
// SPOKE SECTION
//
// LETTER
// Make a 3d letter appear
// l: letter to write
// letter_size: size_of letter in points?
// letter_height: height in mm
// font: font
// halign: horizontal alignment
// valign: vertical alignment
module letter(l, letter_size=1.5, letter_height=0.5, font, halign="center", valign="center") {
     linear_extrude(height = letter_height) {
        text(l, size = letter_size, font = font, halign = halign, valign = valign, $fn = 16);
     }
}
module nipple_from_stl(){
    import("nipple.stl");
}
module spoke_elbow_from_stl(){
    import("elbow.stl");
}

//  NIPPLE
// length: full length of nipple
// spoke_diameter: size in mm of spoke
// wrench_width: size of wrench flats (mm)
// body_diameter: how big is the round body of the spoke (above the wrench flat)
// head_diamter: how big is the head (above the body)
// body_length: portion of nipple that is NOT head 
// slot_width: width (and depth) of screwdriver slot on top of nipple
module nipple(length=12.1, spoke_diameter=2.0, wrench_width=3.27, body_diameter=3.92, head_diameter=6.0, body_length=9, slot_width=1.5){
      difference(){
        union(){
          rotate_extrude($fn=FN)
            polygon(points=[
                [0,length], [head_diameter/2, length],     // top of head
                [head_diameter/2, body_length*1.15],       // end of head
                [body_diameter/2, body_length],            // in to body
                [body_diameter/2, body_length/1.5],        // to wrench flat
                [wrench_width/4, body_length/1.7],         // in to wrench flat
                [wrench_width/4, 0],                       // bottom of wrench flat
                [0, 0]                                     // across bottom
            ]);
            translate([0,0,body_length/3])
                cube([wrench_width*0.707, wrench_width*0.707, body_length/1.5], center=true); // width of center should be sin(45)
        }
        translate([0, 0, (100/2)+(length-slot_width)])                                                         // up into position
             cube([slot_width, head_diameter, 100], center=true);                                             // screwdriver slot
        translate([0,0,-1])                                                                                                 // move down so it fully bores out hole
            cylinder(d=spoke_diameter, h=100);                                                                     // spoke hole
    }
}

// SPOKE HEAD
// Will be attached to the curve of the spoke
// head_diameter: Diameter of the spoke head
// diameter_spoke: Diameter of the spoke
// extra_length: Amount of extra spoke between the head and the elbow
module spoke_head(diameter_head=5, diameter_spoke=2, extra_length=2){
    head_radius=diameter_head/2;
    offset = head_radius/3;
    subrad = head_radius*(2/3);

    if (spoke_head_logo)    // CHANGED: optional, text() needs fonts
        translate([0, 0, extra_length+offset+0.5])
            letter("W", letter_size=1.5);
    hull(){
     rotate_extrude($fn=FN)
        translate([offset, extra_length, 0])
            intersection(){
                circle(r=subrad);
                polygon(points=[
                    [0,0],
                    [(diameter_spoke/2)-offset,0],
                    [4, 3],
                    [4, 10],
                    [0, 10]
                ]);
            }
    }
    cylinder(d=diameter_spoke, h=extra_length);
}

// SPOKE ELBOW
// Will be attached to the curve and head of the spoke
// Creates an elbow, a short piece of spoke, and then a head
// diameter_spoke: How big diameter is the body of the spoke
// radius_curve: How sharp do it curve
// extra_length: How much extra spoke to add between the curve and the head
module spoke_elbow(diameter_spoke=2, radius_curve=3, extra_length=2){
    translate([-radius_curve,0,0])
        rotate([0,-90,0])
            spoke_head(diameter_spoke=diameter_spoke, extra_length=extra_length);
    translate([-radius_curve,0, radius_curve])                             // move to align with 0,0,0
        rotate([90, 90, 0])                                           // rotate to match spoke
            intersection(){                                             // get just one corner
                translate([0,0,-radius_curve])                  // move down to align with full circle
                    cube(radius_curve*2);                           
                rotate_extrude()                                     // extrude the whole curve (circle ring)
                    translate([radius_curve,0,0])               // shift curve radius away from 0,0,0
                        circle(diameter_spoke/2);               // make a cross section of spoke
            }
}

// SPOKE_THREAD
// A section of threaded spoke
// Not needed for a wheel since the nipple covers the threading.
// Also very slow if adding it to a full wheel.
// Use the global no_thread=true for wheels where  you don't want threads
// diameter: same as spoke.
// pitch: thread pitch
// length: Length of threaded section in mm
// leadin: amount of beveled area as threads start
// global no_threads will render a cylinder only
module spoke_thread(diameter_spoke){
    // CHANGED: plain cylinder when threads are off, so thread.scad is optional
    if (no_threads)
        cylinder(d=diameter_spoke, h=10);
    else
        metric_thread(diameter=diameter_spoke, pitch=0.45, length=10, leadin=1);
}

// SPOKE
// length: Length of spoke in mm
// diameter: Diameter of spoke in mm
module spoke(length, diameter=2.0){
    // calc length of curved part on end
    radius_curve = 3;
    bare_length=length-(radius_curve + 10); // remove bend and threads(10mm)
    union(){
        translate([0, 0, radius_curve])                         // move thread and bare out for bend space
            union(){
                translate([0, 0, bare_length])                  // move thread to end of spoke
                    spoke_thread(diameter*1.1);                 // thread (CHANGED: was 2.2)
                cylinder(h=bare_length, r=diameter/2);	    	// bare spoke
            }
        // (CHANGED) selectable with use_stl_parts
        if (use_stl_parts) spoke_elbow_from_stl();
        else               spoke_elbow(diameter, radius_curve);
    }
}

//////////////////////////////////////////////////////////////////////////////
// HALF_SPOKES
// Create 1/2 of the total spokes for the wheel.  Either the drive side or non-drive side.
// spoke_count: 1/2 total wheel spoke count
// num_crosses: How many other spokes does each cross before hitting hub
// erd:  Effective rim diameter
// pcd:  Pitch circle diameter of the hub flange these will exit from
// dist:  Offset of flange from center of hub
// offset:  Drive side or non-drive side.  If offset is true it shifts the polar alignment by 1/2 of spacing degrees
// flange_thickness: needed to shift the spokes out or in based on if they are head in or head out.
module half_spokes(spoke_count=16, num_crosses=3, erd=605, pcd=57, dist=30, offset=true, flange_thickness=2, spoke_color="#202020", nipple_color="silver"){
    A = erd/2;
    B = pcd/2;
    
    // Spoke spacing is just 360 divided the total number of holes on *this* side of the hub 
    // A 32 hole hub would have 16 holes on the drive side flange 
    // 360 / 16 is 22.5 degrees.
    spoke_spacing=(360/spoke_count); // in degrees
    
    // theta
    // This is the angle made up of the three points. A,B,C w
    //          A is one of the spoke holes in the hub
    //          B is the center of the hub (where the axle is
    //          C is another spoke hole in the hub that is "num_crosses" away from A
    //  An example.  A radial laced wheel would return 0.
    // A 32 spoke wheel would have 16 holes on one side of the hub  360/16 is 22.5 degrees.
    //          So a 2 cross would be  22.5*2 = 45 degrees.
    theta = spoke_spacing*num_crosses;

    // Extra space to ensure spokes don't hit flange
    padded_flange_thickness=flange_thickness*1.75;

    // Calculate spoke length
    C = sqrt( pow(A,2) + pow(B,2) - (2 * A * B * cos(theta)));      // Calculate length of spoke cross angle using pythagorus. 
    spoke_len = sqrt(pow(C,2) + pow(dist,2));                       // Now calc in additional length to include the flare out to the hub flange
    
    // Calc angle to spoke hole (across other spokes)
    // This is the angle the spoke will be.  The three points 
    // are center of hub, rim hole, and hole the spoke will go into  (not including flare)
    cos_cross_angle =  (pow(C,2) + pow(A,2) - pow(B,2))/(2*C*A);
    cross_angle = acos(cos_cross_angle);

    // Angle that the spoke will "flare" out to meet the hub flange.
    // The three points are center of hub, rim hole, and flange dist
    flare_angle_outer = offset ? -atan((dist-padded_flange_thickness)/C) : atan((dist+padded_flange_thickness)/C);
    flare_angle_center = offset ? -atan((dist)/C) : atan((dist)/C);
    flare_angle_offset = flare_angle_outer-flare_angle_center;      // difference between hittin center of flange and outside of flange

    
    // Distance to move the spoke to line up with the spoke hole
    // This is one side of the triangle made up of the center of the hub,
    // the flange hole and the angle theta
    shift_amt = cos(theta) * (B)-3;

    // Loop creating a set of spoke and nipples
    spoke_num=0;
    // (CHANGED) was [0 : 1 : spoke_count], which made one extra spoke on top of spoke 0
    for (spoke_num = [0 : 1 : spoke_count-1]){		// create spokes
        // Angle to rotate around the center axis of the hub. 
        // It spreads the spoke evenly around the wheel
        position_angle = offset ? (spoke_spacing * spoke_num) : ((spoke_spacing * spoke_num) + spoke_spacing/2 ); 
        // This is either -1 or +1.  
        // Used to flip spoke head-in or head-out
        // Also used to alternate between leading spoke and trailing spoke
        even = ((spoke_num % 2) * 2) -1;
        // Flare angle shifts up and down depending on if it is heads-in or heads-out
        flare_angle=flare_angle_center + (even * flare_angle_offset);
        // Cross angle alternates for every spoke
        cross_angle=cross_angle * even;
        // Heads-in heads-out alternate for every spoke
        flip_angle = (90*even)+90;                                   
        // Distribute around wheel
        rotate(a=[0, 0, position_angle])
            // Move out to rim
            translate([shift_amt, 0, 0])
                // Tilt to cross angle
                rotate_about_pt(a=[0, 0, cross_angle], pt=[spoke_len, 0, 0])      
                    // Flare out to hub flange
                    rotate_about_pt(a=[0, flare_angle, 0], pt=[spoke_len, 0, 0])  
                        // The spoke was created vertically along z-axis. 
                        // Lay it down onto x axis (rotate down 90 around y) 
                        rotate(a=[0, 90, 0]){		                          
                            // Spoke only
                            // Flip heads-in or heads-out
                            rotate(a=[0,0,flip_angle])
                                color(spoke_color)
                                    spoke(spoke_len, spoke_diameter);		    // create (CHANGED: was 2)
                            // Nipple only
                            // Move out to end of spoke where it meets rim
                            translate([0,0,spoke_len-8])
                                color(nipple_color)
                                    if (use_stl_parts) nipple_from_stl();
                                    else nipple(spoke_diameter=spoke_diameter);
                        }
    }
}
// SPOKES
// Note we need all the wheel info because we are creating and placing the spokes.
// spoke_count: How many total spokes in the wheel
// num_crosses: For each spoke, how many other spokes does it cross on the same side of the wheel.
// erd: Effective rim diameter.  See RIM erd
// nds_dist: Distance from center of hub to non-drive flange
// nds_pcd: Non-drive pitch circle diameter
// ds_dist: Distance from center of hub to drive side flange
// ds_pcd: Diameter of hole of drive side flange
module spokes(spoke_count=32, num_crosses=3, erd=602, nds_dist, nds_pcd, ds_dist, ds_pcd, flange_thickness=2, spoke_color, nipple_color){
    // calc based on crosses, erd, pcd, flange offset
    nds_spoke_count = spoke_count/2;
    ds_spoke_count = nds_spoke_count;
    
    half_spokes(spoke_count = nds_spoke_count, num_crosses=num_crosses, erd=erd, pcd=nds_pcd, dist=nds_dist, offset=false, flange_thickness=flange_thickness, spoke_color=spoke_color, nipple_color=nipple_color);
    half_spokes(spoke_count = nds_spoke_count, num_crosses=num_crosses, erd=erd, pcd=ds_pcd, dist=ds_dist, offset=true, flange_thickness=flange_thickness, spoke_color=spoke_color, nipple_color=nipple_color);
}

// RIM
// erd: Effective Rim Diameter, or how far is it from nipple across the rim to the other nipple head.
// depth: From nipple head to rim bead
// external_width: How wide is the rim
module rim(erd=602, depth=32, external_width=23){
    translate([0,0,-external_width/2])
    difference(){
        color("white") cylinder(h=external_width, r=(erd+depth)/2);                // the rim
        translate([0, 0, -1]){
            color("silver") cylinder(h=external_width+2, r=erd/2); // cutout the center
        }
    }
}

//////////////////////////////////////////////////////////////////////////////////////
// HUB SECTION
//
// ROUNDED_DISC
// Create a disc with a radiused edge like a hub flange
// disc_radius: Diameter of disc
// thickness: How thick is 1/2 the disc in mm
module rounded_disc(disc_radius, thickness){
    hull(){
        union(){
            translate([0,0,thickness/2])                                // move along Z to be centered
                rotate_extrude()
                    translate([disc_radius,0,0])
                        circle(thickness);                                     //
            translate([0,0,-thickness*4])                               // taper align with flange
                cylinder(r=1, h=thickness*8);                           // make fat taper from middle
        }
    }
}

// FLANGE
// dist: distance from center of hub
// pcd: pitch circle diameter (of holes)
// hole_count: number of holes on THIS flange only (for 32 hole hub, this should be 16)
// offset: Should these holes be offset by 1/2 of a hole spacing
//             On all hubs the holes on the flanges are offset from each other.
// flange_thickness: How thick is the flange (Height of the cylinder)
// flange_diameter_beyond_pcd: How many millimeters bigger is the flange than the pcd
// hole_diameter: Diameter of the holes
module flange(dist=20, pcd=57, hole_count=32, offset=false, flange_thickness=2, flange_diameter_beyond_pcd=4, hole_diameter=2.5){
    flange_diameter=pcd+flange_diameter_beyond_pcd;
    hole_spacing=(360/hole_count); // in degrees

    translate([0,0,dist-(flange_thickness/2)]){
        difference(){
            rounded_disc(flange_diameter/2, flange_thickness);
            // create "hole punches"
            // (CHANGED) was [0 : 1 : hole_count], which punched hole 0 twice
            for (hole_num = [0 : 1 : hole_count-1]){// create spoke holes
                position_angle = offset ? (hole_spacing * hole_num) : ((hole_spacing * hole_num) + (hole_spacing/2) ); 
                rotate([0,0,position_angle])                                    // layout around center
                    translate([0,0,-2])                                             // shift down to cover whole flange
                        translate([0, pcd/2, 0])                                    // hole punch out to edge
                            color("pink") cylinder(h=flange_thickness+4, r=hole_diameter/2);    // single hole punch for spoke.
            }
        }
    }
}

// FREEHUB
// speed: 10 or 11  determines the length of the freehub
module freehub(speed=11){
    inner_radius=16.25;     //16.51;
    outer_radius=17.375;    //16.99;
    spline_count=9;         // 9 splines.  
    position_angle=(360/spline_count);  // 40 degrees per pair of spline grove
    height = (speed==11) ? 36.75 :  34.95; // different heights for 8,9,10 vs 11
    circumference = 2 * PI * inner_radius;  // circumference of inner hub body (not splines)
    spline_angle = 17.8;                                    // width of spline in degrees
    grove_angle = 23.8;                                     // width of grove in degrees
    spline_ratio = spline_angle/(spline_angle+grove_angle);   // 
    spline_width = (circumference/spline_count)* spline_ratio;  // spline width in mm
    base_height=2;                          // how thick is lip at upper edge
    spline_height_diff=1;                   // splines don't reach to edge of freehub
    
    union(){
        translate([0,0,height])
            cylinder(r=outer_radius+1, h=base_height);             // larger base
        
        cylinder(r=inner_radius, h=height);     // inner cylinder
        translate([0,0,spline_height_diff])                              // 
        difference(){
            cylinder(r=outer_radius, h=height-spline_height_diff); // outer to be sliced to make splines
            // (CHANGED) was [0 : 1 : spline_count], which cut groove 0 twice
            for (grove_num = [0 : 1 : spline_count-1]){
                rotate([0, 0, position_angle* grove_num])
                translate([inner_radius-1, -(spline_width/2), -1])
                    if(grove_num == 1){ 
                        cube([3, spline_width*1.5, height+2]);  // wide grove narrow spline
                    }else{
                        cube([3, spline_width, height+2]);      // normal spline cutters
                    }
            }
        }
    }
}


// BRAKE MOUNT 
// NONE (ie rim brake)
// Just fills area with cone
module brake_mount_none(cone_length=6, locknut_diameter=14){
    // cone 
    cylinder(h=cone_length, r1=locknut_diameter/2, r2=locknut_diameter);
} 
// CENTERLOCK 
// Creates a splined centerlock for
// a disc brake hub
module brake_mount_centerlock(length=8){
  difference(){
    union(){
        translate([0,0,(length-2)])
            cylinder(h=2, r=17);
        linear_extrude(height=length-1, center=false, $fn=FN)
            import(file="centerlock.svg");
    }
    translate([0,0, (length/4)]){
        if(no_threads==true){
            cylinder(r=16.5, h=length*2);
        }else{
            metric_thread(diameter=33, pitch=1, length=length);
        }
    }
  }
}
// SIX BOLT
// Create a 6 bolt disc brake mount 
module brake_mount_six_bolt(length=8){
  linear_extrude(height=length, center=false, $fn=FN)
      import(file="six_bolt.svg");
}

// CHANGED: brake_mount parameter now actually selects the mount
// Picks the mount from the global brake_mount: "none", "6bolt", "centerlock"
module brake(length=8){
    if (brake_mount == "6bolt")           brake_mount_six_bolt(length=length);
    else if (brake_mount == "centerlock") brake_mount_centerlock(length=length);
    else if (brake_mount == "none")       brake_mount_none();
}

// LOCKNUT
module locknut(locknut_length=6, locknut_diameter=14, axle_diameter=12){
    difference(){
        cylinder(h=locknut_length, r=locknut_diameter/2, $fn=6);
        translate([0,0,-1])
            cylinder(h=locknut_length+2, d=axle_diameter);
    }
}

// HUB
// Will create a generic hub with specified parameters

// old: Outer locknut distance.  Spacing for hub mm
// nds_dist: Distance from center of hub to non-drive flange
// nds_pcd: Diameter of holes in non-drive flange
// ds_dist: Distance from center to ds flange
// ds_pcd: Diameter of holes in drive side flange
// hole_count: total holes for hub
module rear_hub(old=142, nds_dist=33, nds_pcd=57, ds_dist=19, ds_pcd=57, hole_count=32,
    speed=11, axle_diameter=12, filename="", body_color="#302040"){

    locknut_length=6;
    freehub_base = 2;
    freehub_length = (speed==11) ? 36.75 + freehub_base :  34.95 + freehub_base;
    // fits between the disc mount and the freehub
    body_length= old - ((2*locknut_length) + freehub_length);
    body_diameter = nds_pcd/2;
    locknut_diameter=axle_diameter*1.25;

    ds_locknut_offset =    -(old/2);
    freehub_offset =       -(old/2) + (locknut_length);
    body_offset =          -(old/2) + (locknut_length + freehub_length);
    nds_locknut_offset =    (old/2)-locknut_length;
    brake_length =          (nds_locknut_offset - nds_dist)/2;
    brake_offset =          (brake_length + nds_dist)- brake_length/2;

    difference(){
        union(){
            // create hub from drive size
            translate([0,0,ds_locknut_offset])
                locknut(locknut_length, locknut_diameter);
            translate([0,0,freehub_offset])
               color("silver") freehub(speed);
            color(body_color){
                if(filename!=""){
                     rotate_extrude($fn=FN)
                         import(file=filename);
                }else{
                    translate([0,0,body_offset])
                        cylinder(h=body_length, r=body_diameter/2);
                    translate([0,0,-ds_dist])
                        flange(0, ds_pcd, hole_count/2, offset=true, flange_thickness=flange_thickness, hole_diameter=flange_hole);
                    translate([0,0,nds_dist])
                        flange(0, nds_pcd, hole_count/2, offset=false, flange_thickness=flange_thickness, hole_diameter=flange_hole);
                }
                translate([0,0,brake_offset])
                    brake(brake_length);
            }
            translate([0,0,nds_locknut_offset])
                locknut(locknut_length, locknut_diameter);
        }
        translate([0,0,-old])
            cylinder(h=old*2, d=axle_diameter);
    }
}


// FRONT HUB                                
// HUB_BY_FILENAME
// This is a 1/2 profile of a hub
// with the axle aligned with the y-axis
// The SVG file should be sized by mm to match the hub size
// filename: The name of an SVG file 
module front_hub_by_filename(filename="front_hub.svg", body_color="#302040"){
    color(body_color)
        rotate_extrude($fn=FN)
            import(file=filename);
}


module front_hub(old=100, nds_dist=35, nds_pcd=40, ds_dist=35, ds_pcd=40, hole_count=32,
    axle_diameter=12, filename="", body_color="#302040"){
    locknut_length=6;
    locknut_diameter=axle_diameter*1.25;
    body_length = old - 2*locknut_length;
    body_diameter = min(nds_pcd, ds_pcd)/2;
    brake_length = ((old/2 - locknut_length) - nds_dist)/2;
    brake_offset = (brake_length + nds_dist) - brake_length/2;

    difference(){
        union(){
            translate([0,0,-old/2]) locknut(locknut_length, locknut_diameter);
            translate([0,0, old/2-locknut_length]) locknut(locknut_length, locknut_diameter);
            color(body_color){
                if(filename!=""){
                    rotate_extrude($fn=FN) import(file=filename);
                } else {
                    translate([0,0,-body_length/2])
                        cylinder(h=body_length, r=body_diameter/2);
                    translate([0,0,-ds_dist])
                        flange(0, ds_pcd, hole_count/2, offset=true, flange_thickness=flange_thickness, hole_diameter=flange_hole);
                    translate([0,0,nds_dist])
                        flange(0, nds_pcd, hole_count/2, offset=false, flange_thickness=flange_thickness, hole_diameter=flange_hole);
                }
                if (brake_length > 2)
                    translate([0,0,brake_offset]) brake(brake_length);
            }
        }
        translate([0,0,-old]) cylinder(h=old*2, d=axle_diameter);
    }
}


//////////////////////////////////////////////////////////////////////////////
// RIM SECTION
//
// RIM points should already be positioned out at err (effective rim diameter (erd) / 2)
// rim_points: A set of points to make a polygon that will be extruded into a rim
// already positioned at the correct distance from the position [0, 0, 0]
module rim_by_points(rim_points){
    rotate_extrude($fn=FN)
        polygon(rim_points);
}
// RIM_BY_FILENAME
// This is a cutaway outline of a rim.  The "depth" of the rim should be along
// the x-axis and the "width" of the rim along the y-axis
// The inside edge of the rim (near the spoke holes) should be at (0,0)
// erd: Effective rim diameter.  Still needed to move the shape out to the correct radius
// filename:  A svg file that has a rim "cutaway" shape.  See rim.svg for example
module rim_by_filename(erd=602, filename="rim.svg"){
    err = (erd/2) - 2.5; // the 2.5 is wall thickness.
    rotate_extrude($fn=FN)
        translate([err, 0, 0])
            import(file=filename);
}

// Generated rim profile (used when rim_source = "points")
err = erd/2;
ertor = bsd/2;    // CHANGED: was hard-coded 622
rim_points=[
        [err,0],                                  // spoke-bed center
        [err+4, external_width/2],                // spoke-bed edge
        [err+depth, external_width/2 ],           // rim lip
        [err+depth, internal_width/2],
        [ertor, internal_width/2],
        [ertor, -internal_width/2],
        [err+depth, -internal_width/2],
        [err+depth, -external_width/2],           // lower rim lip
        [err+4, -external_width/2]];              // lower spoke-bed edge


//////////////////////////////////////////////////////////////////////////////
// ASSEMBLY

module hub_part(){
    if (hub_type == "front")
        front_hub(old=old, nds_dist=nds_dist, nds_pcd=nds_pcd, ds_dist=ds_dist, ds_pcd=ds_pcd,
                  hole_count=spoke_count,
                  filename = (hub_source == "svg") ? "front_hub.svg" : "");
    else
        rear_hub(old=old, nds_dist=nds_dist, nds_pcd=nds_pcd, ds_dist=ds_dist, ds_pcd=ds_pcd,
                 hole_count=spoke_count, speed=freehub_speed,
                 filename = (hub_source == "svg") ? "HopePro4Rear.svg" : "");
}

module rim_part(){
    color("SlateGray")
        if (rim_source == "svg") rim_by_filename(erd=erd, filename="rim.svg");
        else                     rim_by_points(rim_points);
}

module spokes_part(){
    spokes(spoke_count=spoke_count, num_crosses=num_crosses, erd=erd,
           nds_dist=nds_dist, nds_pcd=nds_pcd, ds_dist=ds_dist, ds_pcd=ds_pcd,
           flange_thickness=flange_thickness,
           spoke_color="#202020", nipple_color="silver");
}

module wheel(){
    hub_part();
    rim_part();
    spokes_part();
}

if      (part == "hub")    hub_part();
else if (part == "rim")    rim_part();
else if (part == "spokes") spokes_part();
else                       wheel();
