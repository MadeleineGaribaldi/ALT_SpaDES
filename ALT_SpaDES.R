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
  reqdPkgs = list("SpaDES.core (>= 3.1.2)", "ggplot2", "data.table","purrr", "dyplr"),
  parameters = bindrows(
    #defineParameter("paramName", "paramClass", value, min, max, "parameter description"),
    defineParameter(".plots", "character", "screen", NA, NA,
                    "Used by Plots function, which can be optionally used here"),
    defineParameter(".plotInitialTime", "numeric", start(sim), NA, NA,
                    "Describes the simulation time at which the first plot event should occur."),
    defineParameter(".plotInterval", "numeric", NA, NA, NA,
                    "Describes the simulation time interval between plot events."),
    defineParameter("grid_ppp", "numeric", 25, NA, NA, "grid points per period. Should sample often enough within each
                    sine wave to detect all temperature crossings. Increasing will increase processing time, decreasing
                    may miss crossing"),
    defineParameter("overresolve", "numeric", 1.2, NA, NA, "multiplier than increases the number of grid points beyond
                    the minimum required by grid_ppp. Increasing this value will increase processing time"),
    defineParameter("plot_check", "logical", FALSE, NA, NA, "If TRUE, produces a diagnostic plot showing the behavior
                    of the ALT_Solver function over the search range. Can be useful for validation and debugging
                    but increases processing time"),
    defineParameter("tol", "numeric", 1e-10, NA ,NA, "number of decimal points for each root"),
    defineParameter("verbose", "logical", FALSE, NA, NA, "If TRUE, gives diagnostice messages while the solver runs.
                     Can be useful for development and debugging but increases processing time"),
    defineParameter("z_search", "numeric", NA, 0, 5,
                    "range of depths the ALT_solver in meters. Increasing this number will increase processing time.
                    may give erroneous permafrost presence for depths > 5m"),
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
    expectsInput("gParameters", objectClass = "data.table", desc = "Calibrated model parameters based on peatland type", "sourceURL = https://drive.google.com/drive/folders/1_Wo6-2t-nHULE4kot4DUAWxg3e9fKWON"),
    expectsInput("siteInfo", objectClass = "data.table", desc = "Annual model variables including year, surface temperature, temperature amplitude, and site information", "sourceURL = https://drive.google.com/drive/folders/1_Wo6-2t-nHULE4kot4DUAWxg3e9fKWON")
  ),
  outputObjects = bindrows(
    #createsOutput("objectName", "objectClass", "output object description", ...),
    createsOutput("ALTfinal", objectClass = "data.table", desc = "Active layer thickness")
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
      scheduleEvent(sim, start(sim),
                    "ALT_SpaDES", "ALTcalc", eventPriority = 1)
      scheduleEvent(sim, start(sim),
                    "ALT_SpaDES", "ALTfinal", eventPriority = 2) #these are given twice is that correct?
      if (!any(is.na(P(sim)$.plots))) {
        scheduleEvent(sim, start(sim),
                      "ALT_SpaDES", "plots", eventPriority = 3) #this is given twice is that correct?
      }
      
      #Are these necessary?
      #sim <- scheduleEvent(sim, P(sim)$.plotInitialTime, "ALThickness", "plot")
      #sim <- scheduleEvent(sim, P(sim)$.saveInitialTime, "ALThickness", "save")
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
    }
    warning(noEventWarning(sim)) # do I need this?
  )
  return(invisible(sim)) # do I need this?
}

### template initialization
Init <- function(sim) {
  # # ! ----- EDIT BELOW ----- ! #
  siteParameters = merge(siteInfo,gParameters, by="Peatland")
  
  months = data.table(month = 5:10)
  
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
      ALT_Solver_dataT
    )
  ]
  ALTparameters2 <- ALTparameters2[!is.na(roots)]
  mod$ALTparameters <- ALTparameters2

  # ! ----- STOP EDITING ----- ! #
  return(invisible(sim))
}

### template for your event2
ALTmaxiumum <- function(sim) {
  # ! ----- EDIT BELOW ----- ! #
    ALTparameters2 <- copy(mod$ALTparameters)
    ALTfinal <- ALTparameters2[,.SD[which.max(ALT)],
      by = .(Year, Site)
    ]
    ALTfinal <- ALTparameters2$maxALT
    
    sim$ALTfinal <- ALTfinal

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
    siteInfo <- prepInputs(url = extractURL("siteInfo"),
                           dpath)
    Cache(userTags = cacheTags)
  }
  
  if(!suppliedElsewhere("gParameters", sim)){
    gParameters <- prepInputs(url = extractURL("gParameters"),
                              dpath)
    Cache(userTags = cacheTags)
  }
  # ! ----- STOP EDITING ----- ! #
  return(invisible(sim))
}

ggplotFn <- function(data, ...) {
  ggplot2::ggplot(data, ggplot2::aes(TheSample)) +
    ggplot2::geom_histogram(...)
}

