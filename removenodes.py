#!/usr/bin/python

import sys
import os


radiolimit = 6

gain      = "-20.0"
noise     = "-140.0"
noisevar = "5.0"

args = len(sys.argv) - 1
if args < 2:
    print "usage: removenode.py <file> [nodes]"
    sys.exit()
file = sys.argv[1]
if os.access(file, os.R_OK):
    f = open(file,"r")
    lines = f.readlines()
else:
    print "Unreadable file"
    sys.exit()


removes = set([])
for i in range(2,len(sys.argv)):
    removes.add(int(sys.argv[i]))

for line in lines:
    items = line.split()
    if items[0] == "gain":
	first = int(items[1])
	second = int(items[2])
	if first not in removes and second not in removes:
	    sys.stdout.write(line)
    else:
		    sys.stdout.write(line)


