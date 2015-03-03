#!/bin/pyton

import random
import sys

millisecond = 10000000

def special():
    return True

def run(argv,t,r,n,gain):
    if len(argv) <= 2:
	seconds = 40
    else:
        seconds = int(sys.argv[2])

    for i in range(0,n):
        t.getNode(i).bootAtTime(random.randint(0,1*millisecond))
    print "Running for", seconds, "seconds:", seconds * 10000000000
    t.runNextEvent()
    time = t.time()
    while (time + seconds * 1000 * millisecond  > t.time()):
        #print "ping"
        t.runNextEvent()
