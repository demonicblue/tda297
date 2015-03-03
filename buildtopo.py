#!/usr/bin/python

import sys
import os


radiolimit = 5

gain      = "-20.0"
noise     = "-140.0"
noisevar = "5.0"

sys.stderr.write("\nNOTE: Make sure that columns match the COLUMNS definition in Rout.h\n      Make sure that radiolimit matches MAXDISTANCE definition in Rout.h\n\n")
args = len(sys.argv) - 1
if args < 2 or args > 3:
    print "usage: buildtopo.py <columns> <rows> [radiolimit]"
    sys.exit()

cols = int(sys.argv[1]);
rows = int(sys.argv[2]);
if args > 2:
    radiolimit = int(sys.argv[3]);


def nodenumber(x,y):
    return y * cols + x

def putnode(x,y):
    id = nodenumber(x,y)
    print "noise\t%d\t%s\t%s" % (id,noise, noisevar)
    for oy in range(rows):
        for ox in range(cols):
	    oid = nodenumber(ox,oy)
	    if (id != oid) and ((x-ox) * (x-ox) + (y-oy) * (y-oy) <= radiolimit):
		print "gain\t%d\t%d\t%s" % (id, oid, gain)



print "nodes\t%d\t%d\t%d" % ((rows * cols),cols,rows)
for y in range(rows):
    for x in range(cols):
        putnode(x,y)
	
	


