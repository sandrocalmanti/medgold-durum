##############################################################################
#
#     MED-GOLD Bias Correction
#
#    v1.0 02/07/2019 S. Calmanti - Initial code based on CSTools
#    v1.1 04/07/2019 S. Calmanti - Write NetCDF output with the sys5 standards
#
##############################################################################

#Clean all
rm(list = ls())

library(abind)
library(multiApply)
library(ncdf4)
library(CSTools)
library(zeallot)
library(lubridate)



#Set domain

domain <- list ( 
  list( fname = 'er-medgold',
        latmin = 43.5,
        latmax = 45.5,
        lonmin = 9.0,
        lonmax = 13.0),  
  list( fname = 'it-medgold',
        latmin = 39.5,
        latmax = 45.5,
        lonmin = 9.0,
        lonmax = 19.0)
)

idomain <- 2

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
        obs_var_min='0')
)

# exp_var_names <- c('tmin2m', 'tmax2m', 'totprec')
# nc_var_names <- c('mn2t24', 'mx2t24', 'tp')
# nc_var_longnames <-
#   c('Minimum temperature at 2 metres in the last 24 hours',
#     'Maximum temperature at 2 metres in the last 24 hours',
#     'Total precipitation'
#   )
# nc_var_units <- c('K', 'K', 'm')

#Start processing
for (ivar in seq(1, length(variable))) {
  print(paste(variable[[ivar]]$exp_var_name, variable[[ivar]]$exp_var_unit))
  start_time <- Sys.time() 
  
  
  exp <- list(list(
    name = 'ecmf',
    path = file.path(
      '/home/sandro/DATA/SEASONAL/ECMF/',
      '$VAR_NAME$_$EXP_NAME$_$START_DATE$.nc'
    ),
    nc_var_name = variable[[ivar]]$exp_var_name,
    var_min = variable[[ivar]]$exp_var_min
  ))
  
  
  obs <- list(list(
    name = 'ERA5',
    path = file.path(paste0('/home/sandro/DATA/REANALYSIS/ERA5/ERA5-EU-',variable[[ivar]]$obs_var_name,'.$YEAR$_',variable[[ivar]]$obs_var_suffix,'.nc')),
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
    latmin = domain[[idomain]]$latmin,
    latmax = domain[[idomain]]$latmax,
    lonmin = domain[[idomain]]$lonmin,
    lonmax = domain[[idomain]]$lonmax,
    grid = 'r1440x720',
    nprocs = 8
  )
  
  # c(exp_dat) %<-% CST_Load(
  #   var = variable[[ivar]]$exp_fil_name,
  #   exp = exp,
  #   sdates = sdates,
  #   storefreq = 'daily',
  #   output = 'lonlat',
  #   latmin = domain[[idomain]]$latmin,
  #   latmax = domain[[idomain]]$latmax,
  #   lonmin = domain[[idomain]]$lonmin,
  #   lonmax = domain[[idomain]]$lonmax,
  #   nprocs = 8
  # )
  
  attr(exp_dat, 'class') <- 's2dv_cube'
  attr(obs_dat, 'class') <- 's2dv_cube'
  
  exp_cst <- CST_Calibration(exp = exp_dat, obs = obs_dat)
#  exp_cst <- exp_dat
  
  end_time <- Sys.time()
  
  elt <- end_time - start_time
  print(elt)
  
  # PlotEquiMap(
  #   obs_dat$data[1, 1, 1, 1, ,],
  #   obs_dat$lon,
  #   obs_dat$lat,
  #   toptitle = 'ERA 5',
  #   title_scale = 0.5,
  #   filled.continents = FALSE
  # )
  # 
  # PlotEquiMap(
  #   exp_dat$data[1, 1, 1, 1, ,],
  #   exp_dat$lon,
  #   exp_dat$lat,
  #   toptitle = 'System 5',
  #   title_scale = 0.5,
  #   filled.continents = FALSE
  # )
  # 
  # PlotEquiMap(
  #   exp_cst$data[1, 1, 1, 1, ,],
  #   exp_cst$lon,
  #   exp_cst$lat,
  #   toptitle = 'System 5 - Bias Corrected',
  #   title_scale = 0.5,
  #   filled.continents = FALSE
  # )
  
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
    
    #Define filename
    ncfname <-
      paste0(
        '/home/sandro/DATA/SEASONAL/ECMF/BC/',
        variable[[ivar]]$exp_fil_name,
        '_ecmf_',
        fdate,
        '_',
        domain[[idomain]]$fname,
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