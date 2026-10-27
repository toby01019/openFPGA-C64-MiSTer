"""Editable 32x32 design based on the user's code-native homepage sprite.
This is an art approval reference, not a claim of native C64 rendering.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import json

C={'bg':'#191621','skin':'#ffd4b5','shade':'#e8af91','light':'#ffe5ce',
   'hair':'#9b9ba3','hairlight':'#d5d5dc','hairshade':'#777782',
   'glass':'#48243b','lens':'#f2cbb8','shirt':'#292632',
   'shirtlight':'#41404c','logo':'#e7e5eb','pants':'#69345d',
   'pantshadow':'#48243b','shoe':'#a82062'}


def figure(phase=None,left=False):
    im=Image.new('RGBA',(32,32),(0,0,0,0))
    d=ImageDraw.Draw(im)
    def rect(box,col): d.rectangle(box,fill=C[col])
    def line(points,col,width=1): d.line(points,fill=C[col],width=width)
    def poly(points,col): d.polygon(points,fill=C[col])
    # Compact swept-up silver hair, with the original three grey shades.
    poly([(13,7),(13,4),(14,4),(14,2),(16,2),(16,1),(18,1),
          (18,2),(20,2),(20,4),(21,4),(21,7),(19,7),(19,6),(16,6),
          (16,8),(14,8),(14,9),(13,9)],'hair')
    line([(14,4),(17,4),(18,3)],'hairlight')
    rect((13,7,14,8),'hairshade')
    # Seven-pixel face with a small nose and a tapered chin.
    rect((16,7,21,12),'skin')
    rect((14,9,15,11),'shade')
    rect((15,9,15,10),'skin')
    rect((21,10,22,11),'skin')
    rect((16,13,19,13),'skin')
    rect((16,14,18,15),'skin')
    rect((16,13,17,14),'shade')
    rect((20,10,20,11),'light')
    # Distinct side-view glasses: thin temple, framed lens, clear reflection.
    rect((14,8,17,8),'glass')
    rect((16,8,21,10),'glass')
    rect((18,9,19,9),'lens')
    # Dark Commodore T-shirt, narrow waist and original plum trousers.
    poly([(13,15),(19,15),(21,17),(20,20),(19,23),
          (12,23),(11,19),(11,17)],'shirt')
    line([(12,16),(13,16),(13,15)],'shirtlight')
    for y,row in enumerate(['0111000','1100011','1100000','1100011','0111000']):
        for x,p in enumerate(row):
            if p=='1': rect((13+x,17+y,13+x,17+y),'logo')
    rect((12,23,19,24),'pants')
    if phase is None:
        legs=[[(13,24),(13,28),(12,29)],[(18,24),(18,28),(19,29)]]
        arms=[[(11,17),(10,20),(11,22)],[(21,17),(22,20),(22,22)]]
    else:
        poses=[
            [[(13,24),(10,26),(7,29)],[(18,24),(21,26),(24,29)]],
            [[(13,24),(11,27),(9,29)],[(18,24),(19,26),(21,27)]],
            [[(13,24),(13,27),(12,29)],[(18,24),(16,26),(15,27)]],
            [[(13,24),(16,26),(17,29)],[(18,24),(14,25),(12,26)]],
            [[(13,24),(19,26),(22,28)],[(18,24),(14,27),(10,29)]],
            [[(13,24),(17,26),(19,27)],[(18,24),(16,27),(15,29)]],
            [[(13,24),(14,26),(15,27)],[(18,24),(18,27),(19,29)]],
            [[(13,24),(11,25),(9,26)],[(18,24),(21,27),(24,29)]],
        ]
        legs=poses[phase]
        reach=[-3,-2,0,2,3,2,0,-2][phase]
        arms=[[(11,17),(10-reach//2,20),(11-reach,21)],
              [(21,17),(22+reach//2,19),(22+reach,20)]]
    for index,leg in enumerate(legs):
        line(leg,'pantshadow' if index==0 else 'pants',3)
        x,y=leg[-1]
        rect((x-1,y,x+2,y+1),'shoe')
    for arm in arms:
        line(arm,'skin',2)
        x,y=arm[0]
        rect((x,y,x+1,y+1),'shirtlight')
    if left: im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    return im


def climb(phase=0):
    """Rear view: opposing hands and feet grip successive ladder rungs."""
    im=Image.new('RGBA',(32,32),(0,0,0,0));d=ImageDraw.Draw(im)
    d.polygon([(13,7),(13,4),(14,4),(14,2),(16,2),(16,1),
               (18,1),(18,2),(20,2),(20,4),(21,4),(21,10),
               (19,12),(15,12),(13,10)],fill=C['hair'])
    d.line([(14,4),(17,4),(18,3)],fill=C['hairlight'])
    d.rectangle((15,12,18,15),fill=C['skin'])
    d.polygon([(12,15),(20,15),(21,18),(20,23),(12,23),(11,18)],fill=C['shirt'])
    d.line((12,16,12,19),fill=C['shirtlight'])
    # Feet are intentionally lifted, not a walking pose reused on a ladder.
    hands=[(8,16),(10,14),(16,8),(14,10)][phase]
    feet=[(29,25),(28,26),(25,29),(26,28)][phase]
    for side in range(2):
        shoulder=12 if side==0 else 20
        grip=10 if side==0 else 22
        knee=12 if side==0 else 20
        d.line([(shoulder,17),(grip,15),(grip,hands[side])],fill=C['skin'],width=2)
        d.rectangle((shoulder,16,shoulder+1,18),fill=C['shirtlight'])
        d.line([(14+side*4,23),(knee,feet[side]-3),(knee,feet[side])],fill=C['pants'],width=3)
        d.rectangle((knee-1,feet[side],knee+2,feet[side]+1),fill=C['shoe'])
    return im


def opponent(kind=0,phase=None,left=False):
    """Matching 30-pixel proportions; no glasses, distinct hats and coats."""
    im=figure(phase);d=ImageDraw.Draw(im)
    d.rectangle((12,0,23,14),fill=(0,0,0,0))
    d.rectangle((16,7,21,12),fill=C['skin'])
    d.rectangle((14,9,15,10),fill=C['shade'])
    d.rectangle((16,13,19,15),fill=C['skin'])
    d.point((21,10),fill=C['skin'])
    d.point((20,8),fill=C['shirt'])
    if kind==0:
        d.rectangle((14,2,19,5),fill=C['shirt'])
        d.line((14,5,19,5),fill=C['hair'])
        d.rectangle((12,6,23,7),fill=C['shirt'])
    else:
        d.polygon([(14,6),(14,3),(16,1),(20,2),(21,5),(21,6)],fill=C['shirt'])
        d.line((14,4,20,4),fill=C['hair'])
        d.rectangle((14,6,23,7),fill=C['shirt'])
    # Remove Toby's C= emblem; simple jacket buttons survive MC quantization.
    d.rectangle((13,17,19,21),fill=C['shirt'])
    d.rectangle((16,17,17,17),fill=C['hair'])
    d.rectangle((16,20,17,20),fill=C['hair'])
    if left:im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    return im


def panel(images,scale=6):
    out=Image.new('RGB',(len(images)*32*scale,34*scale),C['bg'])
    for i,im in enumerate(images):
        im=im.resize((32*scale,32*scale),Image.Resampling.NEAREST)
        out.paste(im,(i*32*scale,scale),im)
    return out


