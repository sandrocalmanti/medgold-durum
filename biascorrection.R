##############################################################################
#
#     MED-GOLD Bias Correction
#
#    v1.0 02/07/2019 S. Calmanti - Initial code based on CSTools
#    v1.1 04/07/2019 S. Calmanti - Write NetCDF output with the sys5 standards
#
##############################################################################
#
# INFO - Batch mode submission
# R CMD BATCH biascorrection.R &
#
# --vanilla Combine --no-save, --no-restore, --no-site-file, --no-init-file and --no-environ
# --slave Make R run as quietly as possible
#
#Clean all
rm(list = ls())

library(abind)
library(multiApply)
library(ncdf4)
library(CSTools)
library(zeallot)
library(lubridate)

#Set your local path here
#
# This is the climate model baseline path.
exp_basepath <- '/fas_c/UTENTI/sandro/DATI/SEASONAL/ECMF/NC'
#
# This is the baseline path for the reference observational data
obs_basepath <- '/fas_c/UTENTI/sandro/DATI/REANALYSIS/ERA5'
#
# This is the baseline path for the bias corrected data
bco_basepath <- '/fas_impact2c/a/SANDRO_DA_SGI_ROTTO/sandro/MEDGOLD/BC'

#Set domain

domain <- list (
        fname = 'er-medgold',
        latmin = 43.5,
        latmax = 45.5,
        lonmin = 9.0,
        lonmax = 13.0)  

#Set dates
dayst <- '01'
monst <- '11'
yrst  <- 1988
yren  <- 2017
sdates <- paste0(as.character(seq(yrst, yren)), monst, dayst)


#Set variables

variable <- list(
  list( exp_fil_name='tmin2m',
        exp_var_name='mn2t24',
        exp_var_longname='Minimum temperature at 2 metres in the last 24 hours',
        exp_var_unit='K',
        exp_var_min='0',
        obs_var_name='t2m',
        obs_var_suffix='daymin',
        obs_var_min='0'),
  list( exp_fil_name='tmax2m',
        exp_var_name='mx2t24',
        exp_var_longname='Maximum temperature at 2 metres in the last 24 hours',
        exp_var_unit='K',
        exp_var_min='0',
        obs_var_name='t2m',
        obs_var_suffix='daymax',
        obs_var_min='0'),
  list( exp_fil_name='totprec',
        exp_var_name='tp',
        exp_var_longname='Total precipitation',
        exp_var_unit='m',
        exp_var_min='0',
        obs_var_name='tp',
        obs_var_suffix='daysum',
        obs_var_min='0'),
  list( exp_fil_name='rh',
        exp_var_name='rh',
        exp_var_longname='2 metre relative humidity',
        exp_var_unit=' ',
        exp_var_min='0',
        obs_var_name='rh',
        obs_var_suffix='dayavg',
        obs_var_min='0'),
  list( exp_fil_name='ssrd',
        exp_var_name='ssrd',
        exp_var_longname='Surface solar radiation downwards',
        exp_var_unit='J m**-2',
        exp_var_min='0',
        obs_var_name='ssrd',
        obs_var_suffix='daysum',
        obs_var_min='0'),
  list( exp_fil_name='wss',
        exp_var_name='wss',
        exp_var_longname='10 metre wind speed',
        exp_var_unit='m s**-1',
        exp_var_min='0',
        obs_var_name='wss',
        obs_var_suffix='dayavg',
        obs_var_min='0'),
  list( exp_fil_name='t2m',
        exp_var_name='t2m',
        exp_var_longname='10 metre temperature',
        exp_var_unit='K',
        exp_var_min='0',
        obs_var_name='t2m',
        obs_var_suffix='dayavg',
        obs_var_min='0')
)


#Start processing
for (ivar in seq(1, length(variable))) {
  print(paste(variable[[ivar]]$exp_var_name, variable[[ivar]]$exp_var_unit))
  start_time <- Sys.time() 
  
  
  exp <- list(list(
    name = 'ecmf',
    path = file.path(exp_basepath,'$YEAR$/$VAR_NAME$_$EXP_NAME$_$START_DATE$.nc'),
    nc_var_name = variable[[ivar]]$exp_var_name,
    var_min = variable[[ivar]]$exp_var_min
  ))
  
  
  obs <- list(list(
    name = 'ERA5',
    path = file.path(paste0(obs_basepath,'/ERA5-EU-',variable[[ivar]]$obs_var_name,'.$YEAR$_',variable[[ivar]]$obs_var_suffix,'.nc')),
    nc_var_name = variable[[ivar]]$obs_var_name,
    var_min = variable[[ivar]]$obs_var_min
  ))
  
  c(exp_dat, obs_dat) %<-% CST_Load(
    var = variable[[ivar]]$exp_fil_name,
    exp = exp,
    obs = obs,
    sdates = sdates,
    storefreq = 'daily',
    output = 'lonlat',
    latmin = domain$latmin,
    latmax = domain$latmax,
    lonmin = domain$lonmin,
    lonmax = domain$lonmax,
    grid = 'r1440x720',
    nprocs = 8,
    path_glob_permissive = TRUE)
  
  attr(exp_dat, 'class') <- 's2dv_cube'
  attr(obs_dat, 'class') <- 's2dv_cube'
  
  if ( variable[[ivar]]$exp_var_name != 'tp' ) {
    
    exp_cst <- CST_Calibration(exp = exp_dat, obs = obs_dat)
    
  } else { 
    
    exp_cst <- exp_dat
    
  }
  
  end_time <- Sys.time()
  
  elt <- end_time - start_time
  print(elt)
  
  #######################################################################
  #
  # Save the results of bias correction in netcdf.
  # Use the netcdf structure of sys5
  #
  # Note: to be implemented in a function that accepts the result of
  # CST_BiasCorrection or CST_BiasCorrection as an input
  #
  #######################################################################
  
  #Check dimensions
  nsdates <- dim(exp_cst$data)['sdate']
  ftime   <- dim(exp_cst$data)['ftime']
  nmem    <- dim(exp_cst$data)['member']
  nlon    <- dim(exp_cst$data)['lon']
  nlat    <- dim(exp_cst$data)['lat']
  
  for (idate in seq(1:nsdates)) {
    #Define time dim
    isdate <- 1 + (idate - 1) * ftime
    iedate <- idate * ftime
    sdate  <- exp_cst$Dates[[1]][isdate]
    edate  <- exp_cst$Dates[[1]][iedate]
    fdate  <-
      paste0(year(sdate),
             sprintf("%02d", month(sdate)),
             sprintf("%02d", day(sdate)))
    dates  <- exp_cst$Dates[[1]][isdate:iedate]
    nc_dates <-
      as.integer(24 * (as.Date(dates) - as.Date("1900-01-01 00:00:00")))
    
    #Define Members
    ensmem <- as.integer(seq(1:nmem))
    
    #Create dir for bias corrected data
    dirname <- paste0(bco_basepath,'/',year(sdate),'/')
    if ( !dir.exists(dirname)) {dir.create(dirname)}
    
    #Define filename
    ncfname <-
      paste0(dirname,
             variable[[ivar]]$exp_fil_name,
             '_ecmf_',
             fdate,
             '_',
             domain$fname,
             '.nc'
      )
    print(ncfname)
    
    #Define void dimensions. Values are added as variables to allow the modification
    #of attributes and to comply with the standard of other NetCDF packages
    londim <-
      ncdim_def(
        "longitude",
        units = '',
        vals = seq(1:length(exp_cst$lon)),
        unlim = FALSE,
        create_dimvar = FALSE
      )
    latdim <-
      ncdim_def(
        "latitude",
        units = '',
        vals = seq(1:length(exp_cst$lat)),
        unlim = FALSE,
        create_dimvar = FALSE
      )
    timedim <-
      ncdim_def(
        "time",
        units = '',
        vals = seq(1:length(nc_dates)),
        unlim = TRUE,
        create_dimvar = FALSE
      )
    ensdim  <-
      ncdim_def(
        "ensemble",
        units = '',
        vals = seq(1:length(ensmem)),
        unlim = FALSE,
        create_dimvar = FALSE
      )
    fillvalue <- 1e32
    
    #Define dim variables
    timvar <-
      ncvar_def("time", units = "hours since 1900-01-01 00:00:00.0", list(timedim))
    lonvar <- ncvar_def("longitude", units = "degrees_east", list(londim))
    latvar <- ncvar_def("latitude", units = "degrees_north", list(latdim))
    ensvar <- ncvar_def("ensemble", units = "", list(ensdim))
    
    #Define main variable
    ncvar <-
      ncvar_def(variable[[ivar]]$exp_var_name,
                variable[[ivar]]$exp_var_unit,
                list(londim, latdim, ensdim, timedim),
                fillvalue)
    
    ############
    #Create file
    ############
    ncout <-
      nc_create(ncfname, list(timvar, lonvar, latvar, ensvar, ncvar))
    
    #Put dim variables
    ncvar_put(ncout,
              timvar,
              nc_dates,
              start = c(1),
              count = length(nc_dates))
    ncvar_put(ncout,
              lonvar,
              exp_cst$lon,
              start = c(1),
              count = length(exp_cst$lon))
    ncvar_put(ncout,
              latvar,
              exp_cst$lat,
              start = c(1),
              count = length(exp_cst$lat))
    ncvar_put(ncout,
              ensvar,
              ensmem,
              start = c(1),
              count = length(ensmem))
    
    #Put main variable
    ncvar_put(ncout, ncvar, aperm(exp_cst$data[1, , idate, , , ], c(4, 3, 1, 2)))
    
    #Modify attributes
    ncatt_put(ncout, timvar, "calendar", "gregorian")
    ncatt_put(ncout, timvar, "standard_name", "time")
    ncatt_put(ncout, timvar, "long_name", "time")
    ncatt_put(ncout, timvar, "axis", "T")
    
    ncatt_put(ncout, lonvar, "standard_name", "longitude")
    ncatt_put(ncout, lonvar, "long_name", "longitude")
    ncatt_put(ncout, lonvar, "axis", "X")
    
    ncatt_put(ncout, latvar, "standard_name", "latitude")
    ncatt_put(ncout, latvar, "long_name", "latitude")
    ncatt_put(ncout, latvar, "axis", "Y")
    
    ncatt_put(ncout, ensvar, "axis", "E")
    
    ncatt_put(ncout, ncvar, "long_name", variable[[ivar]]$exp_var_longname)
    
    #Close file
    nc_close(ncout)
  }
  
}  #End loop over variables