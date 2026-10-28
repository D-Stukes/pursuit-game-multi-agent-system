"""Photo-derived, closed exterior shells using the environment's shared builders.

Dimensions are construction estimates. Windows fill deliberate apertures; opaque
spandrels, returns and piers close every remaining bay interval. Scenery never
provides the exterior wall of an occupied room.
"""
import math


IVORY = (.64, .625, .575, 1)
BRICK = (.47, .475, .45, 1)
DARK = (.18, .185, .18, 1)
FRAME = (.035, .045, .048, 1)
GLASS = (.30, .43, .48, .22)
SCENERY_GLASS = (.075, .13, .16, 1)
STONE = (.53, .51, .46, 1)


def build_facades(layout, box, glazing_y, text, beam, set_module):
    """Build the main shell and three adjoining scenery frontages.

    Callbacks use Blender world metres and assign geometry to the active module.
    No objects are scaled to compensate for mismatched room or floor dimensions.
    """
    front = layout['envelope']['front_depth']
    x0 = layout['envelope']['min_x']
    x1 = layout['envelope']['max_x']
    top = layout['levels']['facade_storeys'][-1]
    ceiling = layout['levels']['upper_ceiling']

    def window(name, xlo, xhi, y, bottom, head, color=GLASS, facing=-1):
        glazing_y(name, y, xlo, xhi, bottom, head, color)
        outside = y + facing * .055
        # Black, recessed metalwork rather than the old pale glass-grid look.
        for z in (bottom, head):
            box(name+'_black_rail', (xlo-.025, outside-.025, z-.035),
                (xhi+.025, outside+.025, z+.035), FRAME)
        for x in (xlo, xhi):
            box(name+'_black_jamb', (x-.035, outside-.025, bottom),
                (x+.035, outside+.025, head), FRAME)
        count = max(1, round((xhi-xlo)/1.18))
        for i in range(1, count):
            x = xlo+(xhi-xlo)*i/count
            box(name+'_mullion', (x-.018, outside-.026, bottom),
                (x+.018, outside+.026, head), FRAME)
        for fraction in (.32, .68):
            z = bottom+(head-bottom)*fraction
            box(name+'_crossbar', (xlo, outside-.027, z-.018),
                (xhi, outside+.027, z+.018), FRAME)

    def cornice(name, left, right, y, height, color=IVORY, facing=-1):
        for dz, overhang, thickness in ((-.32,.13,.11),(-.13,.25,.12),(0,.38,.14)):
            center = y+facing*overhang
            box(name, (left-.15,center-.15,height+dz),
                (right+.15,center+.15,height+dz+thickness),color)

    def crest(name, center, width, y, height, facing=-1, color=IVORY):
        # Low curved parapet over a solid backing, with a small central cap.
        left, right = center-width/2, center+width/2
        box(name+'_backing',(left,y-.15,height),(right,y+.15,height+.21),color)
        previous = None
        for i in range(25):
            x=left+width*i/24
            rise=.14+.48*math.sin(math.pi*i/24)
            box(name+'_parapet',(x-width/48,y-.12,height),
                (x+width/48,y+.12,height+rise),color)
            point=(x,y+facing*.18,height+rise)
            if previous:beam(name+'_curved_molding',previous,point,.055,color)
            previous=point
        box(name+'_center_cap',(center-.43,y-.2,height+.52),
            (center+.43,y+.2,height+.76),color)

    set_module('Exterior_Main')
    # Seven broad middle bays and paired narrow end bays in IMG_4776/4777.
    # The full footprint is enclosed; furniture no longer sits behind a neighbor.
    # The entry and central broad bay share x=0. End-bay widths absorb the
    # photo-estimated footprint asymmetry without moving the live entrance.
    broad_edges=[-19.25+i*5.5 for i in range(8)]
    edges=[x0,(x0+broad_edges[0])/2,*broad_edges,
           (broad_edges[-1]+x1)/2,x1]

    # Ground masonry is dark, with punched shop windows and a tall central entry.
    for left,right in zip(edges,edges[1:]):
        if left<0<right:
            continue
        box('Ground_front_base',(left,front-.20,-.16),(right,front+.08,.96),DARK)
        box('Ground_front_head',(left,front-.20,3.78),(right,front+.08,4.92),DARK)
        # Ground piers and upper piers use the same centerlines.
        box('Ground_storefront_pier',(left-.26,front-.23,.96),(left+.26,front+.09,3.78),DARK)
        box('Ground_storefront_pier',(right-.26,front-.23,.96),(right+.26,front+.09,3.78),DARK)
        window('Ground_facade_window',left+.26,right-.26,front,.96,3.78)
        box('Ground_window_sill',(left+.20,front-.29,.90),(right-.20,front+.08,1.00),STONE)
    # No leaf is generated here: retained doors and puzzle own the live threshold.
    for left,right in ((-2.49,-1.52),(1.52,2.49)):
        window('Entry_sidelight',left,right,front,.01,2.70)
    window('Entry_transom',-2.49,2.49,front,2.70,4.42)
    box('Entry_head',(-2.75,front-.23,4.42),(2.75,front+.09,4.92),DARK)
    for x in (-2.75,2.75):
        box('Entry_pier',(x-.26,front-.28,-.16),(x+.26,front+.12,4.92),DARK)
    text('Street_address','47-10   47-16',(0,front-.12,3.67),.22,IVORY)
    box('For_lease_sign',(2.47,front-.32,2.55),(3.03,front-.29,3.43),(.81,.81,.77,1))
    text('Lease_heading','FOR\nLEASE',(2.75,front-.335,3.12),.13,FRAME)

    levels=layout['levels']['facade_storeys']
    for level,(z0,z1) in enumerate(zip(levels[1:-1],levels[2:])):
        sill=z0+.82;head=z1-.43
        box('Facade_horizontal_band',(x0,front-.13,z0),(x1,front+.10,sill),BRICK)
        box('Facade_window_head',(x0,front-.13,head),(x1,front+.10,z1+.005),BRICK)
        for left,right in zip(edges,edges[1:]):
            a=left+.24;b=right-.24
            window('Upper_facade_window',a,b,front+.015,sill,head,
                   GLASS if level==0 else SCENERY_GLASS)
            box('Window_stone_sill',(a-.04,front-.23,sill-.075),(b+.04,front+.08,sill+.01),IVORY)
            box('Window_stone_lintel',(a-.04,front-.19,head-.01),(b+.04,front+.08,head+.11),IVORY)
            # A restrained brick-course relief supplies real scale cues.
            for z in (z0+.18,z0+.38,z0+.58):
                box('Spandrel_course',(left+.25,front-.137,z),
                    (right-.25,front-.129,z+.008),(.40,.41,.39,1))
        for x in edges:
            box('Facade_pier',(x-.25,front-.26,z0),(x+.25,front+.12,z1),IVORY)
            if level==2:
                box('Pier_capital',(x-.34,front-.34,z1-.60),(x+.34,front+.14,z1-.43),IVORY)
                box('Pier_capital_flute',(x-.13,front-.32,z1-1.04),(x+.13,front-.26,z1-.62),STONE)
    # These are main-building outer returns, not neighboring frontages.
    for x in (x0,x1):
        box('High_side_wall',(x-.08,front,ceiling),(x+.08,17.5,top),IVORY)
    box('High_rear_wall',(x0,17.32,ceiling),(x1,17.5,top),IVORY)
    box('Roof',(x0-.18,front-.16,top),(x1+.18,17.5,top+.18),(.32,.33,.31,1))
    cornice('Cornice',x0,x1,front,top)
    crest('Main_parapet_crest',x1-2.7,3.4,front,top)
    # Narrow vertical banners visible in the main street photographs.
    for x in (edges[2],edges[4],edges[6],edges[8]):
        beam('Banner_bracket',(x,front-.25,8.1),(x,front-.7,8.1),.025,FRAME)
        box('Street_banner',(x-.11,front-.75,6.05),(x+.11,front-.69,8.12),(.09,.105,.11,1))

    def scenery(name,left,right,y,height,storeys,color,facing,fluted=False):
        depth=10
        rear=y-facing*depth
        # Opaque mass sits behind opaque scenery glass; no visible hollow void.
        box(name+'_mass',(left,min(y,rear),0),(right,max(y,rear),height),color)
        bay_count=max(1,round((right-left)/3.65))
        width=(right-left)/bay_count
        fh=height/storeys
        outside=y+facing*.045
        for row in range(storeys):
            base=row*fh;bottom=base+.78;head=(row+1)*fh-.30
            for i in range(bay_count):
                a=left+i*width+.28;b=left+(i+1)*width-.28
                window(name+'_window',a,b,outside,bottom,head,SCENERY_GLASS,facing)
                box(name+'_sill',(a-.04,outside-.10,bottom-.07),(b+.04,outside+.10,bottom+.02),STONE)
            for i in range(bay_count+1):
                x=left+i*width
                if fluted:
                    for dx in (-.13,0,.13):
                        center=outside+facing*.10
                        box(name+'_fluted_pier',(x+dx-.035,center-.06,base),
                            (x+dx+.035,center+.06,(row+1)*fh),(.20,.205,.20,1))
        cornice(name+'_cornice',left,right,y,height,color,facing)

    scenery('Near_dark_industrial',-55,x0,front,19.4,5,(.13,.14,.14,1),-1,True)
    scenery('Near_white_neighbor',x1,55,front,16.4,4,(.46,.425,.365,1),-1)

    set_module('Exterior_Opposite')
    scenery('Opposite_white_factory',-48,38,-24,18,4,BRICK,1)
    # Projecting ivory piers contrast with the gray brick infill in IMG_4772.
    opposite_bays=round(86/3.65)
    for i in range(opposite_bays+1):
        x=-48+86*i/opposite_bays
        box('Opposite_ivory_pier',(x-.22,-24.10,0),(x+.22,-23.76,18),IVORY)
        box('Opposite_pier_cap',(x-.31,-24.14,17.28),(x+.31,-23.67,17.48),IVORY)
    cornice('Opposite_main_cornice',-48,38,-24,18,IVORY,1)
    crest('Opposite_central_pediment',-5,6.6,-24,18,1)
    box('Opposite_roof_pavilion',(-43,-31,18),(29,-25.5,21.0),SCENERY_GLASS)
    for x in range(-43,29,3):
        window('Pavilion_glass',x+.04,min(x+2.96,29),-25.46,18.1,20.88,SCENERY_GLASS,1)
    box('Pavilion_roof',(-43.15,-31.1,20.95),(29.15,-25.35,21.08),IVORY)
    box('Opposite_dark_roof_box',(-39,-29,18),(-35,-25.4,21.3),(.15,.16,.15,1))
    box('Opposite_entry_canopy',(-30,-24.1,3.65),(-24,-22.65,3.81),(.38,.39,.36,1))
    text('Opposite_address','47-11',(-27,-22.62,3.29),.25,IVORY,rotation=(math.pi/2,0,math.pi))
    scenery('Opposite_end_block',38,55,-24,12.2,3,(.34,.265,.21,1),1)
