#!/usr/bin/sh
#
#####
# VERSIONS
# 1.0 plain data retrieval (grib)
# 1.1 reformat data for CSTools
set +e
now=`date +%Y%m%d-%H%M%S`
START_TIME=$SECONDS
ERRLOG=retrieve_medgold-platform_months_$now.err
STDOUT=retrieve_medgold-platform_months_$now.log

WDIR=`pwd`
ARCHIVELOCAL='/home/sandro/DATA/SEASONAL/ECMF'
ARCHIVEREMOTE='http://data.med-gold.eu/ecmwf/o'

while read iyy; do
 ARCHIVEGRIB=${ARCHIVELOCAL}/GRIB/${iyy}
 ARCHIVENC=${ARCHIVELOCAL}/NC/${iyy}
 mkdir -p ${ARCHIVEGRIB}
 mkdir -p ${ARCHIVENC}
 while read month; do
  while read varname; do
    cd ${ARCHIVEGRIB}

    #Get data from the remote archive 
    #(consider upgrading/integrating this this with direct retrieval from the CDS
    FILEIN=ecmf_${iyy}${month}${varname}.grib
    FILEOUT=${ARCHIVENC}/${varname}_ecmf_${iyy}`printf "%02d" "$month"`01.nc
    if [ -f ${FILEIN} ]; then
     echo INFO - ${ARCHIVEGRIB}/${FILEIN} exists, skip retrieval
    else
     echo INFO - Retrieving ${ARCHIVEGRIB}/${FILEIN} ...
     wget -o $STDOUT ${ARCHIVEREMOTE}/${iyy}/${month}/${FILEIN}
     if [ $? -ne 0 ]; then
      echo ERROR - Retrieving ecmf_${iyy}${month}${varname}.grib >> $ERRLOG
     fi
    fi    

    if [ -f ${FILEOUT} ]; then
      echo WARNING - ${FILEOUT} exists, skip processing processing
    else
     #Convert to NetCDF
     grib_to_netcdf -o tmp.nc ${FILEIN}
     cdo -r -f nc copy tmp.nc ${FILEOUT}
     rm tmp.nc
     ncrename -v number,ensemble -d number,ensemble ${FILEOUT}
     ncatted -O -a axis,ensemble,m,c,"E" ${FILEOUT}

     #Process rainfall, derive daily cumulated
     if [ ${varname} == 'totprec' ]; then
      cd ${ARCHIVENC}
      mv ${FILEOUT} tmp.nc
      cdo -delete,timestep=1  -shifttime,-1day tmp.nc tmp_B.nc
      cdo -delete,timestep=-1 tmp.nc tmp_A.nc
      cdo -b 32 -shifttime,-1day -seltimestep,1 tmp.nc tmp_A1.nc

      cdo -b 32 -sub tmp_B.nc tmp_A.nc tmp_C.nc
      cdo -O -mergetime tmp_A1.nc tmp_C.nc tmp_D.nc
      cdo -b 32 -shifttime,1day tmp_D.nc ${FILEOUT}
      rm tmp*.nc
     fi 
    fi
    
    cd ${WDIR}
  done < retrieve_medgold-platform_vars.in

 #Derive wss using v10 and u10. Rescale wss10 to 2m for the computation of potential evpotranspiration

 #Derive RH from Td.  Deil average temp is a byproduct from Tmin and Tmax



 done < retrieve_medgold-platform_months.in
done < retrieve_medgold-platform_years.in

DATA_SIZE=`du -sh|awk '{print $1}'`
ELAPSED_TIME=$(($SECONDS - $START_TIME)) 
echo ${DATA_SIZE} retrived and processed in ${ELAPSED_TIME} seconds
