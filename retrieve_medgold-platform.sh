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
  OUTSUFFIX=_ecmf_${iyy}`printf "%02d" "$month"`01.nc
  while read varname; do
    cd ${ARCHIVEGRIB}

    #Get data from the remote archive 
    #(consider upgrading/integrating this this with direct retrieval from the CDS
    FILEIN=ecmf_${iyy}${month}${varname}.grib
    FILEOUT=${ARCHIVENC}/${varname}${OUTSUFFIX}
    if [ -f ${FILEIN} ]; then
     echo "INFO    - ${ARCHIVEGRIB}/${FILEIN} exists, skip retrieval"
    else
     echo "INFO    - Retrieving ${ARCHIVEGRIB}/${FILEIN} ..."
     wget -o $STDOUT ${ARCHIVEREMOTE}/${iyy}/${month}/${FILEIN}
     if [ $? -ne 0 ]; then
      echo ERROR   - Retrieving ecmf_${iyy}${month}${varname}.grib >> $ERRLOG
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
  cd ${ARCHIVENC}
 if [ -f "10v${OUTSUFFIX}" -a -f "10u${OUTSUFFIX}" ]; then
  if [ -f "wss${OUTSUFFIX}" ]; then
   echo "WARNING - wss${OUTSUFFIX} exists, skip computation of wind speed"
  else
   echo "INFO    - Compute wss and rescale to wss2"
   cdo -merge 10v${OUTSUFFIX} 10u${OUTSUFFIX} wind${OUTSUFFIX}
   cdo -expr,'wss=sqrt(u10*u10+u10*u10)' wind${OUTSUFFIX} wss${OUTSUFFIX}
   rm -f wind${OUTSUFFIX}
  fi
 else
  echo WARNING - Wind components for ${iyy}-${month} not found. Skip computation of wind speed
 fi

 #Derive RH from Td.  Daily average temp is a byproduct from Tmin and Tmax
 if [ -f "tmax2m${OUTSUFFIX}" -a -f "tmin2m${OUTSUFFIX}" -a -f "2d${OUTSUFFIX}" ]; then
  if [ -f "rh${OUTSUFFIX}" ]; then
   echo "WARNING - rh${OUTSUFFIX} exists, skip computation of relative humidity"
  else
   echo "INFO    - Compute RH"
   cdo -merge tmax2m${OUTSUFFIX} tmin2m${OUTSUFFIX} tmp.nc
   cdo -expr,'t2m=(mx2t24+mn2t24)*0.5' tmp.nc t2m${OUTSUFFIX}
   cdo -merge 2d${OUTSUFFIX} t2m${OUTSUFFIX} temp${OUTSUFFIX}
   rm -f tmp.nc
   cdo -expr,'rh=100*((0.611*exp(5423*((1/273) - (1/d2m))))/(0.611*exp(5423*((1/273) - (1/t2m)))));' temp${OUTSUFFIX} rh${OUTSUFFIX}
   rm -f temp${OUTSUFFIX}
  fi
 else
   echo "WARNING - Temperature for ${iyy}-${month} not found. Check tmin, tmax, t2d. Skip computation of RH"
 fi


 done < retrieve_medgold-platform_months.in
done < retrieve_medgold-platform_years.in

DATA_SIZE=`du -sh|awk '{print $1}'`
ELAPSED_TIME=$(($SECONDS - $START_TIME)) 
echo ${DATA_SIZE} retrived and processed in ${ELAPSED_TIME} seconds
