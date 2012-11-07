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
r.in.gdal --overwrite -e input=nbcd/data/nbcdAldb.vrt output=nbcdAldb
r.in.gdal --overwrite input=cusaStatesAea.img output=states
r.in.gdal --overwrite input=cusaCountiesAea.img output=counties
r.in.gdal --overwrite input=nbcdZones.img output=zones

# g.region rast=nbcd
# r.mapcalc nbcdZero='if( isnull( nbcd), 0, nbcd)'

g.region rast=Nlcd01v1
r.mask -o input=Nlcd01v1 maskcats="1 thru 95"

echo grid_5min,Nlcd01v1,gap,aldb,n > data/statsNbcdNlcd01v1Grid5min.csv && \
r.stats -Nc input=grid_5min,Nlcd01v1,gap,nbcdAldb fs=, >> data/statsNbcdNlcd01v1Grid5min.csv 2> data/statsNbcdNlcd01v1Grid5min.err &

echo state,county,Nlcd01v1,gap,aldb,n > data/statsNbcdNlcd01v1County.csv && \
r.stats -Nc input=states,counties,Nlcd01v1,gap,nbcdAldb fs=, >> data/statsNbcdNlcd01v1County.csv 2> data/statsNbcdNlcd01v1County.err &

echo zone,Nlcd01v1,gap,aldb,n > data/statsNbcdNlcd01v1Zone.csv && \
r.stats -Nc input=zones,Nlcd01v1,gap,nbcd fs=, >> data/statsNbcdNlcd01v1Zone.csv 2> data/statsNbcdNlcd01v1Zone.err &

# g.region rast=Nlcd01v2
# r.mask -o input=Nlcd01v2 maskcats="1 thru 95"

# echo grid_5min,Nlcd01v2,gap,nbcd,n > data/statsNbcdNlcd01v2Grid5min.csv && \
# r.stats -Nc input=grid_5min,Nlcd01v2,gap,nbcd fs=, >> data/statsNbcdNlcd01v2Grid5min.csv 2> data/statsNbcdNlcd01v2Grid5min.err &

# echo state,county,nlcd01v2,gap,nbcd,n > data/statsNbcdNlcd01v2County.csv && \
# r.stats -Nc input=states,counties,Nlcd01v2,gap,nbcd fs=, >> data/statsNbcdNlcd01v2County.csv 2> data/statsNbcdNlcd01v2County.err &

# echo zone,nlcd01v2,gap,nbcd,n > data/statsNbcdZone.csv && \
# r.stats -Nc input=zones,Nlcd01v2,gap,nbcd fs=, >> data/statsNbcdNlcd01v2Zone.csv 2> data/statsNbcdNlcd01v2Zone.err &

# g.region rast=Nlcd06
# r.mask -o input=Nlcd06 maskcats="1 thru 95"

# echo grid_5min,nlcd06,gap,nbcd,n > data/statsNbcdNlcd06Grid5min.csv && \
# r.stats -Nc input=grid_5min,Nlcd06,gap,nbcd fs=, >> data/statsNbcdNlcd06Grid5min.csv 2> data/statsNbcdNlcd06Grid5min.err &

# echo state,county,nlcd06,gap,nbcd,n > data/statsNbcdNlcd06County.csv && \
# r.stats -Nc input=states,counties,Nlcd06,gap,nbcd fs=, >> data/statsNbcdNlcd06County.csv 2> data/statsNbcdNlcd06County.err &

# echo zone,nlcd06,gap,nbcd,n > data/statsNbcdNlcd06Zone.csv && \
# r.stats -Nc input=zones,Nlcd06,gap,nbcd fs=, >> data/statsNbcdNlcd06Zone.csv 2> data/statsNbcdNlcd06Zone.err &

r.mask -r

# run GRASS' cleanup routine
$GISBASE/etc/clean_temp

# remove session tmp directory:
rm -rf /tmp/grass6-$USER-$GIS_LOCK
