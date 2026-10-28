"""Scenic street extensions and visible review limits, in authoring metres.

These background blocks suggest the neighborhood beyond the photographed area;
they are scenery, not surveyed building reconstructions or playable rooms.
"""
import math


def build_street_extensions(layout,box,floor,text,set_module):
    asphalt=(.12,.13,.14,1)
    pavement=(.50,.50,.46,1)
    frame=(.045,.05,.05,1)
    glass=(.10,.17,.20,1)
    orange=(.85,.23,.035,1)
    white=(.86,.86,.79,1)
    set_module('Streetscape')
    # Abut the retained road and sidewalks. Cross streets have separate north
    # and south arms, so no two asphalt rectangles share a top surface.
    for left,right in ((-108,-65),(65,108)):
        floor('Street_continuation',left,-22,right,-8.3,-.20,asphalt)
    for left,right in ((-67,-55),(55,67)):
        for low,high in ((-55,-22),(-8.3,20)):
            floor('Cross_street_asphalt',left,low,right,high,-.20,asphalt)
    for left,right in ((-108,-70.5),(70.5,108)):
        for low,high in ((-8.3,-4.75),(-24,-22)):
            floor('Street_extension_sidewalk',left,low,right,high,0,pavement)
    for left,right in ((-108,-67),(67,108)):
        for y in (-8.3,-22):
            box('Street_extension_curb',(left,y-.09,-.22),
                (right,y+.09,.012),pavement)
    for left,right in ((-70.5,-67),(67,70.5)):
        for low,high in ((-55,-22),(-8.3,20)):
            floor('Cross_street_sidewalk',left,low,right,high,0,pavement)
    for x in (-67,67):
        for low,high in ((-55,-22),(-8.3,20)):
            box('Cross_street_curb',(x-.09,low,-.22),(x+.09,high,.012),pavement)

    def block(name,left,low,right,high,height,color,axis='y',positive=True,add_mass=True):
        set_module('Exterior_Opposite')
        if add_mass:
            box(name+'_mass',(left,low,-.20),(right,high,height),color)
        # Windows sit on an opaque closed mass. Longitudinal/depth frontage
        # uses the same framing; no hollow structures are hidden in scenery.
        start,end=(left,right) if axis=='y' else (low,high)
        face=(high if positive else low) if axis=='y' else (right if positive else left)
        face += .025 if positive else -.025
        width=end-start
        bays=max(1,round(width/3.7))
        storeys=max(2,round(height/3.8))
        for row in range(storeys):
            z=.70+row*height/storeys
            head=(row+1)*height/storeys-.45
            for col in range(bays):
                a=start+width*col/bays+.30
                b=start+width*(col+1)/bays-.30
                if axis=='y':
                    box(name+'_window',(a,face-.015,z),(b,face+.015,head),glass)
                    for h in (z,head):
                        box(name+'_rail',(a-.025,face-.035,h-.025),(b+.025,face+.035,h+.025),frame)
                    for v in (a,(a+b)/2,b):
                        box(name+'_mullion',(v-.02,face-.035,z),(v+.02,face+.035,head),frame)
                else:
                    box(name+'_window',(face-.015,a,z),(face+.015,b,head),glass)
                    for h in (z,head):
                        box(name+'_rail',(face-.035,a-.025,h-.025),(face+.035,b+.025,h+.025),frame)
                    for v in (a,(a+b)/2,b):
                        box(name+'_mullion',(face-.035,v-.02,z),(face+.035,v+.02,head),frame)
        if add_mass:
            box(name+'_parapet',(left-.08,low-.08,height),(right+.08,high+.08,height+.18),color)

    # Continue both sides of the main road and wrap each cross-street corner.
    # Heights and materials echo the industrial street without inventing photo
    # matches for buildings that were never photographed.
    for side in (-1,1):
        left,right=(-108,-70.5) if side<0 else (70.5,108)
        for index,(low,high,height,color) in enumerate((
            (-4.75,20,15.5,(.35,.32,.28,1)),
            (-55,-24,19.0,(.47,.48,.45,1)),
        )):
            block('Cross_street_corner_'+str(side)+'_'+str(index),
                  left,low,right,high,height,color,'x',side<0)
        # Long-road faces and transverse blocks close the distant vista.
        block('Street_near_extension_'+str(side),left,-4.75,right,5.25,
              15.5,(.35,.32,.28,1),'y',False,False)
        block('Street_far_extension_'+str(side),left,-34,right,-24,
              19,(.47,.48,.45,1),'y',True,False)
        cap_left,cap_right=(-122,-108) if side<0 else (108,122)
        block('Street_distance_cap_'+str(side),cap_left,-34,cap_right,20,
              22,(.29,.31,.31,1),'x',side<0)
        arm_left,arm_right=(-70.5,-51.5) if side<0 else (51.5,70.5)
        block('Cross_street_far_cap_'+str(side),arm_left,-65,arm_right,-55,
              16,(.42,.37,.31,1),'y',True)
        block('Cross_street_near_cap_'+str(side),arm_left,20,arm_right,30,
              18,(.34,.37,.38,1),'y',False)

    set_module('Streetscape')
    limits=layout['street_review_limits']
    for side,x in ((-1,limits['min_x']),(1,limits['max_x'])):
        for low,high,base in ((limits['min_depth'],-22,0),
                              (-22,-8.3,-.20),(-8.3,limits['max_depth'],0)):
            count=max(1,math.ceil((high-low)/2.4))
            step=(high-low)/count
            for i in range(count):
                a=low+i*step+.06
                b=low+(i+1)*step-.06
                box('Review_barricade_board',(x-.055,a,base+.65),
                    (x+.055,b,base+1.08),white)
                for j in range(4):
                    if j%2==0:
                        box('Review_barricade_orange',(x-.06,a+(b-a)*j/4,base+.65),
                            (x+.06,a+(b-a)*(j+1)/4,base+1.08),orange)
                for y in (a+.10,b-.10):
                    box('Review_barricade_post',(x-.045,y-.035,base),
                        (x+.045,y+.035,base+1.16),frame)
                    box('Review_barricade_foot',(x-.32,y-.10,base+.005),
                        (x+.32,y+.10,base+.065),frame)
        # Clearly mark the sidewalk boundary where a reviewer first encounters it.
        text('Street_review_limit_sign','REVIEW AREA\nNO ENTRY',
             (x-side*.067,-5.56,.90),.13,frame,
             (math.pi/2,0,-side*math.pi/2))
