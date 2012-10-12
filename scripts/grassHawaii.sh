#!/bin/bash -v

    # path to GRASS binaries and libraries:
    export GISBASE=/usr/lib/grass64
    export PATH=$PATH:$GISBASE/bin:$GISBASE/scripts
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$GISBASE/lib
    
    # use process ID (PID) as lock file number:
    export GIS_LOCK=$$
    
    # path to GRASS settings file
    export GISRC=./.grassrc6
    EOF
    
    cat <<EOF
    g.gisenv set=LOCATION_NAME=\$GIS_LOCK
    eval \$(g.gisenv)
    mkdir -p \$GISDBASE/\$GIS_LOCK
    g.mapset -c mapset=temp
    r.in.gdal in=aeaGrid5min${REGION}.img out=grid_5min location=${REGION}
    # g.gisenv set=LOCATION_NAME=${REGION}
    # g.gisenv set=MAPSET=PERMANENT
    g.mapset mapset=PERMANENT location=${REGION}
    rm -rf \$GISDBASE/\$GIS_LOCK/temp
    # g.rename rast=aeaGrid5min${REGION}.img,grid_5min
    r.in.gdal input=pad-us/PADUS1_2_regions/PADUS1_2_${REGION}_GAP.tif output=gap
    EOF
  r.in.gdal input=nlcd/hi_landcover_wimperv_9-30-08_se5.img output=Nlcd01v1HI
    r.mapcalc MASK="if( Nlcd01v1HI > 0, 1, null())"
    echo grid_5min,Nlcd01v1HI,gap,n > statsNlcd01v1HI.csv
    r.stats -c input=grid_5min,Nlcd01v1HI,gap fs=, >> statsNlcd01v1HI.csv
    r.mask -r
    echo grid_5min,n > gridNlcd01v1HI.csv
    r.stats -c input=grid_5min fs=, >> gridNlcd01v1HI.csv
    EOF
