## Everything in this file and any files in the R directory are sourced during `simInit()`;
## all functions and objects are put into the `simList`.
## To use objects, use `sim$xxx` (they are globally available to all modules).
## Functions can be used inside any function that was sourced in this module;
## they are namespaced to the module, just like functions in R packages.
## If exact location is required, functions will be: `sim$.mods$<moduleName>$FunctionName`.
defineModule(sim, list(
  name = "ALT_SpaDES",
  description = paste("Determines active layer thickness"),
  keywords = c("permafrost","Active Layer Thickness"),
  authors = c(
    person("Madeleine", "Garibaldi", email = "madeleine.garibaldi@nrcan-rncan.gc.ca", role = c("aut", "cre")),
    person(c("Oleksandra (Sasha)"), "Hararuk", email = "oleksandra.hararuk@nrcan-rncan.gc.ca", role = c("aut","cre"))),
  childModules = character(0),
  version = list(ALT_SpaDES = "1.0.0.0000"),
  timeframe = as.POSIXlt(c(NA, NA)),
  timeunit = "year",
  citation = list("citation.bib"),
  documentation = list("NEWS.md", "README.md", "ALT_SpaDES.Rmd"),
  reqdPkgs = list("SpaDES.core (>= 3.1.2)", "ggplot2", "data.table","purrr", "dplyr"),
  parameters = bindrows(
    #defineParameter("paramName", "paramClass", value, min, max, "parameter description"),
    defineParameter(".plots", "character", "screen", NA, NA,
                    "Used by Plots function, which can be optionally used here"), #use interally
    defineParameter(".plotInitialTime", "numeric", start(sim), NA, NA,
                    "Describes the simulation time at which the first plot event should occur."),
    defineParameter(".plotInterval", "numeric", NA, NA, NA,
                    "Describes the simulation time interval between plot events."),
    defineParameter("grid_ppp", "numeric", 25, NA, NA, "Sets the number of grid points per period. This determines 
                    how often the function is sampled within each sine wave. Increasing this value will ensure 
                    all crossings of temperature = 0 but can increase processing time. If this value is decreased 
                    processing time will increase but crossings may be missed."),
    defineParameter("months", "numeric", c(5,10), NA, NA, "sets the months for which the ALT Solver is run and for
                    which roots (i.e. active layer thicknesses) are calculated. These months should correspond to 
                    the timing of maximum thaw in order to accurately predict active layer thickness. Running 
                    for months where seasonal frost might be present may lead to errouneous estimations of ALT. 
                    The default is May (5) to October (10). Increasing the number of months will 
                    increase processing time."),
    defineParameter("overresolve", "numeric", 1.2, NA, NA, "multiplier than increases the number of grid points beyond
                    the minimum required by grid_ppp. Increasing this value will increase processing time"),
    defineParameter("plot_check", "logical", FALSE, NA, NA, "This replaces the .plot parameter for this module. 
                    The Default is FALSE. If set to TRUE module will create a diagnostic plot for each month showing 
                    the behavior of the ALT Solver Function and can indicate the solver is saving the correct z for each 
                    month. This can be used for validation and debugging, however it greatly increases the processing 
                    time. Plots can only be save to the screen."),
    defineParameter("tol", "numeric", 1e-10, NA ,NA, "tolerance which sets the numerical accuracy (number of decimal 
                    points) reported for the active layer thickness"),
    defineParameter("verbose", "logical", FALSE, NA, NA, "If TRUE, gives diagnostice messages while the solver runs.
                     Can be useful for development and debugging but increases processing time. The default is FALSE."),
    defineParameter("z_search", "numeric", c(0,5), NA, NA,
                    "Range of depths (z) in meters for the ALT Solver. Default is 0-5m. The module will produce 
                    results up to the maximum provided. This can lead to erroneous prediction of active layer 
                    thickness where no permafrost is present. As the parameters depend on calibration data it is 
                    recommended to keep the maximum for z_search within the calibration depth range. The default 
                    parameter values provided in the gParameters input were calibrated and validated for depths up 
                    to 3m therefore running the module for depths much greater than 3m may produce inaccurate results. 
                    It is recommended to limit the model run to within typical active layer thicknesses (< 5m) as 
                    the model may still produces an ALT value which exceed any known ALT."),
    ## .seed is optional: `list('init' = 123)` will `set.seed(123)` for the `init` event only.
    defineParameter(".seed", "list", list(), NA, NA,
                    "Named list of seeds to use for each event (names)."),
    defineParameter(".useCache", "logical", FALSE, NA, NA,
                    "Should caching of events or module be used?")
    ## Opt-in: pin a fixed cacheId per event so a pre-seeded Google Drive folder
    ## can short-circuit a deterministic event to a download. To enable,
    ## uncomment the block below (the leading `,` is valid R as a continuation),
    ## edit the cacheId/cloudFolderID, and set `.useCache` above to include the
    ## relevant event name(s), e.g. `c("init")`.
    # ,defineParameter(".useCacheArgs", "list",
    #                  list(init = list(cacheId       = "_v1.0",
    #                                   useCloud      = TRUE,
    #                                   cloudFolderID = "<google-drive-folder-id>")),
    #                  NA, NA,
    #                  paste("Optional named list, keyed by event name, of extra arguments",
    #                        "passed to reproducible::Cache() for that event. Useful for",
    #                        "pinning a fixed cacheId so a pre-seeded cloud folder can",
    #                        "short-circuit a deterministic event."))
  ),
  inputObjects = bindrows(
    #expectsInput("objectName", "objectClass", "input object description", sourceURL, ...),
    expectsInput("gParameters", objectClass = "data.table", desc = "Data table input with the parameters 
                 required in the ALT Solver. The columns of this data table are Landcover, 
                 d (damping depth), k (decay in annual temperature), b (the amplitude modifier), 
                 p (the period modifier). This input can be created using the GT_Calibration_SpaDES 
                 module if the parameters need to be calibrated for new environment and/or land cover types. 
                 Currently the parameters provided in this data table have been calibrated for peatland land covers.",sourceURL = NA),
    expectsInput("siteInfo", objectClass = "data.table", desc = "Data table input with the site information. 
                 The columns of this data table are Site (the site names), Class, Year, Ts 
                 (the annual ground surface temperature in Kelvin), and A 
                 (the ground surface temperature amplitude, the difference between the monthly maximum 
                 and minimum ground surface temperature). The class column a user defined division based on what 
                 impacts the parameters d and k.Sample data is provided to show module function but 
                 should be replaced with real data before use.This data table can be generated using the 
                 GS_Temp_SpaDES module.", sourceURL = NA)
  ),
  outputObjects = bindrows(
    #createsOutput("objectName", "objectClass", "output object description", ...),
    createsOutput("ALTfinal", objectClass = "data.table", desc = "Data table containing the final active layer 
                  thickness (in meters) for each site and year in the siteInfo data table input. 
                  For sites with no permafrost and no ALT the module will out put an NA or a blank cell 
                  when converted to a .csv file. The month assigned to this value will be September (9). If September 
                  is not used the month assigned will be the earliest.")
  )
))

doEvent.ALT_SpaDES = function(sim, eventTime, eventType) {
  switch(
    eventType,
    init = {
      sim <- Init(sim)
      ### check for more detailed object dependencies:
      ### (use `checkObject` or similar)

      # do stuff for this event

      # schedule future event(s)
      sim <- scheduleEvent(sim, start(sim),
                    "ALT_SpaDES", "ALTcalc", eventPriority = 1)
      sim <- scheduleEvent(sim, start(sim),
                    "ALT_SpaDES", "ALTfinal", eventPriority = 2)
      if (!any(is.na(P(sim)$.plots))) {
        scheduleEvent(sim, start(sim),
                      "ALT_SpaDES", "plots", eventPriority = 3)
      }
      
    },
    plot = {
      # ! ----- EDIT BELOW ----- ! #
      # do stuff for this event

      plotFun(sim) # example of a plotting function
      # schedule future event(s)

      # e.g.,
      #sim <- scheduleEvent(sim, time(sim) + P(sim)$.plotInterval, "ALThickness", "plot")

      # ! ----- STOP EDITING ----- ! #
    },
     
      # ! ----- EDIT BELOW ----- ! #
      # do stuff for this event
    ALTcalc= {
      sim <- ALTestimation(sim)
      scheduleEvent(sim, time(sim) + 1,
                    "ALT_SpaDES", "ALTcalc", eventPriority = 1)

      # ! ----- STOP EDITING ----- ! #
    },
    ALTfinal = {
      # ! ----- EDIT BELOW ----- ! #
      # do stuff for this event
      sim <- ALTmaximum(sim)
      
      scheduleEvent(sim, time(sim) + 1,
                    "ALT_SpaDES", "ALTfinal", eventPriority = 2)

      # ! ----- STOP EDITING ----- ! #
    },
    
    plots = {
      sim <- plotALT(sim)
      
      scheduleEvent(sim, time(sim) + 1,
                    "ALT_SpaDES", "plots", eventPriority = 3)
    },
    warning(noEventWarning(sim)) # do I need this? This line seems to be causing issues when I try to install from Github
  )
  return(invisible(sim)) # do I need this?
}

### template initialization
Init <- function(sim) {
  # # ! ----- EDIT BELOW ----- ! #
  requiredColssiteInfo <- c("Site","Class","Year","Ts","A")
  missingColssiteInfo <- setdiff(requiredColssiteInfo, names(sim$siteInfo))
  
  if (length(missingColssiteInfo) > 0) {
    stop(
      paste0(
        "siteInfo is missing required column(s): ",
        paste(missingColssiteInfo, collapse = ", "),
        "\nColumns found: ",
        paste(names(sim$siteInfo), collapse = ", ")
      )
    )
  }
  if (any(sim$siteInfo$Ts < 100, na.rm = TRUE)) {
    stop(
      paste0(
        "Invalid values found in siteInfo$Ts.Must be in Kelvin ",
      )
    )
  }
  
  requiredColsgParameters <- c("Class","d","k","b","p")
  missingColsgParameters <- setdiff(requiredColsgParameters, names(sim$gParameters))
  
  if (length(missingColsgParameters) > 0) {
    stop(
      paste0(
        "gParameters is missing required column(s): ",
        paste(missingColsgParameters, collapse = ", "),
        "\nColumns found: ",
        paste(names(sim$gParameters), collapse = ", ")
      )
    )
  }
  
  siteParameters = merge(sim$siteInfo,sim$gParameters, by="Class")
  
  if (length(P(sim)$months) != 2) {
    stop("'months' must contain exactly two values: c(minMonth, maxMonth)")
  }
  
  months <- data.table(
    month = seq(P(sim)$months[1], P(sim)$months[2])
  )
  
  
  ALTparameters <- data.table(NULL)
  ALTparameters <- cross_join(siteParameters, months)
  mod$ALTparameters <- ALTparameters
  # ! ----- STOP EDITING ----- ! #

  return(invisible(sim))
}

### template for your event1
ALTestimation <- function(sim) {
  # ! ----- EDIT BELOW ----- ! #
  ALTparameters2 <- copy(mod$ALTparameters)
  ALTparameters2[
    ,
    ALT := pmap_dbl(
      list(Ts, A, month, p, k, d, b),
      ALT_Solver_dataT,
      grid_ppp = P(sim)$grid_ppp,
      overresolve = P(sim)$overresolve,
      plot_check = P(sim)$plot_check,
      tol = P(sim)$tol,
      verbose = P(sim)$verbose,
      z_search = P(sim)$z_search
    )
  ]
  mod$ALTparameters <- ALTparameters2

  # ! ----- STOP EDITING ----- ! #
  return(invisible(sim))
}

### template for your event2
ALTmaximum <- function(sim) {
  # ! ----- EDIT BELOW ----- ! #
    ALTparameters2 <- copy(mod$ALTparameters)
    sim$ALTfinal <- ALTparameters2[
      ,
      if (all(is.na(ALT))) {
        if (any(month == 9)) {
          .SD[month == 9]
        } else {
          .SD[1]
        }
      } else {
        .SD[which.max(replace(ALT, is.na(ALT), -Inf))]
      },
      by = .(Year, Site)
    ]
    
    fwrite(
      sim$ALTfinal,
      file.path(outputPath(sim), "ALTfinal.csv")
    )
  # ! ----- STOP EDITING ----- ! #
  return(invisible(sim))
}

plotALT <- function(sim) {
  
  checkPath(file.path(outputPath(sim), "figures"), create = TRUE)
  
  Plots(...,
        types = P(sim)$.plots)
  
  return(invisible(sim))
}

plotFun <- function(sim) {
  # ! ----- EDIT BELOW ----- ! #
  # do stuff for this event
  sampleData <- data.frame("TheSample" = sample(1:10, replace = TRUE))
  Plots(sampleData, fn = ggplotFn) # needs ggplot2
  
  # ! ----- STOP EDITING ----- ! #
  return(invisible(sim))
}
.inputObjects <- function(sim) {
  # Any code written here will be run during the simInit for the purpose of creating
  # any objects required by this module and identified in the inputObjects element of defineModule.
  # This is useful if there is something required before simulation to produce the module
  # object dependencies, including such things as downloading default datasets, e.g.,
  # downloadData("LCC2005", modulePath(sim)).
  # Nothing should be created here that does not create a named object in inputObjects.
  # Any other initiation procedures should be put in "init" eventType of the doEvent function.
  # Note: the module developer can check if an object is 'suppliedElsewhere' to
  # selectively skip unnecessary steps because the user has provided those inputObjects in the
  # simInit call, or another module will supply or has supplied it. e.g.,
  # if (!suppliedElsewhere('defaultColor', sim)) {
  #   sim$map <- Cache(prepInputs, extractURL('map')) # download, extract, load file from url in sourceURL
  # }

  cacheTags <- c(currentModule(sim), "function:.inputObjects") ## uncomment this if Cache is being used
  dPath <- asPath(getOption("reproducible.destinationPath", dataPath(sim)), 1)
  message(currentModule(sim), ": using dataPath '", dPath, "'.")

  # ! ----- EDIT BELOW ----- ! #
  if(!suppliedElsewhere("siteInfo", sim)){
    sim$siteInfo <- fread(file.path(paths(sim)$modulePath, currentModule(sim), "data", "siteInfo.csv"))
  }
  if(!suppliedElsewhere("gParameters", sim)){
    sim$gParameters <- fread(file.path(paths(sim)$modulePath, currentModule(sim), "data", "gParameters.csv"))
  }
  # ! ----- STOP EDITING ----- ! #
  return(invisible(sim))
}

ggplotFn <- function(data, ...) {
  ggplot2::ggplot(data, ggplot2::aes(TheSample)) +
    ggplot2::geom_histogram(...)
}

