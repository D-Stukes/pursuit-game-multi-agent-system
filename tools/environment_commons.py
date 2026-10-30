"""Commons furnishings from Dennis's twelve October 29 room photographs.

The existing shell, kitchen frame and gameplay anchors stay authoritative.
These are estimated furniture placements, not a surveyed reconstruction.
"""
import math

WHITE=(.79,.79,.75,1)
INK=(.035,.04,.045,1)
STEEL=(.39,.43,.45,1)
OAK=(.55,.42,.28,1)
BLUE=(.018,.065,.33,1)
FABRIC=(.13,.14,.15,1)
RED=(.5,.035,.022,1)


def build_photo_commons(layout,b,set_module,kitchen_frame):
    from mathutils import Matrix
    F=layout['levels']['upper'];TOP=layout['levels']['upper_ceiling']
    set_module('Commons')

    def office_chair(name,x,y,heading=0):
        frame=b.framed(Matrix.Translation((x,y,0)) @
            Matrix.Rotation(heading,4,'Z') @
            Matrix.Translation((-x,-y,0)),b.box)
        frame(name+'_seat',(x-.23,y-.22,F+.43),(x+.23,y+.22,F+.50),FABRIC)
        frame(name+'_mesh_back',(x-.23,y+.19,F+.50),(x+.23,y+.24,F+.98),(.10,.12,.13,1))
        for dx in (-.28,.28):
            frame(name+'_arm',(x+dx-.025,y-.14,F+.69),(x+dx+.025,y+.16,F+.73),INK)
            frame(name+'_arm_support',(x+dx-.018,y+.08,F+.46),(x+dx+.018,y+.12,F+.70),STEEL)
        b.cyl(name+'_pedestal',(x,y,F+.27),.035,.35,STEEL)
        for i in range(5):
            angle=i*math.tau/5
            end=(x+.29*math.cos(angle),y+.29*math.sin(angle),F+.065)
            b.beam(name+'_caster_spoke',(x,y,F+.14),end,.018,INK)
            b.cyl(name+'_wheel',end,.042,.065,INK,8)

    def workbench(name,x,y,w=4.8):
        b.box(name+'_white_top',(x-w/2,y-.62,F+.72),(x+w/2,y+.62,F+.77),WHITE)
        for dx in (-w/2+.15,w/2-.15):
            b.box(name+'_steel_leg',(x+dx-.035,y-.48,F+.055),(x+dx+.035,y+.48,F+.72),(.58,.60,.61,1))
            b.box(name+'_steel_foot',(x+dx-.07,y-.55,F+.025),(x+dx+.07,y+.55,F+.065),STEEL)
        b.box(name+'_cable_tray',(x-w/2+.2,y-.07,F+.57),(x+w/2-.2,y+.07,F+.64),INK)
        for dx in (-1.55,0,1.55):
            office_chair(name+'_south_chair',x+dx,y-1.03,math.pi)
            office_chair(name+'_north_chair',x+dx,y+1.03)
        for dx in (-.9,.9):
            b.cyl(name+'_water_bottle',(x+dx,y-.30,F+.89),.035,.24,(.42,.59,.68,1),12)
            b.cyl(name+'_bottle_cap',(x+dx,y-.30,F+1.02),.025,.025,INK,12)

    # Photos 8–12: paired long white desks and wheeled mesh office chairs.
    workbench('Commons_shared_desk_west',-20.0,15.85,4.6)
    workbench('Commons_shared_desk_east',-14.6,15.85,4.4)
    b.box('Commons_wall_display',(-19.1,17.25,F+1.45),(-17.4,17.29,F+2.42),INK)
    b.beam('Commons_display_conduit',(-18.25,17.245,F+.8),(-18.25,17.245,F+1.45),.008,WHITE)
    b.plant('Commons_desk_plant',-22.05,15.8,F+.77)

    def sofa(name,x,y,w=2.6,heading=0):
        frame=Matrix.Translation((x,y,0)) @ Matrix.Rotation(heading,4,'Z') @ Matrix.Translation((-x,-y,0))
        box=b.framed(frame,b.box)
        box(name+'_base',(x-w/2,y-.4,F+.13),(x+w/2,y+.4,F+.43),FABRIC)
        box(name+'_back',(x-w/2,y+.27,F+.43),(x+w/2,y+.43,F+.92),FABRIC)
        for dx in (-w/2,w/2):box(name+'_arm',(x+dx-.065,y-.4,F+.25),(x+dx+.065,y+.4,F+.71),FABRIC)
        for i in range(max(1,round(w/.8))):
            step=w/max(1,round(w/.8));cx=x-w/2+step*(i+.5)
            box(name+'_seat_pad',(cx-step*.47,y-.37,F+.43),(cx+step*.47,y+.25,F+.53),(.19,.20,.21,1))
            box(name+'_back_pad',(cx-step*.47,y+.20,F+.57),(cx+step*.47,y+.32,F+.89),(.18,.19,.20,1))
        for dx in (-w/2+.13,w/2-.13):
            for dy in (-.27,.27):box(name+'_foot',(x+dx-.035,y+dy-.035,F),(x+dx+.035,y+dy+.035,F+.14),STEEL)

    # Hallway wall seating requested beneath the enlarged BUILD · LEARN lettering.
    set_module('Internal_Hall')
    sofa('Hallway_wall_couch',-9.0,4.18,3.4,math.pi)
    set_module('Commons')

    # Photos 3, 6, 7: charcoal sofa backs divide desks from the low lounge.
    sofa('Commons_couch_main',-18.1,13.35,2.8)
    sofa('Commons_armchair_one',-14.65,12.1,.85,-math.pi/2)
    sofa('Commons_armchair_two',-14.65,13.65,.85,-math.pi/2)
    b.table('Commons_coffee_table',-17.65,12.2,w=1.9,d=.75,h=.40,color=(.64,.52,.36,1))
    for x,y in ((-14.55,12.9),):
        b.box('Commons_oak_side_table_top',(x-.28,y-.25,F+.42),(x+.28,y+.25,F+.47),OAK)
        for dx in (-.25,.25):b.box('Commons_oak_side_table_side',(x+dx-.025,y-.25,F),(x+dx+.025,y+.25,F+.42),OAK)
    for x,y in ((-20.6,13.0),(-21.5,13.0)):
        b.cyl('Commons_knitted_pouf',(x,y,F+.20),.27,.40,(.20,.21,.20,1),24)
    # Bare concrete replaces the earlier invented circular lounge rug.

    # Photos 1–3: black dining tables and mixed folding/metal chairs.
    for x,y in ((-21.1,11.3),(-11.45,12.5)):
        b.table('Commons_black_dining_table',x,y,w=1.55,d=.78,color=(.055,.06,.065,1))
        for dx in (-.48,.48):
            for dy in (-.7,.7):b.chair('Commons_metal_dining_chair',x+dx,y+dy,heading=math.pi if dy<0 else 0)

    # Photos 4 and 7: three wood-sided quiet booths. One is open for inspection.
    set_module('Side_Workspace')
    for index,x in enumerate((-14.85,-13.05,-11.25)):
        prefix='Commons_quiet_booth_'+str(index)
        left=x-.78;right=x+.78;back=9.02;front=10.62
        b.floor(prefix+'_carpet',left+.06,back+.06,right-.06,front-.04,F+.012,(.22,.22,.21,1))
        for sx in (left,right):b.box(prefix+'_oak_side',(sx-.035,back,F),(sx+.035,front,F+2.38),OAK)
        b.box(prefix+'_back',(left,back-.035,F),(right,back+.035,F+2.38),WHITE)
        b.box(prefix+'_ceiling',(left,back,F+2.34),(right,front,F+2.40),WHITE)
        b.box(prefix+'_head',(left,front-.04,F+2.22),(right,front+.04,F+2.38),WHITE)
        b.box(prefix+'_front_return',(left,front-.04,F),(left+.30,front+.04,F+2.22),WHITE)
        # Glazed door leaves sit open at 90 degrees in the first booth only.
        if index==0:
            b.glazing_x(prefix+'_open_glass',left+.32,front-.94,front,F+.06,F+2.15)
            for sy in (front-.96,front):b.box(prefix+'_open_stile',(left+.29,sy-.02,F),(left+.35,sy+.02,F+2.22),WHITE)
        else:
            b.glazing_y(prefix+'_closed_glass',front,left+.34,right-.04,F+.08,F+2.15)
            for sx in (left+.32,right):b.box(prefix+'_closed_stile',(sx-.025,front-.04,F),(sx+.025,front+.04,F+2.22),WHITE)
        b.text(prefix+'_label','QUIET ROOM',(x,front+.048,F+2.26),.085,INK,(math.pi/2,0,math.pi))
        b.table(prefix+'_desk',x,back+.27,w=1.20,d=.42,h=.76)
        office_chair(prefix+'_chair',x+.18,back+.72)
        b.box(prefix+'_laptop_base',(x-.25,back+.10,F+.765),(x+.18,back+.36,F+.78),INK)
        b.box(prefix+'_laptop_screen',(x-.25,back+.10,F+.78),(x+.18,back+.13,F+1.07),INK)

    set_module('Commons')
    # Photos 1 and 5: cubby storage, water station and a rolling clothing rack.
    b.box('Commons_blue_storage_wall',(-22.91,9.12,F),(-22.85,11.0,F+2.9),BLUE)
    b.box('Commons_cubby_bottom',(-22.75,9.28,F+.03),(-22.25,10.78,F+.09),WHITE)
    for y in (9.28,9.78,10.28,10.78):b.box('Commons_cubby_divider',(-22.75,y-.025,F+.06),(-22.25,y+.025,F+.85),WHITE)
    b.box('Commons_cubby_top',(-22.75,9.28,F+.85),(-22.25,10.78,F+.91),WHITE)
    b.box('Commons_cubby_shelf',(-22.75,9.28,F+.44),(-22.25,10.78,F+.49),WHITE)
    b.box('Commons_water_station',(-22.66,10.1,F+.91),(-22.32,10.46,F+1.4),INK)
    b.cyl('Commons_water_jug',(-22.49,10.28,F+1.57),.13,.34,(.38,.53,.62,1),20)
    for x in (-21.5,-20.1):
        b.beam('Commons_clothes_rack_upright',(x,9.3,F+.08),(x,9.3,F+1.85),.022,STEEL)
        b.beam('Commons_clothes_rack_foot',(x,9.05,F+.08),(x,9.55,F+.08),.022,STEEL)
        for y in (9.05,9.55):b.cyl('Commons_clothes_rack_wheel',(x,y,F+.045),.045,.05,INK,8)
    b.beam('Commons_clothes_rack_bar',(-21.5,9.3,F+1.82),(-20.1,9.3,F+1.82),.022,STEEL)
    for i in range(8):
        x=-21.36+i*.15
        b.beam('Commons_coat_hanger',(x-.12,9.3,F+1.62),(x,9.3,F+1.78),.009,INK)
        b.beam('Commons_coat_hanger',(x,9.3,F+1.78),(x+.12,9.3,F+1.62),.009,INK)
        b.box('Commons_donated_coat',(x-.06,9.24,F+.65),(x+.06,9.36,F+1.62),[(.26,.28,.31,1),(.24,.17,.13,1),(.10,.26,.15,1),(.65,.56,.43,1)][i%4])
    # Column locations respect the clear entry route around x=-18.
    b.cyl('Commons_blue_storage_column',(-21.95,9.22,F+1.9),.26,3.8,BLUE,24)
    b.cyl('Commons_white_structural_column',(-12.65,13.7,F+1.9),.27,3.8,WHITE,24)

    # Roller shades from photos 8–10 leave daylight visible below them.
    for y in (9.2,11.05,12.9,14.75):
        b.box('Commons_window_roller_shade',(-22.89,y,F+1.43),(-22.87,min(y+1.67,16.4),F+2.87),(.70,.69,.61,1))
        b.beam('Commons_shade_bottom',(-22.86,y,F+1.43),(-22.86,min(y+1.67,16.4),F+1.43),.012,WHITE)
    for x in (-15.12,-12.94,-10.76,-8.58):
        b.box('Commons_rear_roller_shade',(x,17.25,F+1.38),(x+2.0,17.27,F+2.87),(.70,.69,.61,1))

    # Photos 6 and 11: small working objects on the existing kitchen/island.
    kb=b.framed(kitchen_frame,b.box);kc=b.framed(kitchen_frame,b.cyl)
    kb('Coffee_machine',(-17.6,16.55,F+.95),(-17.25,16.96,F+1.38),INK)
    kc('Paper_towel_roll',(-16.9,16.75,F+1.1),.065,.3,WHITE)
    for x in (-16.6,-16.35):kc('Counter_mug',(x,16.7,F+1.0),.055,.12,WHITE)
    for x in (-20.4,-19.25,-18.1):kb('Island_storage_basket',(x-.36,14.1,F+.17),(x+.36,14.65,F+.43),(.47,.42,.32,1))
    for x in (-20.3,-19.1):
        kc('Island_cup_stack',(x,14.35,F+1.12),.055,.24,WHITE)
    kb('Island_red_supply_box',(-17.4,14.1,F+1),(-17.0,14.55,F+1.28),(.55,.025,.03,1))

    # Industrial ceiling: broad segmented trunks, branches, vents and suspended LEDs.
    for y in (11.65,15.65):
        b.box('Commons_duct_trunk',(-22.6,y-.30,TOP-.47),(-6.6,y+.30,TOP-.18),STEEL,metal=.65)
        for x in (-22,-20,-18,-16,-14,-12,-10,-8):
            b.box('Commons_duct_seam',(x-.018,y-.315,TOP-.485),(x+.018,y+.315,TOP-.165),(.28,.32,.34,1),metal=.7)
            b.beam('Commons_duct_hanger',(x,y,TOP-.16),(x,y,TOP-.015),.012,STEEL)
        for x in (-20.4,-14.4,-8.4):
            b.box('Commons_duct_vent',(x-.22,y-.38,TOP-.53),(x+.22,y+.38,TOP-.46),WHITE)
            for dx in (-.14,-.07,0,.07,.14):b.box('Commons_vent_slot',(x+dx-.012,y-.29,TOP-.538),(x+dx+.012,y+.29,TOP-.531),INK)
    b.box('Commons_duct_cross_branch',(-19.7,9.0,TOP-.43),(-19.34,16.95,TOP-.20),STEEL,metal=.65)
    for y in (10.7,13.55,16.55):
        b.beam('Commons_red_fire_main',(-22.6,y+.47,TOP-.11),(-6.6,y+.47,TOP-.11),.025,RED)
        for x in (-20.8,-16.5,-12.2,-7.9):
            b.box('Commons_LED_housing',(x-1.1,y-.045,TOP-.77),(x+1.1,y+.045,TOP-.71),INK)
            b.box('Commons_LED_diffuser',(x-1.08,y-.04,TOP-.785),(x+1.08,y+.04,TOP-.771),(.92,.91,.84,1),emission=.7)
            for dx in (-.8,.8):b.beam('Commons_LED_chain',(x+dx,y,TOP-.71),(x+dx,y,TOP-.02),.007,STEEL)
    # Photo 2's hanging wayfinding, mounted clear of head height.
    b.box('Commons_wayfinding_panel',(-10.6,10.91,TOP-.94),(-8.75,10.96,TOP-.58),BLUE)
    b.text('Commons_wayfinding_text','CONNECTIONS  ←',(-9.68,10.90,TOP-.83),.12,WHITE)

    # Apply the approved top-down study as rigid assembly placements. Authoring
    # coordinates are Z-up; Godot's positive Z movement is negative authoring Y.
    import bpy
    from mathutils import Vector
    approved=layout['commons_photo_revision']['approved_layout']
    bpy.context.view_layer.update()
    for ob in list(bpy.context.scene.objects):
        if ob.type not in ('MESH','FONT'):continue
        name=ob.name
        booth=next((i for i in range(3) if name.startswith(f'Commons_quiet_booth_{i}_')),None)
        if booth is not None:
            old=Vector(((-14.85,-13.05,-11.25)[booth],9.82,F))
            target=Vector(approved['quiet_booth_centres'][booth])
            transform=(Matrix.Translation(target) @
                Matrix.Rotation(-math.pi/2,4,'Z') @ Matrix.Translation(-old))
            ob.matrix_world=transform @ ob.matrix_world
            ob['approved_commons_assembly']='quiet_booth_'+str(booth)
            continue
        for group in approved['translations']:
            if name.startswith(tuple(group['prefixes'])):
                delta=list(group['delta'])
                if group['id']=='dining' and ob.matrix_world.translation.x>=-17:
                    delta[1]=group['east_y']
                ob.matrix_world=Matrix.Translation(delta) @ ob.matrix_world
                ob['approved_commons_assembly']=group['id']
                break
