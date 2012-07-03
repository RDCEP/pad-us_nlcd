#!/bin/bash -v

# path to GRASS binaries and libraries:
export GISBASE=/usr/lib/grass64
export PATH=$PATH:$GISBASE/bin:$GISBASE/scripts
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$GISBASE/lib

# use process ID (PID) as lock file number:
export GIS_LOCK=$$

# path to GRASS settings file
export GISRC=./.grassrc6
g.gisenv set=LOCATION_NAME=cUSA
g.gisenv set=MAPSET=PERMANENT
eval $(g.gisenv)

GRASS_MESSAGE_FORMAT=plain r.in.gdal --overwrite input=nbcdWarped.vrt output=nbcd2000
# r.null map=nbcd2000 null=0

g.region rast=nbcd2000
GRASS_MESSAGE_FORMAT=plain r.mapcalc nbcd2000Zero='if( isnull( nbcd2000), 0, nbcd2000)'

g.region rast=nlcd2006
export GRASS_MESSAGE_FORMAT=plain
# r.mapcalc MASK="if( nlcd2006 > 0, 1, null())"
r.mask input=nlcd2006 maskcats="1 thru 95"
# echo grid_5min,nlcd2006,gap,nbcd2000,n > statsNbcd.csv
# r.stats -Nc input=grid_5min,nlcd2006,gap,nbcd2000Zero fs=, >> statsNbcd.csv

# this causes integer overflow
# r.mapcalc gridNlcdGap="grid_5min*1000 + nlcd2006*10 + if( isnull( gap), 0, gap)"
# r.average --overwrite cover=nbcd2000Zero base=gridGap output=gridNlcdGapAldb
# r.stats -A input=grid_5min,nlcd2006,gap,gridNlcdGap

r.stats -A input=grid_5min,nlcd2006,gap,nbcd2000Zero
r.mask -r

# run GRASS' cleanup routine
$GISBASE/etc/clean_temp

# remove session tmp directory:
rm -rf /tmp/grass6-$USER-$GIS_LOCK
