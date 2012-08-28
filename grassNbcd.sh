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

export GRASS_MESSAGE_FORMAT=plain 
r.in.gdal --overwrite input=nbcdWarped.vrt output=nbcd2000
r.in.gdal --overwrite input=cusaStatesAea.img output=states
r.in.gdal --overwrite input=cusaCountiesAea.img output=counties
r.in.gdal --overwrite input=nbcdZones.img output=zones

g.region rast=nbcd2000
r.mapcalc nbcd2000Zero='if( isnull( nbcd2000), 0, nbcd2000)'

g.region rast=nlcd2006
r.mask input=nlcd2006 maskcats="1 thru 95"
echo grid_5min,nlcd2006,gap,nbcd2000,n > statsNbcd.csv && \
r.stats -Nc input=grid_5min,nlcd2006,gap,nbcd2000Zero fs=, >> statsNbcd.csv 2> statsNbcd.err &

# echo state,nlcd2006,gap,nbcd2000,n > statsNbcdState.csv && \
# r.stats -Nc input=states,counties,nlcd2006,gap,nbcd2000Zero fs=, >> statsNbcdState.csv 2> statsNbcdState.err &

echo state,county,nlcd2006,gap,nbcd2000,n > statsNbcdCounty.csv && \
r.stats -Nc input=states,counties,nlcd2006,gap,nbcd2000Zero fs=, >> statsNbcdCounty.csv 2> statsNbcdCounty.err &

echo zone,nlcd2006,gap,nbcd2000,n > statsNbcdZone.csv && \
r.stats -Nc input=zones,nlcd2006,gap,nbcd2000Zero fs=, >> statsNbcdZone.csv 2> statsNbcdZone.err &

r.mask -r

# run GRASS' cleanup routine
$GISBASE/etc/clean_temp

# remove session tmp directory:
rm -rf /tmp/grass6-$USER-$GIS_LOCK
