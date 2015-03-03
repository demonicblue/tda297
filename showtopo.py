#!/usr/bin/python

import sys
import os


radiolimit = 6

gain      = "-20.0"
noise     = "-140.0"
noisevar = "5.0"

args = len(sys.argv) - 1
if args != 1:
    print "usage: showtopo.py <file>"
    sys.exit()
file = sys.argv[1]
if os.access(file, os.R_OK):
    f = open(file,"r")
    lines = f.readlines()
else:
    print "Unreadable file"
    sys.exit()


existing = set([])
for line in lines:
    items = line.split()
    if items[0] == "nodes":
	nodes=int(items[1])
	cols=int(items[2])
	rows=int(items[3])
    elif items[0] == "gain":
	existing.add(int(items[1]))

#print existing

for y in range(rows):
    for x in range(cols):
        if (x + y * cols) in existing:
	    sys.stdout.write("X")
	else:
	    sys.stdout.write(".")
    sys.stdout.write("\n")

#print "nodes\t%s" % (rows * cols)
#for y in range(rows):
#    for x in range(cols):
#        putnode(x,y)
	
	


