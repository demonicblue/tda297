#!/usr/bin/python

from TOSSIM import *
from tinyos.tossim.TossimApp import *
import sys
import os
import simulationrun
from random import *

def readifexist(file):
    if os.access(file, os.R_OK):
	f = open(file,"r")
	return f.readlines()
    else:
	return None


def read_overridable_file(defaultdir, name):
    lines = readifexist(name)
    if lines != None:
	return lines
    else:
	return readifexist(defaultdir+"/"+name)
	
def step():
    return t.runNextEvent()

#####################################################

seed(None)
defaultdir=os.environ["TOSROOT"]+"/mybin/defaults"

variables=[]
lines = read_overridable_file(defaultdir,"variables.txt")
if lines != None:
    for line in lines:
        s = line.split()
	last = s[2]
	for i in range (3,len(s)):
	    last = last + " " + s[i]
	variables = variables + [s[0],s[1],last]

#variables = NescApp().variables.variables()

#print variables
t = Tossim(variables)
r = t.radio()
mac = t.mac()

lines = read_overridable_file(defaultdir,"channels.txt")
if lines == None:
    print "No channels!"
    sys.exit()
for line in lines:
    channel=line.split()[0]
    #print "Adding channel: ", channel
    t.addChannel(channel, sys.stdout)


gain = -40.0

##################################################
def readTopo(fname):
    lines = read_overridable_file(defaultdir,fname)
    if lines == None:
	print "Usage: simulation.py <topology> [running time in seconds]"
	sys.exit()
    for line in lines:
        s = line.split()
	if (len(s) > 0):
	    if (s[0] == "nodes"):
		n = int(s[1])
	    elif (s[0] == "gain"):
		r.add(int(s[1]), int(s[2]), float(s[3]))
	    elif (s[0] == "noise"):
		r.setNoise(int(s[1]), float(s[2]), float(s[3]))
    return n
##################################################

##################################################
def readNewTopo(fname):
    lines = read_overridable_file(defaultdir,fname)
    if lines == None:
	print "Usage: simulation.py <topology> [running time in seconds]"
	sys.exit()
    for line in lines:
        s = line.split()
	if (len(s) > 0):
	    if (s[0] == "nodes"):
		n = int(s[1])
	    elif (s[0] == "gain"):
		r.add(int(s[1]), int(s[2]), float(s[3]))
#	    elif (s[0] == "noise"):
#		r.setNoise(int(s[1]), float(s[2]), float(s[3]))

    noise = open("noise.txt", "r")
    lines = noise.readlines()
    for line in lines:
        str = line.strip()
        if (str != ""):
            val = int(str)
            for i in range(n):
                t.getNode(i).addNoiseTraceReading(val)
    for i in range(n):
        t.getNode(i).createNoiseModel()
    return n
##################################################


if len(sys.argv) == 1:
    n = readNewTopo("topo.topo")
elif sys.argv[1] == "vardump":
    vars = NescApp().variables.variables()
    for i in range(0,len(vars)):
        if i % 3 == 2:
	    end = "\n"
	else:
	    end = "\t"
	print vars[i] + end,
    sys.exit()
elif sys.argv[1] == "rawvardump":
    vars = NescApp().variables.variables()
    print len(vars)
    print vars
    sys.exit()
elif sys.argv[1] == "dumpcurrent":
    print len(variables)
    print variables
    sys.exit()
else:
    n = readNewTopo(sys.argv[1])
#    n = int(sys.argv[1])
#    for i in range(0,n):
#        for j in range(0,i):
#	    gain = uniform(-30.0,-50.0)
#	    r.add(i, j, gain + uniform(-1.0, 1.0))
#	    r.add(j, i, gain + uniform(-1.0, 1.0))
#    for i in range(0,n):
#        for j in range(0,n):
#	    if i != j:
#		r.add(i, j, gain)
#    for i in range(0,n):
#	r.setNoise(i, -120.0, 5.0)




if not simulationrun.special():
    for i in range(0,n):
        t.getNode(i).bootAtTime(100)
    t.runNextEvent()
    time = t.time()
    while (time + 50000000000 > t.time()):
        t.runNextEvent()
else:
    simulationrun.run(sys.argv,t,r,n,gain)
