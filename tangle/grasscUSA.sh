#!/bin/bash -v

# path to GRASS binaries and libraries:
export GISBASE=/usr/lib/grass64
export PATH=$PATH:$GISBASE/bin:$GISBASE/scripts
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$GISBASE/lib

# use process ID (PID) as lock file number:
export GIS_LOCK=$$

# path to GRASS settings file
export GISRC=./.grassrc6
g.gisenv set=LOCATION_NAME=$GIS_LOCK
eval $(g.gisenv)
mkdir -p $GISDBASE/$GIS_LOCK
g.mapset -c mapset=temp
r.in.gdal in=aeaGrid5mincUSA.img out=grid_5min location=cUSA
# g.gisenv set=LOCATION_NAME=cUSA
# g.gisenv set=MAPSET=PERMANENT
g.mapset mapset=PERMANENT location=cUSA
rm -rf $GISDBASE/$GIS_LOCK/temp
# g.rename rast=aeaGrid5mincUSA.img,grid_5min
r.in.gdal input=pad-us/PADUS1_2_regions/PADUS1_2_cUSA_GAP.tif output=gap

r.in.gdal input=nlcd/nlcd2001_landcover_mosaic_2-20-07/nlcd2001_mosaic_2-20-07.img output=Nlcd01v1

r.in.gdal input=nlcd/NLCD2001_landcover_v2_2-13-11/nlcd2001_landcover_v2_2-13-11.img output=Nlcd01v2

r.in.gdal input=nlcd/nlcd2006_landcover_4-20-11_se5.img output=Nlcd06

r.mapcalc MASK="if( Nlcd01v1 > 0, 1, null())"
echo grid_5min,Nlcd01v1,gap,n > statsNlcd01v1.csv
r.stats -c input=grid_5min,Nlcd01v1,gap fs=, >> statsNlcd01v1.csv
r.mask -r
echo grid_5min,n > gridNlcd01v1.csv
r.stats -c input=grid_5min fs=, >> gridNlcd01v1.csv

r.mapcalc MASK="if( Nlcd01v2 > 0, 1, null())"
echo grid_5min,Nlcd01v2,gap,n > statsNlcd01v2.csv
r.stats -c input=grid_5min,Nlcd01v2,gap fs=, >> statsNlcd01v2.csv
r.mask -r
echo grid_5min,n > gridNlcd01v2.csv
r.stats -c input=grid_5min fs=, >> gridNlcd01v2.csv

r.mapcalc MASK="if( Nlcd06 > 0, 1, null())"
echo grid_5min,Nlcd06,gap,n > statsNlcd06.csv
r.stats -c input=grid_5min,Nlcd06,gap fs=, >> statsNlcd06.csv
r.mask -r
echo grid_5min,n > gridNlcd06.csv
r.stats -c input=grid_5min fs=, >> gridNlcd06.csv

cat <<'EOF'
# run GRASS' cleanup routine
$GISBASE/etc/clean_temp

# remove session tmp directory:
rm -rf /tmp/grass6-$USER-$GIS_LOCK
EOF
