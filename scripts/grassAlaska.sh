#!/bin/bash -v

LOCATION=Alaska
NLCD=Nlcd01v1AK
export GISBASE=/usr/lib/grass64
export PATH=$PATH:$GISBASE/bin:$GISBASE/scripts
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$GISBASE/lib

# use process ID (PID) as lock file number:
export GIS_LOCK=$$

# path to GRASS settings file
export GISRC=./.grassrc6
# path to GRASS binaries and libraries:
g.gisenv set=LOCATION_NAME=$GIS_LOCK
eval $(g.gisenv)
mkdir -p $GISDBASE/$GIS_LOCK
g.mapset -c mapset=temp
r.in.gdal in=aeaGrid5min${LOCATION}.img out=grid_5min location=${LOCATION}
g.mapset mapset=PERMANENT location=${LOCATION}
rm -rf $GISDBASE/$GIS_LOCK/temp
r.in.gdal input=pad-us/data/PADUS1_2_${LOCATION}_GAP.tif output=gap
r.in.gdal input=nlcd/pr_landcover_wimperv_10-28-08_se5.img output=Nlcd01v1PR
r.mapcalc MASK="if( ${NLCD} > 0, 1, null())"
echo grid_5min,${NLCD},gap,n > stats${NLCD}.csv
r.stats -c input=grid_5min,${NLCD},gap fs=, >> stats${NLCD}.csv
r.mask -r
echo grid_5min,n > grid${NLCD}.csv
r.stats -c input=grid_5min fs=, >> grid${NLCD}.csv
# run GRASS' cleanup routine
$GISBASE/etc/clean_temp

# remove session tmp directory:
rm -rf /tmp/grass6-$USER-$GIS_LOCK
