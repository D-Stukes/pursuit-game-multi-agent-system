"""Rebuild the connected lift arrival in final Blender world coordinates.

Called once after the original room-plan reflection. The retained lift geometry
receives one rigid move; the photographed stairs, ramp and classroom stay intact.
"""
import math

import bpy
from mathutils import Matrix


def rebuild_arrival(layout, scene, box, floor, wallx, wally,
                    glazing_x, glazing_y, beam, cyl, text, set_module):
    floor_height = layout['levels']['upper']
    ceiling = layout['levels']['upper_ceiling']
    white = (.74, .73, .68, 1)
    blue = (.018, .065, .33, 1)
    ink = (.035, .045, .05, 1)
    steel = (.39, .44, .46, 1)
    wood = (.53, .35, .17, 1)
    removed = []

    def remove(ob):
        removed.append(ob.name)
        bpy.data.objects.remove(ob, do_unlink=True)

    def erase(prefixes):
        for ob in list(scene.objects):
            if ob.name.startswith(prefixes):
                assert ob.get('retained_source_kind') != 'classroom', ob.name
                remove(ob)

    # The former lounge was a speculative room blocking the new public approach.
    # Remove its complete candidate shell/decor; never change the pinned source.
    erase(('Brown-room', 'Brown room', 'Left room', 'Room left', 'Room back',
           'Room right', 'Left area east rear closure', 'Left area west skirting',
           'Left area north skirting', 'Left area south skirting',
           'Left area suspended light', 'Left area light', 'Forecourt north skirting',
           'Elevator forecourt north wall', 'Elevator forecourt ceiling',
           'Corrected room light', 'Corrected room diffuser',
           'Ramp continuation ceiling', 'Ramp continuation light',
           'Ground black bank base'))

    # Ground bank wall/call-station pieces were historically tagged "ground".
    # Move them with the cabins so no duplicate station remains at the old shaft.
    bank_front_prefixes = (
        'Ground white bank wall', 'Ground bank upper lintel',
        'Ground central brushed call plate', 'Ground call display', 'Ground round call',
        'Ground stainless bin', 'Ground bin dark rim', 'Ground generic bin label',
        'Ground recycle metal lid', 'Ground recycle aperture')
    move = (Matrix.Translation((-15.5, 4.7, 0)) @
            Matrix.Rotation(math.pi / 2, 4, 'Z') @
            Matrix.Translation((.95, -12.1, 0)))
    bank_objects = []
    for ob in list(scene.objects):
        if (ob.get('retained_source_kind') in ('bank', 'bank_trim') or
                ob.name.startswith(bank_front_prefixes)):
            ob.matrix_world = move @ ob.matrix_world
            ob['arrival_rigid_move'] = 'Rz90 old(-.95,12.1) to(-15.5,4.7)'
            bank_objects.append(ob.name)
    bpy.context.view_layer.update()

    set_module('Upper_Circulation')
    # A non-overlapping four-rectangle slab union leaves only the declared shaft.
    for name, x0, y0, x1, y1 in [
        ('west', -23, -4.75, -20.8, 17.4),
        ('east', -14.4, -4.75, 25, 17.4),
        ('south', -20.8, -4.75, -14.4, 3.15),
        ('north', -20.8, 5.79, -14.4, 17.4),
    ]:
        floor('Arrival_upper_slab_' + name, x0, y0, x1, y1, floor_height)
    for center in (-18.5, -15.5):
        floor('Arrival_upper_cab', center-.9, 3.37, center+.9, 5.65,
              floor_height, ink)
        floor('Arrival_upper_threshold', center-.9, 5.65, center+.9, 5.79,
              floor_height, steel)
    # Fill every non-cab portion of the rectangular shaft cutout. In particular,
    # rotating the old 0.6 m north-end pit must not recreate it beside the window.
    solid_bank_spans = [(-20.8, -19.4), (-17.6, -16.4), (-14.6, -14.4)]
    for left, right in solid_bank_spans:
        floor('Arrival_upper_bank_endcap', left, 3.15, right, 5.79, floor_height)
        box('Arrival_upper_bank_infill', (left, 5.79, floor_height),
            (right, 5.95, ceiling), white)
    for center in (-18.5, -15.5):
        floor('Arrival_upper_cab_backstrip', center-.9, 3.15, center+.9, 3.37,
              floor_height, ink)
    wallx('Retired_landing_closure', 2.6, 9.95, 10.45)

    # The bank is fully enclosed behind and above its retained front. The cap
    # closes the former 8.0 m lintel-to-ceiling slot without stretching its mesh.
    for x in (-20.8, -14.4):
        wallx('Arrival_shaft_side', x, 3.15, 5.79, floor_height, ceiling)
    wally('Arrival_shaft_back', 3.15, -20.8, -14.4, floor_height, ceiling)
    wally('Arrival_south_corridor_wall',5.79,-14.4,-4,floor_height,ceiling)
    for center in (-18.5, -15.5):
        box('Arrival_bank_upper_cap', (center-.9, 5.79, floor_height+2.95),
            (center+.9, 5.95, ceiling), white)

    # The old west wall must be cut, not hidden behind a decorative glass plane.
    wallx('Upper_west_south', -23, -4.75, 5.79)
    wallx('Upper_west_north', -23, 8.1, 17.4)
    box('Arrival_end_sill', (-23.08, 5.79, floor_height),
        (-22.92, 8.1, floor_height+.65), white)
    box('Arrival_end_head', (-23.08, 5.79, floor_height+2.9),
        (-22.92, 8.1, ceiling), white)
    window_low,window_high=6.0,7.86
    for low,high in ((5.79,window_low),(window_high,8.1)):
        box('Arrival_end_white_return',(-23.08,low,floor_height+.65),
            (-22.92,high,floor_height+2.9),white)
    glazing_x('Arrival_end_window', -23, window_low, window_high,
              floor_height+.65, floor_height+2.9, (.45,.56,.59,.08))
    for y in (window_low,window_low+.62,window_low+1.24,window_high):
        box('Arrival_end_black_mullion',(-22.965,y-.025,floor_height+.65),
            (-22.925,y+.025,floor_height+2.9),ink)
    for z in (floor_height+.65,floor_height+1.78,floor_height+2.9):
        box('Arrival_end_black_rail',(-22.965,window_low,z-.025),
            (-22.925,window_high,z+.025),ink)

    # Blue-backed glazing is a closed shallow room envelope on the NORTH side.
    # It reads on the left after turning right out of the north-facing lift.
    glass_bays = [(-22.6, -19.8), (-19.4, -16.6), (-16.2, -13.4),
                  (-13.0, -10.2), (-9.8, -7.0)]
    cursor = -23
    for left, right in glass_bays:
        box('Arrival_glazing_pier', (cursor, 8.02, floor_height),
            (left, 8.18, ceiling), white)
        box('Arrival_glazing_sill', (left, 8.02, floor_height),
            (right, 8.18, floor_height+.72), white)
        box('Arrival_glazing_head', (left, 8.02, floor_height+2.75),
            (right, 8.18, ceiling), white)
        glazing_y('Arrival_blue_glazing', 8.1, left, right,
                  floor_height+.72, floor_height+2.75)
        cursor = right
    box('Arrival_glazing_pier', (cursor, 8.02, floor_height),
        (-5.5, 8.18, ceiling), white)
    box('Arrival_blue_room_backing', (-23, 8.49, floor_height),
        (-5.5, 8.65, ceiling), blue)
    # Butt the end returns to the glazing/backing edges; overlapping centered
    # walls left coplanar white/blue end faces visible from the restroom branch.
    for left,right in ((-23.16,-23),(-5.5,-5.34)):
        box('Arrival_blue_room_end',(left,8.02,floor_height),
            (right,8.65,ceiling),white)
    box('Arrival_corridor_duct', (-22.92, 6.5, ceiling-.50),
        (-4.2, 6.84, ceiling-.20), steel, metal=.65)
    beam('Arrival_fire_main', (-22.92, 7.35, ceiling-.14),
         (-4.2, 7.35, ceiling-.14), .025, (.50, .035, .022, 1))
    for x in (-21, -17, -13, -9, -5):
        cyl('Arrival_pendant_stem', (x, 6.95, ceiling-.38), .012, .7, ink)
        cyl('Arrival_pendant_shade', (x, 6.95, ceiling-.75), .16, .08, steel)
        cyl('Arrival_pendant_diffuser', (x, 6.95, ceiling-.798), .13, .025,
            (.88, .84, .68, 1))
    # Photographed arrival landmarks stay against the walls, clear of the aisle.
    cyl('Arrival_reception_column',(-5.0,7.69,floor_height+1.9),.22,3.8,white)
    box('Arrival_reception_mat',(-5.4,6.08,floor_height+.002),
        (-4.08,7.25,floor_height+.008),ink)
    box('Arrival_bench_seat',(-8.7,7.72,floor_height+.43),
        (-7.4,7.98,floor_height+.48),ink)
    for x in (-8.58,-7.52):
        box('Arrival_bench_leg',(x-.025,7.75,floor_height),
            (x+.025,7.95,floor_height+.43),steel)
    cyl('Arrival_extinguisher',(-6.1,7.87,floor_height+.47),.09,.58,(.55,.02,.015,1))
    box('Arrival_extinguisher_handle',(-6.18,7.82,floor_height+.77),
        (-6.02,7.90,floor_height+.83),ink)
    for center in (-18.5,-15.5):
        box('Arrival_upper_cab_diffuser',(center-.58,3.8,floor_height+2.79),
            (center+.58,4.02,floor_height+2.805),(.9,.88,.75,1),emission=1.2)

    set_module('Ground_Core')
    # Existing retained landing/ramp cover x[-3.2,3.1], y<=6.24. These three
    # additions abut them instead of laying another coplanar floor over them.
    for name, x0, y0, x1, y1 in [
        ('west', -23, 5.79, -3.2, 8.1),
        ('east', -3.2, 6.24, 3.35, 8.1),
        ('ramp_edge', 3.1, 5.79, 3.35, 6.24),
    ]:
        floor('Arrival_ground_approach_' + name, x0, y0, x1, y1, .85)
    for center in (-18.5, -15.5):
        floor('Arrival_ground_cab', center-.9, 3.37, center+.9, 5.65, .85, ink)
        floor('Arrival_ground_threshold', center-.9, 5.65, center+.9, 5.79, .85, steel)
    for left, right in solid_bank_spans:
        floor('Arrival_ground_bank_endcap', left, 3.15, right, 5.79, .85)
    for center in (-18.5, -15.5):
        floor('Arrival_ground_cab_backstrip', center-.9, 3.15, center+.9, 3.37, .85, ink)
    # Solid skirts reach the ground under every raised public edge. The south
    # wall prevents stepping off the .85 m platform into an inaccessible void.
    box('Arrival_platform_skirt', (-23, 5.65, -.02), (-3.2, 5.79, .85), white)
    for left, right in [(-23, -19.4), (-17.6, -16.4), (-14.6, -3.36)]:
        box('Arrival_ground_tenant_boundary', (left, 5.79, .85),
            (right, 5.95, floor_height-.14), white)
    for center in (-18.5, -15.5):
        box('Arrival_ground_bank_cap', (center-.9, 5.79, 3.28),
            (center+.9, 5.95, floor_height-.14), white)
    for x in (-20.8, -14.4):
        wallx('Arrival_ground_shaft_side', x, 3.15, 5.79, .85, floor_height-.14)
    wally('Arrival_ground_shaft_back', 3.15, -20.8, -14.4, .85, floor_height-.14)
    wally('Arrival_ground_north', 8.1, -23, 3.35, .85, floor_height-.14)
    # A continuous soffit covers the approach, replacing the speculative lounge.
    box('Arrival_ground_soffit', (-23, 5.79, floor_height-.16),
        (3.35, 8.1, floor_height-.14), white)
    box('Arrival_ground_duct',(-22.6,6.35,floor_height-.63),
        (2.7,6.69,floor_height-.30),steel,metal=.65)
    beam('Arrival_ground_fire_main',(-22.6,7.25,floor_height-.28),
         (2.7,7.25,floor_height-.28),.025,(.50,.035,.022,1))
    for x in (-20,-15,-10,-5,1):
        for y in (6.28,7.45):
            beam('Arrival_ground_light_suspension',(x,y,floor_height-.17),
                 (x,y,floor_height-.76),.009,steel)
        box('Arrival_ground_pendant',(x-.045,6.25,floor_height-.82),
            (x+.045,7.6,floor_height-.75),ink)
        box('Arrival_ground_diffuser',(x-.035,6.26,floor_height-.828),
            (x+.035,7.59,floor_height-.818),(.86,.83,.66,1),emission=1.4)
    for left,right in [(-23,-19.4),(-17.6,-16.4),(-14.6,-3.36)]:
        box('Arrival_ground_south_base',(left,5.95,.85),
            (right,5.98,.99),ink)
    box('Arrival_ground_north_base',(-23,7.98,.85),(3.35,8.02,.99),ink)
    box('Arrival_lift_sign',(-13.86,6.23,3.50),(-13.78,7.65,3.95),ink)
    text('Arrival_lift_sign_label','ELEVATORS',(-13.765,6.94,3.66),.15,
         (.9,.91,.85,1),(math.pi/2,0,math.pi/2))
    for y in (6.3,7.58):
        beam('Arrival_lift_sign_hanger',(-13.82,y,3.95),
             (-13.82,y,floor_height-.16),.012,steel)
    for center in (-18.5,-15.5):
        box('Arrival_ground_lift_mat',(center-.85,5.96,.852),
            (center+.85,6.8,.86),ink)

    # Commons loses only the strip reserved for the coherent circulation core.
    set_module('Commons')
    floor('Commons_polished_floor', -21.8, -4.6, -5.5, 2.5,
          floor_height+.008, (.58, .58, .53, 1))
    wallx('Commons_entry_wall', -5.5, -4.6, 2.5,
          doors=[(-2.5, -.5)], color=blue, door_height=3.5)
    # Two side bay edges connect the finish to the full structural envelope.
    floor('Commons_west_floor_edge', -23, -4.6, -21.8, 2.5,
          floor_height+.008, (.58, .58, .53, 1))
    bays = [(-13.55, -12.45), (-11.05, -9.95), (-8.55, -7.45)]
    cursor = -23
    for left, right in bays:
        box('Commons_blue_wall', (cursor, 2.42, floor_height),
            (left, 2.58, ceiling), blue)
        box('Commons_booth_head', (left, 2.42, floor_height+2.25),
            (right, 2.58, ceiling), blue)
        # Closed, framed glass fronts; niches are completely enclosed.
        glazing_y('Commons_booth_front', 2.50, left, right,
                  floor_height+.04, floor_height+2.25)
        box('Commons_booth_back', (left-.08, 3.82, floor_height),
            (right+.08, 3.98, ceiling), wood)
        for x in (left-.08, right):
            box('Commons_booth_side', (x, 2.58, floor_height),
                (x+.08, 3.82, ceiling), wood)
        box('Commons_booth_floor', (left, 2.58, floor_height),
            (right, 3.82, floor_height+.04), wood)
        cursor = right
    box('Commons_blue_wall', (cursor, 2.42, floor_height),
        (-5.5, 2.58, ceiling), blue)

    # Kitchen and lounge parts are authored at their fitted positions by the
    # producer; this module owns only the arrival shell and its new fixtures.
    # Reintroduce the photographed rack on the blue wall, clear of hall travel.
    for x in (-7.1, -5.9):
        beam('Donation_rack_post', (x, 2.17, floor_height),
             (x, 2.17, floor_height+1.8), .025, steel)
    beam('Donation_rack_bar', (-7.1, 2.17, floor_height+1.8),
         (-5.9, 2.17, floor_height+1.8), .025, steel)
    for i in range(6):
        x = -7.02+i*.18
        box('Donated_clothing', (x, 2.03, floor_height+.6),
            (x+.12, 2.31, floor_height+1.7), [blue, ink, wood, white][i % 4])

    # IMG4802's room stays an inaccessible reference landmark: a white-framed
    # closed door on opaque infill, not another invented playable connection.
    set_module('Side_Workspace')
    box('Telephone_closet_white_panel', (-18.18, 2.39, floor_height),
        (-16.82, 2.42, floor_height+2.7), white)
    box('Telephone_closet_closed_leaf', (-18.05, 2.35, floor_height+.03),
        (-16.95, 2.39, floor_height+2.48), (.55, .59, .58, 1))
    for x in (-18.09, -16.95):
        box('Telephone_closet_jamb', (x, 2.32, floor_height),
            (x+.04, 2.40, floor_height+2.53), white)
    box('Telephone_closet_head', (-18.09, 2.32, floor_height+2.49),
        (-16.91, 2.4, floor_height+2.55), white)
    box('Telephone_closet_handle', (-17.12, 2.29, floor_height+1.05),
        (-17.08, 2.33, floor_height+1.24), steel)
    # Offset from the nearby coffee table by .3 m in plan, with no scaled props.
    cx, cy = -16.6, 1.5
    box('Side_workstation_top', (cx-.45, cy-.3, floor_height+.70),
        (cx+.45, cy+.3, floor_height+.75), white)
    for dx in (-.37, .37):
        for dy in (-.22, .22):
            box('Side_workstation_leg', (cx+dx-.025, cy+dy-.025, floor_height),
                (cx+dx+.025, cy+dy+.025, floor_height+.70), ink)
    box('Side_workspace_chair_seat', (cx-.22, .68, floor_height+.43),
        (cx+.22, 1.12, floor_height+.49), ink)
    box('Side_workspace_chair_back', (cx-.23, .66, floor_height+.49),
        (cx+.23, .72, floor_height+.9), ink)
    for dx in (-.18, .18):
        for y in (.72, 1.08):
            box('Side_workspace_chair_leg', (cx+dx-.018, y-.018, floor_height),
                (cx+dx+.018, y+.018, floor_height+.43), steel)

    # Adjacent courtyard building, seen through the true landing end window.
    set_module('Exterior_Opposite')
    box('Arrival_court_neighbor_mass', (-37, 5.5, 0), (-27, 22, 16),
        (.46, .42, .36, 1))
    for z in (1.2, 5.2, 9.2, 13.2):
        for y in (6.1, 9.9, 13.7, 17.5):
            glazing_x('Arrival_court_neighbor_window', -26.94, y, y+2.8, z, z+2.35)

    set_module('Upper_Circulation')
    return {'removed': removed, 'moved_bank_objects': bank_objects,
            'lift_centers': [(-15.5, 4.7), (-18.5, 4.7)],
            'upper_exit': (-15.5, 6.7, floor_height)}
