"""Approved October25/28 blueprint, constructed in final authoring coordinates.

Room connections follow the approved drawing. The photo-derived furniture,
industrial glazing and services dress those connections without relocating them.
The circulation core and right-facing banks retain their placement. The closed
yellow door uses its declared rigid pose exception.
"""
import math
from mathutils import Matrix


WHITE=(.74,.73,.68,1)
BLUE=(.018,.065,.33,1)
INK=(.035,.045,.05,1)
STEEL=(.39,.44,.46,1)
WOOD=(.53,.35,.17,1)
GREY=(.16,.18,.18,1)
RED=(.5,.035,.022,1)


def build_blueprint(layout,b,set_module):
    F=layout['levels']['upper']
    TOP=layout['levels']['upper_ceiling']
    reception=next(room for room in layout['modules'] if room['id']=='Reception')['bounds']
    rx0,ry0,rx1,ry1=reception
    classroom=next(room for room in layout['modules'] if room['id']=='Classroom')['bounds']
    cx0,cy0,cx1,cy1=classroom
    reception_shift=ry0-5.46
    def assembly_frame(placement):
        return (Matrix.Translation(placement['to']) @
                Matrix.Rotation(math.radians(placement['rotation_z_degrees']),4,'Z') @
                Matrix.Translation(tuple(-v for v in placement['from'])))
    def cut_floor(name,rect,z,holes=(),color=(.45,.45,.40,1)):
        pieces=[rect]
        for hole in holes:
            following=[]
            for x0,y0,x1,y1 in pieces:
                a=max(x0,hole[0]);c=min(x1,hole[2])
                d=max(y0,hole[1]);e=min(y1,hole[3])
                if c<=a or e<=d:
                    following.append((x0,y0,x1,y1));continue
                following.extend((r for r in ((x0,y0,a,y1),(c,y0,x1,y1),
                    (a,y0,c,d),(a,e,c,y1)) if r[2]-r[0]>1e-6 and r[3]-r[1]>1e-6))
            pieces=following
        for rect in pieces:b.floor(name,*rect,z,color)

    def door(name,x,y,width,level=F,axis='y',closed=False,double=False,glazed=False):
        # Axis denotes the wall plane: Y=constant or X=constant.
        lo=width/2
        def local_box(suffix,u0,u1,v0,v1,z0,z1,color):
            if axis=='y':b.box(name+suffix,(x+u0,y+v0,z0),(x+u1,y+v1,z1),color)
            else:b.box(name+suffix,(x+v0,y+u0,z0),(x+v1,y+u1,z1),color)
        for u in (-lo,lo):local_box('_jamb',u-.035,u+.035,-.06,.06,level,level+2.55,STEEL)
        local_box('_head',-lo,lo,-.06,.06,level+2.50,level+2.56,STEEL)
        if closed:
            if glazed:
                if axis=='x':b.glazing_x(name+'_closed_leaf',x,y-lo+.04,y+lo-.04,level+.04,level+2.48)
                else:b.glazing_y(name+'_closed_leaf',y,x-lo+.04,x+lo-.04,level+.04,level+2.48)
                for u in (lo-.28,lo-.15):
                    local_box('_handle_mount',u,u+.025,-.06,-.015,level+1.08,level+1.13,STEEL)
            else:
                local_box('_closed_leaf',-lo+.04,lo-.04,-.03,.03,level+.012,level+2.49,WHITE)
                local_box('_inset',-lo+.16,lo-.16,-.037,-.031,level+.30,level+2.15,(.60,.62,.59,1))
            local_box('_handle',lo-.30,lo-.12,-.10,-.045,level+1.08,level+1.13,STEEL)
        elif double:
            # Both leaves hinge into the classroom, clear of the full opening.
            for u in (-lo,lo):b.glazing_x(name+'_open_leaf',x+u,y-width/2+.04,y-.04,level+.06,level+2.46)
        elif axis=='y':
            b.glazing_x(name+'_open_leaf',x-lo,y+.04,y+width-.05,level+.06,level+2.46)
        else:
            b.glazing_y(name+'_open_leaf',y-lo,x+.04,x+width-.05,level+.06,level+2.46)

    holes=[]
    for depth in (11.2,14.2):
        holes.extend([(-2.28,depth,0,depth+1.8),(0,depth+.35,.135,depth+1.45)])
    def cab_floors(level):
        for depth in (11.2,14.2):
            cut_floor('Blueprint_cab_floor',(-2.28,depth,0,depth+1.8),level,
                [(-.195,depth+.35,.135,depth+1.45)],INK)

    # Original central ground geometry: stairs, right ramp, yellow doors,
    # independent brown-door room and right-facing banks retain source placement.
    set_module('Ground_Core')
    b.floor('Ground_foundation',-23,-4.75,25,17.4,-.02)
    b.floor('Street_threshold',-3.32,-4.85,3.32,-4.3,.006)
    cut_floor('Ground_forward_hall_floor',(-6.2,6.24,3.36,17.4),.85,holes)
    cab_floors(.85)
    # Raised wings reach the storefront and perimeter. Solid plinths avoid
    # exposed under-slab slots; the lower entrance/ramp remains unchanged.
    b.box('Ground_large_left_floor',(-23,-4.75,-.16),(-6.2,17.4,.85),(.45,.45,.40,1))
    b.box('Ground_left_front_arm',(-6.2,-4.75,-.16),(-3.36,6.24,.85),(.45,.45,.40,1))
    b.box('Ground_hall_subslab_support',(-6.2,6.24,-.16),(3.36,17.4,.71),(.45,.45,.40,1))
    b.box('Ground_right_floor',(3.36,-4.75,-.16),(24.92,17.32,.85),(.45,.45,.40,1))
    b.wallx('Ground_west',-23,-4.75,17.4,-.16,F)
    b.wallx('Ground_east',25,-4.75,17.4,-.16,F)
    b.wally('Ground_rear',17.4,-23,25,-.16,F)
    b.wallx('Brown_L_outer_wall',-6.1,3,16.8,.85,3.8,doors=[(7.55,9.2)])
    b.wally('Brown_L_front_closure',3,-6.2,-3.32,.85,3.8)
    door('Ground_left_room_door',-6.1,8.375,1.65,.85,'x',True)
    b.wally('Brown_L_back',16.8,-6.1,-2.48,.85,3.8)
    # Fixed bakery observation opening; no invented route from hallway to tenant.
    b.wallx('Bakery_view_wall',3.32,6.3,17.4,.85,F-.14,doors=[(7.55,9.2)],door_height=2.5)
    b.glazing_x('Bakery_observation',3.32,7.55,9.2,1.65,3.35)
    b.box('Bakery_window_sill',(3.24,7.55,.85),(3.40,9.2,1.65))
    b.wallx('Bakery_ramp_backing',3.32,-4.65,6.3,.85,F-.14,doors=[(.85,6.1)],door_height=2.7975)
    b.box('Bakery_long_sill',(3.24,.85,.85),(3.40,6.1,2.1725))
    b.wally('Bakery_retail_backing',-3.6,3.4,25,-.16,F-.14)
    for x in (7,10,13):
        for y in (7,11,14):
            for h in (1.3,1.7,2.1,2.5):b.box('Bakery_rack_shelf',(x,y,h),(x+1.3,y+.65,h+.035),STEEL,metal=.7)
            for dx in (0,1.3):
                for dy in (0,.65):b.box('Bakery_rack_post',(x+dx-.02,y+dy-.02,.85),(x+dx+.02,y+dy+.02,2.7),STEEL,metal=.7)
            for h in (1.36,1.76,2.16):
                for i in range(4):b.cyl('Bread_roll',(x+.2+i*.28,y+.33,h),.10,.09,(.66,.39,.12,1),10)
    for y in (-1.5,1.4,4.3):
        b.box('Bakery_workbench',(4.2,y,.85),(5.8,y+.8,1.72),STEEL,metal=.7)
        b.box('Bakery_worktop',(4.14,y-.04,1.72),(5.86,y+.84,1.79),STEEL,metal=.8)
    # Close both street corner reveals and the plenum above retained low ceilings.
    for x in (-3.28,3.28):b.wallx('Entry_hall_front_return',x,-4.75,-4.3,-.16,F-.14)
    b.box('Entry_plenum_front',(-3.32,-4.61,3.8),(3.32,-4.43,F-.14),WHITE)
    for x0,x1 in ((-23,-3.4),(3.4,25)):
        b.box('Ground_side_ceiling',(x0,-4.75,3.8),(x1,17.4,F-.14),WHITE)
    for a,c in ((10.4,11.55),(12.65,14.55),(15.65,16.8)):
        b.box('Ground_continuous_bank_base',(-.18,a,.85),(.03,c,.98),INK)
    b.box('Ground_bank_upper_closure',(-.18,10.4,3.28),(0,16.8,3.8),WHITE)
    b.box('Ground_bank_back_enclosure',(-2.52,10.4,.85),(-2.36,16.8,3.8),WHITE)
    b.box('Ground_bank_interstitial_infill',(-2.48,13.02,.85),(-.10,14.18,3.8),WHITE)
    b.text('Ground_lift_wayfinding','ELEVATORS',(1.6,16.71,2.95),.18,INK)

    # One structural upper floor, with only real cab/threshold apertures.
    set_module('Upper_Circulation')
    cut_floor('Upper_blueprint_slab',(-23,-4.75,25,17.4),F,holes)
    cab_floors(F)
    b.box('Upper_ceiling',(-23,-4.75,TOP),(25,17.4,TOP+.16),WHITE)
    b.wallx('Upper_east',25,-4.75,17.4)
    b.wallx('Upper_west_front',-23,-4.75,8.8)
    # Shaft enclosures follow the preserved bank, not a relocated service pocket.
    b.box('Lift_shaft_front_return',(-2.5,11.0,F),(.02,11.16,TOP),WHITE)
    b.box('Lift_bank_above_front',(-.18,11.16,F+2.54),(0,16.8,TOP),WHITE)
    b.box('Lift_bank_end_infill',(-2.5,16.04,F),(.02,17.4,TOP),WHITE)
    b.box('Upper_bank_interstitial_infill',(-2.48,13.02,F),(-.10,14.18,TOP),WHITE)
    b.box('Landing_end_sill',(.02,17.32,F),(4.86,17.48,F+.70),WHITE)
    b.box('Landing_end_head',(.02,17.32,F+2.9),(4.86,17.48,TOP),WHITE)
    b.glazing_y('Landing_end_window',17.4,.18,4.70,F+.70,F+2.9,(.45,.56,.59,.08))
    for x in (.18,1.69,3.19,4.70):b.box('Landing_black_mullion',(x-.025,17.34,F+.70),(x+.025,17.38,F+2.9),INK)
    for z in (F+.70,F+1.80,F+2.9):b.box('Landing_black_rail',(.18,17.34,z-.025),(4.70,17.38,z+.025),INK)
    for left,right in ((-6.2,.02),(4.86,25)):
        b.wally('Upper_rear_landing_returns',17.4,left,right)
    b.beam('Landing_pendant_cord',(2.4,14.6,F+2.74),(2.4,14.6,TOP),.008,INK)
    b.cyl('Landing_pendant_shade',(2.4,14.6,F+2.65),.18,.18,INK)
    b.cyl('Landing_pendant_diffuser',(2.4,14.6,F+2.555),.16,.012,(.90,.85,.68,1))
    # The original landing faces the closed white other-room door.
    set_module('Other_Room')
    b.wallx('Other_room_opposite_wall',4.94,ry1,17.4,doors=[(11.55,12.65)])
    door('Opposite_lift_white_door',4.94,12.1,1.1,axis='x',closed=True)
    b.wally('Other_room_front',ry1,4.94,25)
    # Bathroom access is at the END of Hallway1, behind the bank's back wall.
    set_module('Bathrooms')
    for x in (-6.2,-4.35,-2.5):b.wallx('Bathroom_side',x,11.2,17.4)
    b.wally('Bathroom_one_front',11.2,-6.2,-4.35,doors=[(-5.88,-4.88)])
    b.wally('Bathroom_two_front',11.2,-4.35,-2.5,doors=[(-4.02,-3.02)])
    for x in (-5.38,-3.52):
        door('Bathroom_door',x,11.2,1.0,closed=True)
        b.text('Bathroom_sign','RESTROOM',(x,11.09,F+2.66),.13,INK)
    set_module('Upper_Circulation')
    b.wallx('Hallway_one_end',-6.2,8.8,11.2,color=BLUE)
    b.cyl('Cross_hall_white_column',(-.40,10.0,F+1.9),.27,3.8,WHITE)
    b.box('Landing_reception_mat',(-.05,ry1+.05,F+.003),(2.15,ry1+1.1,F+.01),INK)
    bench_box=b.framed(assembly_frame(layout['landing_bench_placement']),b.box)
    bench_box('Landing_bench',(.36,15.5,F+.42),(1.8,15.85,F+.48),INK)
    for x in (.50,1.66):bench_box('Landing_bench_leg',(x-.025,15.53,F),(x+.025,15.82,F+.42),STEEL)

    # Direct reception/classroom connection and open Hallway2 mouth.
    set_module('Classroom')
    b.floor('Classroom_carpet',cx0+.1,cy0+.15,cx1-.1,cy1-.1,F+.008,(.18,.19,.18,1))
    b.wallx('Classroom_west',cx0,cy0,cy1,color=BLUE)
    b.wallx('Classroom_east',cx1,cy0,cy1)
    b.wally('Classroom_shared_reception_wall',cy1,cx0,cx1,doors=[(-.9,1.66)],color=BLUE)
    door('Classroom_direct_double_door',.38,cy1,2.56,double=True)
    set_module('Reception')
    b.floor('Reception_finish',rx0+.08,ry0+.10,rx1-.08,ry1-.08,F+.006,(.67,.67,.61,1))
    separate=next(portal for portal in layout['portals'] if portal['id']=='separate')
    sx,sy,_=layout['anchors'][separate['anchor']]
    width=separate['width']
    b.wallx('Reception_separate_wall',rx1,ry0,ry1,doors=[(sy-width/2,sy+width/2)],color=BLUE)
    door('Separate_room_door',sx,sy,width,axis='x',closed=separate['closed'],glazed=separate.get('glazed',False))
    b.wallx('Reception_west_return',rx0,8.8,ry1)
    for a,c in ((rx0,-.15),(2.25,4.94)):
        b.box('Reception_front_sill',(a,ry1-.08,F),(c,ry1+.08,F+.70),WHITE)
        b.glazing_y('Reception_front_glazing',ry1,a,c,F+.70,F+2.8)
        b.box('Reception_front_head',(a,ry1-.08,F+2.8),(c,ry1+.08,TOP),WHITE)
    b.glazing_y('Reception_entry_transom',ry1,-.15,2.25,F+2.55,F+2.8)
    b.box('Reception_entry_head',(-.15,ry1-.08,F+2.8),(2.25,ry1+.08,TOP),WHITE)
    door('Reception_entry',1.05,ry1,2.4,double=True)
    b.text('Reception_sign','PURSUIT',(1.05,ry1+.105,F+2.92),.18,INK,(math.pi/2,0,math.pi))
    # Hollow desk beside the classroom doors; room for the chair underneath.
    desk_move=Matrix.Translation((0,reception_shift,0))
    desk_box=b.framed(desk_move,b.box)
    desk_box('Reception_counter_top',(2.45,5.86,F+1.0),(4.95,6.72,F+1.07),(.91,.90,.85,1))
    desk_box('Reception_counter_front',(2.5,6.56,F),(4.9,6.66,F+1.0),WHITE)
    for x in (2.5,4.8):desk_box('Reception_counter_side',(x,5.91,F),(x+.1,6.56,F+1.0),WHITE)
    desk_box('Reception_counter_light',(2.7,6.665,F+.35),(4.7,6.68,F+.53),(.10,.68,.42,1),emission=.6)
    b.chair('Reception_staff_chair',3.65,6.0+reception_shift,heading=math.pi)
    desk_box('Reception_monitor',(3.2,6.25,F+1.08),(3.85,6.32,F+1.5),INK)
    b.plant('Reception_plant',rx1-.50,ry1-.45)
    b.egg_chair('Reception_egg_chair',rx1-.95,ry0+.89)
    desk_box('Reception_far_TV',(rx1-.13,5.75,F+1.35),(rx1-.08,6.8,F+2.15),INK)
    desk_box('Reception_far_TV_screen',(rx1-.145,5.80,F+1.40),(rx1-.135,6.75,F+2.10),BLUE)
    for tilt in (-.6,.6):
        points=[]
        for i in range(49):
            t=i*math.tau/48;u=.17*math.cos(t);v=.30*math.sin(t)
            points.append((.38+u*math.cos(tilt)-v*math.sin(tilt),ry0+.10,
                           F+3.15+u*math.sin(tilt)+v*math.cos(tilt)))
        for a,c in zip(points,points[1:]):b.beam('Reception_neon_orbit',a,c,.012,(.12,.72,.84,1))

    # Hallway2 rooms stop at x=-6.2, exactly aligned with Hallway1's end.
    for index,(left,right) in enumerate(((-6.2,-3.9),(-3.7,-1.4)),1):
        set_module('Hall_Room_'+str(index))
        b.floor('Hall_room_floor',left,7,right,8.8,F+.008)
        for x in (left,right):b.wallx('Hall_room_side',x,7,8.8,color=INK)
        b.wally('Hall_room_back',8.8,left,right,color=INK)
        center=(left+right)/2
        b.wally('Hall_room_front',7,left,right,doors=[(center-.5,center+.5)],color=INK)
        door('Hall_room_'+str(index)+'_door',center,7,1.0)
        b.table('Hall_room_worktable',center,8.25,w=1.2,d=.45)
        b.chair('Hall_room_chair',center+.70,7.85,heading=-math.pi/2)
    set_module('Hall_Room_1')
    b.wallx('Hall_rooms_shared_divider_infill',-3.8,7,8.8,color=INK)
    set_module('Larger_Room')
    # One L-shaped separate room reaches the street beside the additional room.
    b.wallx('Separate_front_arm_west',6.9,-4.75,ry0)
    b.wally('Separate_inside_return',ry0,6.9,rx1)
    for x,y in ((10,7.4),(15,7.4),(10,1.2),(16,1.2),(21,1.2)):
        b.table('Separate_room_table',x,y,w=2.0,d=.8)
        b.chair('Separate_room_chair',x,y+.65)
    set_module('Small_Room')
    # Dennis explicitly confirmed this reception connection in the revision.
    additional=next(portal for portal in layout['portals'] if portal['id']=='additional_room')
    ax,ay,_=layout['anchors'][additional['anchor']]
    aw=additional['width']
    b.floor('Additional_room_floor',4.5,-4.6,6.82,ry0-.08,F+.006)
    b.wally('Additional_room_reception_wall',ry0,4.42,6.9,doors=[(ax-aw/2,ax+aw/2)])
    door(additional['mesh_prefix'],ax,ay,aw)
    set_module('Internal_Hall')
    b.text('Hallway_two_display','BUILD · LEARN',(-8.5,ry0+.09,F+1.7),.16,WHITE,(math.pi/2,0,math.pi))
    for y in (-2,2.0,5.8):
        b.table('Hallway_window_worktable',-21.8,y,w=1.5,d=.65)
        b.chair('Hallway_window_chair',-21.8,y+.65)

    # Large indoor commons joins Hallway2 without any door, wall or vestibule.
    set_module('Commons')
    b.floor('Commons_polished_floor',-22.92,8.8,-6.28,17.32,F+.008,(.58,.58,.53,1))
    b.cyl('Commons_blue_round_column',(-15.1,8.8,F+1.9),.24,3.8,BLUE)
    for a,c in ((8.8,9.1),(16.5,17.4)):b.wallx('Commons_west_return',-23,a,c)
    b.box('Commons_west_sill',(-23.08,9.1,F),(-22.92,16.5,F+.7),WHITE)
    b.box('Commons_west_head',(-23.08,9.1,F+2.9),(-22.92,16.5,TOP),WHITE)
    b.glazing_x('Commons_west_window',-23,9.1,16.5,F+.7,F+2.9)
    for y in (10.95,12.8,14.65):b.box('Commons_window_mullion',(-22.965,y-.025,F+.7),(-22.925,y+.025,F+2.9),INK)
    b.wally('Commons_north_wall',17.4,-23,-15.3)
    b.box('Commons_rear_sill',(-15.3,17.32,F),(-6.2,17.48,F+.7),WHITE)
    b.box('Commons_rear_head',(-15.3,17.32,F+2.9),(-6.2,17.48,TOP),WHITE)
    b.glazing_y('Commons_rear_window',17.4,-15.3,-6.2,F+.7,F+2.9)
    # One proper rigid assembly frame moves counters, appliances and island
    # together to the bathroom-side wall confirmed in the walkthrough.
    kitchen_frame=assembly_frame(layout['kitchen_placement'])
    kb=b.framed(kitchen_frame,b.box)
    kc=b.framed(kitchen_frame,b.cyl)
    kbeam=b.framed(kitchen_frame,b.beam)
    kb('Kitchen_charcoal_backing',(-22.9,17.22,F),(-14.9,17.34,TOP),INK)
    for x in (-21,-20,-19,-18,-17,-16):
        kb('Kitchen_base',(x,16.40,F),(x+.94,17.22,F+.88),WHITE)
        kb('Kitchen_upper',(x,16.83,F+1.55),(x+.94,17.22,F+2.3),WHITE)
        kbeam('Cabinet_handle',(x+.72,16.80,F+1.7),(x+.72,16.80,F+2.05),.012,STEEL)
    kb('Kitchen_worktop',(-21.05,16.35,F+.88),(-15.01,17.22,F+.94),(.78,.77,.7,1))
    kb('Fridge',(-22.55,16.15,F),(-21.25,17.15,F+2.2),STEEL,metal=.8)
    kb('Fridge_door_seam',(-21.91,16.12,F+.03),(-21.89,16.15,F+2.17),INK)
    for x in (-22.0,-21.82):kbeam('Fridge_handle',(x,16.09,F+.7),(x,16.09,F+1.6),.018,INK)
    kb('Microwave',(-20.7,16.45,F+.95),(-20.0,17.05,F+1.35),INK)
    kb('Sink',(-18.9,16.43,F+.945),(-18.0,17.05,F+.96),STEEL,metal=.8)
    kbeam('Sink_tap',(-18.4,17.0,F+.95),(-18.4,17.0,F+1.24),.022,STEEL)
    kbeam('Sink_spout',(-18.4,17.0,F+1.24),(-18.4,16.7,F+1.24),.022,STEEL)
    kb('Island_top',(-21,13.9,F+.94),(-16.2,14.9,F+1),(.86,.85,.79,1))
    kb('Island_base',(-20.9,14,F+.08),(-16.3,14.8,F+.15),WHITE)
    kb('Island_recessed_plinth',(-20.78,14.1,F+.008),(-16.42,14.7,F+.09),INK)
    for x in (-20.9,-19.75,-18.6,-17.45,-16.3):kb('Island_divider',(x-.035,14,F+.15),(x+.035,14.8,F+.94),WHITE)
    kb('Island_shelf',(-20.9,14,F+.47),(-16.3,14.8,F+.51),WHITE)
    for x in (-20.2,-19,-17.8,-16.7):
        kc('Island_stool_seat',(x,13.35,F+.68),.22,.055,WHITE)
        for dx in (-.13,.13):kbeam('Island_stool_leg',(x+dx,13.2,F),(x+dx,13.35,F+.65),.018,STEEL)
    b.sofa('Commons_couch',-17.7,13.3,w=2.2,heading=-math.pi/2)
    b.sofa('Commons_armchair',-20.0,14.8,w=.85)
    b.table('Commons_coffee_table',-19.7,12.9,w=1.7,d=.8,h=.42,color=WOOD)
    b.cyl('Commons_round_rug',(-19.7,12.9,F+.016),1.65,.015,(.36,.31,.21,1),32)
    for x,y in ((-20.3,11.2),(-19.0,11.8)):b.cyl('Commons_pouf',(x,y,F+.2),.28,.4,GREY)
    b.table('Commons_dining_table',-17,16.1,w=1.65,d=.85,color=INK)
    for x in (-17.5,-16.5):
        for y in (15.45,16.75):b.chair('Commons_folding_chair',x,y,heading=math.pi if y<16.1 else 0)
    b.plant('Commons_plant',-15.4,16.7)
    for y in (11.8,14.4):
        b.table('Window_worktable',-22.1,y,w=.65,d=1.7)
        b.chair('Window_workchair',-21.4,y,heading=-math.pi/2)
    # Keep the relocated kitchen wall clear; remount art on the solid north wall.
    for i,x in enumerate((-19.2,-16.0)):
        b.box('Commons_wall_art',(x-.5,17.295,F+1),(x+.5,17.325,F+2.1),WOOD)
        b.box('Commons_art_canvas',(x-.44,17.28,F+1.06),(x+.44,17.29,F+2.04),
              ((.22,.38,.29,1),(.71,.58,.21,1))[i])
    b.beam('Donation_rack_bar',(-22.2,17.05,F+1.8),(-21.0,17.05,F+1.8),.025,STEEL)
    for x in (-22.2,-21.0):b.beam('Donation_rack_post',(x,17.05,F),(x,17.05,F+1.8),.025,STEEL)
    for i in range(6):b.box('Donated_clothing',(-22.1+i*.17,16.88,F+.6),(-21.98+i*.17,17.15,F+1.7),(BLUE,INK,WOOD,WHITE)[i%4])
    set_module('Side_Workspace')
    b.table('Side_workstation',-20,10.3,w=1.3,d=.6)
    b.chair('Side_workspace_chair',-20,9.55,heading=math.pi)

    # Shared industrial services are scoped to actual rooms/corridors. Nothing
    # crosses an enclosed room front merely to imitate a photograph.
    for ident,rect in (('Reception',(rx0+.1,ry0+.14,rx1-.1,ry1-.1)),
                       ('Upper_Circulation',(.3,ry1+.1,4.7,16.7)),
                       ('Internal_Hall',(-22.8,ry0+.24,-1.4,6.9)),
                       ('Commons',(-22.8,9.2,-6.4,17.2))):
        set_module(ident);x0,y0,x1,y1=rect
        if x1-x0>y1-y0:
            yc=(y0+y1)/2
            b.box('Room_main_duct',(x0,yc-.18,TOP-.55),(x1,yc+.18,TOP-.22),STEEL,metal=.65)
            b.beam('Room_fire_main',(x0,yc+.45,TOP-.15),(x1,yc+.45,TOP-.15),.025,RED)
            count=max(1,int((x1-x0)/3.5))
            positions=[(x0+(i+.5)*(x1-x0)/count,yc-.3) for i in range(count)]
        else:
            xc=(x0+x1)/2
            b.box('Room_main_duct',(xc-.18,y0,TOP-.55),(xc+.18,y1,TOP-.22),STEEL,metal=.65)
            b.beam('Room_fire_main',(xc+.45,y0,TOP-.15),(xc+.45,y1,TOP-.15),.025,RED)
            count=max(1,int((y1-y0)/3.5))
            positions=[(xc-.3,y0+(i+.5)*(y1-y0)/count) for i in range(count)]
        for x,y in positions:
            b.box('Room_pendant_light',(x-.65,y-.05,TOP-.8),(x+.65,y+.05,TOP-.73),(.86,.83,.66,1))
            for dx in (-.5,.5):b.beam('Room_light_suspension',(x+dx,y,TOP-.73),(x+dx,y,TOP-.02),.008,STEEL)
    # Closed courtyard scenery behind the real exterior commons windows.
    set_module('Exterior_Opposite')
    b.box('Courtyard_neighbor_mass',(-37,5.5,0),(-27,28,16),(.46,.42,.36,1))
    for z in (1.2,5.2,9.2,13.2):
        for y in (6.1,9.9,13.7,17.5,21.3,25.1):b.glazing_x('Courtyard_neighbor_window',-26.94,y,y+2.8,z,z+2.35)
    b.box('Rear_courtyard_neighbor_mass',(-25,26,0),(28,36,16),(.46,.42,.36,1))
    for z in (1.2,5.2,9.2,13.2):
        for x in (-23,-19,-15,-11,-7,-3,1,5,9,13,17,21,25):
            b.glazing_y('Rear_courtyard_neighbor_window',25.94,x,x+2.8,z,z+2.35)
