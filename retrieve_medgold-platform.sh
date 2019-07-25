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


#Remote archive
pth_rmt='http://data.med-gold.eu/ecmwf/o'

while read iyy; do
 while read month; do
  while read varname; do
    FILEOUT=${varname}_ecmf_${iyy}`printf "%02d" "$month"`01.nc
    wget -o $STDOUT ${pth_rmt}/${iyy}/${month}/ecmf_${iyy}${month}${varname}.grib
    grib_to_netcdf -o tmp.nc ecmf_${iyy}${month}${varname}.grib
    cdo -r -f nc copy tmp.nc ${FILEOUT}
    rm tmp.nc
    ncrename -v number,ensemble -d number,ensemble ${FILEOUT}
    ncatted -O -a axis,ensemble,m,c,"E" ${FILEOUT}
    if [ $? -ne 0 ]; then
      echo ERROR - Retrieving ecmf_${iyy}${month}${varname}.grib >> $ERRLOG
    fi

    #Process rainfall, derive daily cumulated
    if [ ${varname} == 'totprec' ]; then
      mv ${FILEOUT} tmp.nc
      cdo -delete,timestep=1  -shifttime,-1day tmp.nc tmp_B.nc
      cdo -delete,timestep=-1 tmp.nc tmp_A.nc
      cdo -b 32 -shifttime,-1day -seltimestep,1 tmp.nc tmp_A1.nc

      cdo -b 32 -sub tmp_B.nc tmp_A.nc tmp_C.nc
      cdo -O -mergetime tmp_A1.nc tmp_C.nc tmp_D.nc
      cdo -b 32 -shifttime,1day tmp_D.nc ${FILEOUT}
      rm tmp*.nc
    fi
  done < retrieve_medgold-platform_vars.in

 #Derive wss using v10 and u10. Rescale wss10 to 2m for the computation of potential evpotranspiration

 #Derive RH from Td.  Deil average temp is a byproduct from Tmin and Tmax



 done < retrieve_medgold-platform_months.in
done < retrieve_medgold-platform_years.in

DATA_SIZE=`du -sh|awk '{print $1}'`
ELAPSED_TIME=$(($SECONDS - $START_TIME)) 
echo ${DATA_SIZE} retrived and processed in ${ELAPSED_TIME} seconds
