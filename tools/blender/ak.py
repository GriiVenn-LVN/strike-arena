import sys, importlib, math
sys.path.insert(0, r'D:\Office365_data\NLAVOINE\Onedrive\OneDrive - GROUPEMENT Mousquetaires\Bureau\Claude\tools\blender')
import common; importlib.reload(common)
from common import *

clear_scene()
C = coll('AK47')
STEEL = mat('AK_acier', (0.055, 0.058, 0.064), 1.0, 0.38, 'steel')
DARK  = mat('AK_acier_sombre', (0.028, 0.03, 0.034), 1.0, 0.45, 'steel')
WOOD  = mat('AK_bois', (0.42, 0.17, 0.06), 0.0, 0.42, 'wood')
MAG   = mat('AK_chargeur', (0.06, 0.062, 0.066), 0.9, 0.5, 'steel')

# --- carcasse (boîte de culasse emboutie) ---
box('Carcasse', .032, .27, .055, 0, .035, .0275, STEEL, C)
box('Puits_chargeur', .034, .062, .014, 0, .132, -.006, STEEL, C)
cyl('Couvercle', .0165, .0165, .25, 0, .02, .054, STEEL, C, seg=32)
for i in range(3): box('Nervure_couvercle_%d' % i, .036, .006, .006, 0, -.07 + i*.07, .066, STEEL, C, .0008)
box('Talon_arriere', .03, .02, .05, 0, -.105, .025, DARK, C)
box('Tourillon_avant', .036, .02, .062, 0, .18, .026, DARK, C)
for (yy, zz) in ((-.06, .012), (.0, .012), (.06, .012), (.12, .04), (.15, .012), (-.08, .04)):
    for s in (-1, 1): cyl('Rivet', .0022, .0022, .003, s*.0168, yy, zz, DARK, C, axis='X', seg=10, bevel=0)

# --- hausse ---
box('Hausse_base', .03, .065, .026, 0, .205, .058, DARK, C)
box('Hausse_planche', .012, .055, .004, 0, .2, .074, DARK, C, .0005)
box('Hausse_curseur', .016, .01, .008, 0, .19, .077, STEEL, C, .0006)

# --- canon, tube de gaz, baguette ---
cyl('Canon', .0085, .0085, .43, 0, .385, .03, DARK, C, seg=24)
cyl('Tube_gaz', .011, .011, .235, 0, .312, .058, STEEL, C, seg=24)
cyl('Baguette', .003, .003, .375, 0, .388, .011, STEEL, C, seg=10)
prof('Bloc_gaz', [(.43, .015), (.465, .015), (.465, .07), (.45, .072), (.43, .07)], .026, DARK, C, bevel=.0025)

# --- garde-mains en bois ---
gr = []
for i in range(6):
    y0 = .2 + i*.035
    gr += [(y0, -.017), (y0+.012, -.021), (y0+.023, -.017)]
lower = [(.19, .036), (.405, .036), (.412, .02)] + [(.41, -.01)] + list(reversed(gr)) + [(.19, -.012)]
prof('Garde_main_inf', lower, .046, WOOD, C, bevel=.004, taper=lambda y, z: 1 - max(0, (y-.37))*2.2)
prof('Garde_main_sup', [(.2, .046), (.4, .046), (.405, .06), (.395, .074), (.21, .074), (.198, .062)], .03, WOOD, C, bevel=.005)
box('Bague_garde_main', .05, .008, .056, 0, .413, .028, DARK, C)

# --- guidon ---
cyl('Bague_guidon', .012, .012, .03, 0, .56, .03, DARK, C, seg=20)
prof('Tour_guidon', [(.548, .035), (.572, .035), (.572, .085), (.562, .098), (.556, .098), (.548, .085)], .016, DARK, C, bevel=.0015)
for s in (-1, 1): box('Oreille_guidon', .003, .016, .03, s*.011, .56, .09, DARK, C, .0006)
cyl('Guidon', .0016, .0016, .02, 0, .56, .103, STEEL, C, axis='Z' if False else 'Y', seg=8, bevel=0)
box('Tenon_baionnette', .01, .02, .012, 0, .56, .008, DARK, C)
# frein de bouche oblique
cyl('Frein_bouche', .0105, .0105, .035, 0, .617, .03, DARK, C, seg=20)
prof('Frein_bec', [(.6, .02), (.635, .02), (.635, .045), (.622, .045), (.6, .04)], .02, DARK, C, bevel=.001)

# --- chargeur courbe 30 coups ---
path = []
for i in range(18):
    t = i/17
    a = -math.pi/2 + t*0.62
    R = .42
    path.append((.128 + .065*math.sin(t*0.9) + (R*math.cos(a+math.pi/2) - 0)*0 + t*.075, -.004 - t*.23 + math.sin(t*math.pi)*.01))
sweep('Chargeur', path, lambda t: .027, lambda t: .061 + t*.012, MAG, C, bevel=.0018)
for k in (.3, .5, .7):
    i = int(k*17); y, z = path[i]
    box('Nervure_chargeur', .029, .03, .004, 0, y-.005, z, MAG, C, .0008)
y, z = path[-1]; box('Plaque_chargeur', .031, .08, .008, 0, y, z-.004, DARK, C, .0015)

# --- pontet, détente, poignée ---
tg = [(.115, -.004), (.112, -.022), (.1, -.036), (.07, -.04), (.045, -.036), (.035, -.02), (.034, -.004)]
sweep('Pontet', tg, lambda t: .011, lambda t: .0035, DARK, C, .0005)
sweep('Detente', [(.085, -.002), (.083, -.012), (.077, -.022), (.07, -.027)], lambda t: .006, lambda t: .006 - t*.002, STEEL, C, .0005)
prof('Poignee', [(.065, -.002), (.028, -.002), (-.03, -.112), (-.026, -.124), (.006, -.124), (.012, -.112), (.042, -.05), (.06, -.022)], .03, WOOD, C, bevel=.004,
     taper=lambda y, z: .9 + .1*(1 + z*8))

# --- crosse en bois ---
stock = [(-.105, .048), (-.25, .043), (-.47, .036), (-.485, .033), (-.485, -.105), (-.465, -.11), (-.33, -.072), (-.2, -.03), (-.115, -.008)]
prof('Crosse', stock, .038, WOOD, C, bevel=.006, taper=lambda y, z: .78 + .22*min(1, (-y-.1)/.2))
prof('Plaque_couche', [(-.485, .036), (-.494, .036), (-.494, -.11), (-.485, -.108)], .041, DARK, C, bevel=.002)

# --- sélecteur et levier d'armement (côté droit) ---
prof('Selecteur', [(.0, .036), (.13, .046), (.14, .041), (.0, .03)], .002, STEEL, C, x=.0175, bevel=.0005)
box('Levier_armement', .006, .012, .01, .019, .125, .04, STEEL, C, .001)
cyl('Levier_boule', .006, .006, .012, .026, .128, .04, STEEL, C, axis='X', seg=14)

print('AK construit :', len(C.objects), 'pièces')
