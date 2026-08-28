## Everything in this file and any files in the R directory are sourced during `simInit()`;
## all functions and objects are put into the `simList`.
## To use objects, use `sim$xxx` (they are globally available to all modules).
## Functions can be used inside any function that was sourced in this module;
## they are namespaced to the module, just like functions in R packages.
## If exact location is required, functions will be: `sim$.mods$<moduleName>$FunctionName`.
defineModule(sim, list(
  name = "ALThickness",
  description = paste("Determines active layer thickness"),
  keywords = c("permafrost","Active Layer Thickness"),
  authors = c(
    person("Madeleine", "Garibaldi", email = "madeleine.garibaldi@nrcan-rncan.gc.ca", role = c("aut", "cre")),
    person(c("Oleksandra (Sasha)"), "Hararuk", email = "oleksandra.hararuk@nrcan-rncan.gc.ca", role = c("aut","cre"))),
  childModules = character(0),
  version = list(ALThickness = "1.0.0.0000"),
  timeframe = as.POSIXlt(c(NA, NA)),
  timeunit = "year",
  citation = list("citation.bib"),
  documentation = list("NEWS.md", "README.md", "ALThickness.Rmd"),
  reqdPkgs = list("SpaDES.core (>= 3.1.2)", "ggplot2", "data.table",),
  parameters = bindrows(
    #defineParameter("paramName", "paramClass", value, min, max, "parameter description"),
    defineParameter(".plots", "character", "screen", NA, NA,
                    "Used by Plots function, which can be optionally used here"),
    defineParameter(".plotInitialTime", "numeric", start(sim), NA, NA,
                    "Describes the simulation time at which the first plot event should occur."),
    defineParameter(".plotInterval", "numeric", NA, NA, NA,
                    "Describes the simulation time interval between plot events."),
    defineParameter(".saveInitialTime", "numeric", NA, NA, NA,
                    "Describes the simulation time at which the first save event should occur."),
    defineParameter(".saveInterval", "numeric", NA, NA, NA,
                    "This describes the simulation time interval between save events."),
    defineParameter(".studyAreaName", "character", NA, NA, NA,
                    "Human-readable name for the study area used - e.g., a hash of the study",
                          "area obtained using `reproducible::studyAreaName()`"),
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
    expectsInput("gParameters", objectClass = "data.table", desc = "Calibrated model parameters based on peatland type", sourceURL = NA),
    expectsInput("siteInfo", objectClass = "data.table", desc = "Annual model variables including year, surface temperature, temperature amplitude, and site information")
  ),
  outputObjects = bindrows(
    #createsOutput("objectName", "objectClass", "output object description", ...),
    createsOutput("ALTfinal", objectClass = "data.table", desc = "Active layer thickness")
  )
))

doEvent.ALThickness = function(sim, eventTime, eventType) {
  switch(
    eventType,
    init = {
      ### check for more detailed object dependencies:
      ### (use `checkObject` or similar)

      # do stuff for this event
      # MG Load data tables?
      
      #MG Site information 
      siteInfo <- sim$siteInfo
      
      # MG Calibrated model parameters based on peatland type
      # Can change based on calibration script
      gParameters <- sim$gParameters 
      
      #MG merge into one to assign model parameters to site based on peatland 
      #class
      siteParameters <- merge (siteInfo,gParameters, by="Peatland")
      
      #MG make a data table for the monthly ALT calculation
      #Can be adjusted by user
      months = data.table(month = 5:10)
      
      #MG make a new data table and combine the data tables so each site has 
      #an entry for each month
      ALTparameters <- data.table(NULL)
      ALTparameters <- cross_join(siteParameters, months)
      
      #MG run the ALT solver function for each month at each site
      #In the function there are 6 parameters which have a default that can be
      #changed by the user
      
      ALTparameters[
        ,
        roots := mapply(
          function(Ts, A, month, p, k, d, b) {
            r <- ALT_Solver(
              Ts, A, month, p, k, d, b,
              #z_search,     # range of depths to search for depth where 
                             # temperature equals 0
              #ppp_grid,     # grid points per period --> smaller may miss
                             # depths where temperature equals 0, larger may
                             # may increase processing time
              #overresolve,  # multiplier that increases the number of grid
                             # points beyond the minimum required by grid_ppp
              #tol,          # tolerance which assigns the number of decimal 
                             # points for output depths
              verbose = FALSE, # print function progress messages (default is True)
              plot_check = FALSE # creates graph of roots for visual verification
            )$roots
            if (length(r) == 0) NA_real_ else min(r)
          },
          Ts, A, month, p, k, d, b
        )
      ]
      
      # MG removes NAs and calculates annual maximum thaw depth (ALT)
      ALTparameters <- ALLparameters[!is.na(roots)]
      ALTfinal <- ALTparameters[
        ,
        .SD[which.max(roots)],
        by = .(Year, Site)
      ]
      
      

      # schedule future event(s)
      sim <- scheduleEvent(sim, P(sim)$.plotInitialTime, "ALThickness", "plot")
      sim <- scheduleEvent(sim, P(sim)$.saveInitialTime, "ALThickness", "save")
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
    save = {
      # ! ----- EDIT BELOW ----- ! #
      # do stuff for this event

      # e.g., call your custom functions/methods here
      # you can define your own methods below this `doEvent` function

      # schedule future event(s)

      # e.g.,
      # sim <- scheduleEvent(sim, time(sim) + P(sim)$.saveInterval, "ALThickness", "save")

      # ! ----- STOP EDITING ----- ! #
    },
    event1 = {
      # ! ----- EDIT BELOW ----- ! #
      # do stuff for this event

      # e.g., call your custom functions/methods here
      # you can define your own methods below this `doEvent` function

      # schedule future event(s)

      # e.g.,
      # sim <- scheduleEvent(sim, time(sim) + increment, "ALThickness", "templateEvent")

      # ! ----- STOP EDITING ----- ! #
    },
    event2 = {
      # ! ----- EDIT BELOW ----- ! #
      # do stuff for this event

      # e.g., call your custom functions/methods here
      # you can define your own methods below this `doEvent` function

      # schedule future event(s)

      # e.g.,
      # sim <- scheduleEvent(sim, time(sim) + increment, "ALThickness", "templateEvent")

      # ! ----- STOP EDITING ----- ! #
    },
    warning(noEventWarning(sim))
  )
  return(invisible(sim))
}

### template initialization
Init <- function(sim) {
  # # ! ----- EDIT BELOW ----- ! #

  # ! ----- STOP EDITING ----- ! #

  return(invisible(sim))
}
### template for save events
Save <- function(sim) {
  # ! ----- EDIT BELOW ----- ! #
  # do stuff for this event
  sim <- saveFiles(sim)

  # ! ----- STOP EDITING ----- ! #
  return(invisible(sim))
}

### template for plot events
plotFun <- function(sim) {
  # ! ----- EDIT BELOW ----- ! #
  # do stuff for this event
  sampleData <- data.frame("TheSample" = sample(1:10, replace = TRUE))
  Plots(sampleData, fn = ggplotFn) # needs ggplot2

  # ! ----- STOP EDITING ----- ! #
  return(invisible(sim))
}

### template for your event1
Event1 <- function(sim) {
  # ! ----- EDIT BELOW ----- ! #
  # THE NEXT TWO LINES ARE FOR DUMMY UNIT TESTS; CHANGE OR DELETE THEM.
  # sim$event1Test1 <- " this is test for event 1. " # for dummy unit test
  # sim$event1Test2 <- 999 # for dummy unit test

  # ! ----- STOP EDITING ----- ! #
  return(invisible(sim))
}

### template for your event2
Event2 <- function(sim) {
  # ! ----- EDIT BELOW ----- ! #
  # THE NEXT TWO LINES ARE FOR DUMMY UNIT TESTS; CHANGE OR DELETE THEM.
  # sim$event2Test1 <- " this is test for event 2. " # for dummy unit test
  # sim$event2Test2 <- 777  # for dummy unit test

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

  #cacheTags <- c(currentModule(sim), "function:.inputObjects") ## uncomment this if Cache is being used
  dPath <- asPath(getOption("reproducible.destinationPath", dataPath(sim)), 1)
  message(currentModule(sim), ": using dataPath '", dPath, "'.")

  # ! ----- EDIT BELOW ----- ! #

  # ! ----- STOP EDITING ----- ! #
  return(invisible(sim))
}

ggplotFn <- function(data, ...) {
  ggplot2::ggplot(data, ggplot2::aes(TheSample)) +
    ggplot2::geom_histogram(...)
}

