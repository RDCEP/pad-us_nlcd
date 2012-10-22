
all: nlcd2006 ak hi pr

nlcd2006:
	-wget -nc 'http://gisdata.usgs.gov/TDDS/DownloadFile.php?TYPE=nlcd2006&FNAME=NLCD2006_landcover_4-20-11_se5.zip' \
-O NLCD2006_landcover_4-20-11_se5.zip
	mkdir NLCD2006_landcover_4-20-11_se5
	7za e -o NLCD2006_landcover_4-20-11_se5 NLCD2006_landcover_4-20-11_se5.zip

nlcd2006change:
	-wget -nc 'http://gisdata.usgs.gov/TDDS/DownloadFile.php?TYPE=nlcd2006&FNAME=NLCD2006_landcover_change_pixels_5-4-11_se5.zip' -O NLCD2006_landcover_change_pixels_5-4-11_se5.zip
	mkdir NLCD2006_landcover_change_pixels_5-4-11_se5
	unzip -d NLCD2006_landcover_change_pixels_5-4-11_se5 NLCD2006_landcover_change_pixels_5-4-11_se5.zip  

nlcd2001:
	-wget -nc 'http://gisdata.usgs.gov/TDDS/DownloadFile.php?TYPE=nlcd2001v2&FNAME=NLCD2001_landcover_v2_2-13-11.zip' -O NLCD2001_landcover_v2_2-13-11.zip
	mkdir NLCD2001_landcover_v2_2-13-11
	unzip -n -d NLCD2001_landcover_v2_2-13-11 NLCD2001_landcover_v2_2-13-11.zip
	-wget -nc 'http://gisdata.usgs.gov/TDDS/DownloadFile.php?TYPE=nlcdconus&FNAME=nlcd2001_canopy_mosaic_1-29-08.zip' -O nlcd2001_canopy_mosaic_1-29-08.zip
	-wget -nc 'http://www.mrlc.gov/nlcd01_leg.php'
	-wget -nc 'http://www.mrlc.gov/includes/custom.css'

nlcd01v1URL = 'http://gisdata.usgs.gov/TDDS/DownloadFile.php?TYPE=nlcd2001v1&FNAME=nlcd2001_landcover_mosaic_2-20-07.zip'

nlcd01v1:
	-wget -nc $(nlcd01v1URL) -O nlcd2001_landcover_mosaic_2-20-07.zip
	unzip nlcd2001_landcover_mosaic_2-20-07.zip -x 'nlcd2001_landcover_mosaic_2-20-07/nlcd_2001_landcover_metadata/*'
	gdalinfo nlcd2001_landcover_mosaic_2-20-07/nlcd2001_mosaic_2-20-07.img > nlcd2001_landcover_mosaic_2-20-07/nlcd2001_mosaic_2-20-07.gdalinfo

ak:
	-wget -nc 'http://gisdata.usgs.gov/TDDS/DownloadFile.php?TYPE=nlcdak&FNAME=AK_NLCD_2001_land_cover_3-13-08.zip' -O AK_NLCD_2001_land_cover_3-13-08.zip
	7za e -o. AK_NLCD_2001_land_cover_3-13-08.zip AK_NLCD_2001_land_cover_3-13-08/ak_nlcd_2001_land_cover_3-13-08_se5.ige AK_NLCD_2001_land_cover_3-13-08/ak_nlcd_2001_land_cover_3-13-08_se5.img AK_NLCD_2001_land_cover_3-13-08/ak_nlcd_2001_land_cover_3-13-08_se5.rrd

hi:
	-wget -nc 'http://gisdata.usgs.gov/TDDS/DownloadFile.php?TYPE=nlcdhi&FNAME=HI_landcover_wimperv_9-30-08_se5.zip' -O HI_landcover_wimperv_9-30-08_se5.zip
	7za e HI_landcover_wimperv_9-30-08_se5.zip hi_landcover_wimperv_9-30-08_se5.img hi_landcover_wimperv_9-30-08_se5.rrd

pr:
	-wget -nc 'http://gisdata.usgs.gov/TDDS/DownloadFile.php?TYPE=nlcdpr&FNAME=PR_landcover_wimperv_10-28-08_se5.zip' -O PR_landcover_wimperv_10-28-08_se5.zip
	7za e PR_landcover_wimperv_10-28-08_se5.zip pr_landcover_wimperv_10-28-08_se5.img pr_landcover_wimperv_10-28-08_se5.rrd


.PHONY: nlcd2006 nlcd2006change nlcd2001 nlcd01v1 ak hi pr