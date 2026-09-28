---
title: "ALT_SpaDES Manual"
subtitle: "v.1.0.0.0"
date: "Last updated: 2026-09-28"
output:
  bookdown::html_document2:
    toc: true
    toc_float: true
    theme: sandstone
    number_sections: false
    df_print: paged
    keep_md: yes
editor_options:
  chunk_output_type: console
always_allow_html: true
---

# ALT_SpaDES Module

<!-- the following are text references used in captions for LaTeX compatibility -->

(ref:ALT_SpaDES) *ALT_SpaDES*



[![made-with-Markdown](figures/markdownBadge.png)](https://commonmark.org)

<!-- if knitting to pdf remember to add the pandoc_args: ["--extract-media", "."] option to yml in order to get the badge images -->

#### Authors:

Madeleine Garibaldi <madeleine.garibaldi@nrcan-rncan.gc.ca> [aut, cre], Oleksandra (Sasha) Hararuk <oleksandra.hararuk@nrcan-rncan.gc.ca> [aut, cre] <!-- ideally separate authors with new lines, '\n' not working -->

## Module Overview

Estimates active layer thickness (ALT) based on repeated iterations of a sine ground temperature function. ALT is the depth of the layer of substrate above permafrost that freezes and thaws each year. ALTs typically range from around 0.2 m to around 3 m.

### Quick links

-   [General functioning](#general-functioning)

-   [List of input objects](#input-list)

-   [List of parameters](#params-list)

-   [List of outputs](#outputs-list)

-   [Simulation flow and module events](#sim-flow)

### Module summary

ALT_SpaDES module calculates active layer thickness using annual ground surface temperature, surface temperature amplitude, and 4 parameters calibrated based on a user decided class (i.e. substrate or land cover). As the equation uses exponentials the annual ground surface temperature (Ts) must be provided in KELVIN. The module runs the ALT Solver function monthly (from May to October as a default) and summarizes the greatest depth where the ground remains greater than 0 during this period (i.e. the active layer thickness). If no value is returned this means the module is predicted no near surface permafrost.

### Module inputs and parameters

#### Inputs

Describe input data required by the module and how to obtain it (e.g., directly from online sources or supplied by other modules) If `sourceURL` is specified, `downloadData("ALT_SpaDES", "C:/Users/mgaribal/Documents/test/modules")` may be sufficient.

Table \@ref(tab:moduleInputs-ALT_SpaDES) shows the full list of module inputs.

<table class="table" style="margin-left: auto; margin-right: auto;">
<caption>(\#tab:moduleInputs-ALT_SpaDES)(\#tab:moduleInputs-ALT_SpaDES)List of (ref:ALT_SpaDES) input objects and their description.</caption>
 <thead>
  <tr>
   <th style="text-align:left;"> objectName </th>
   <th style="text-align:left;"> objectClass </th>
   <th style="text-align:left;"> desc </th>
   <th style="text-align:left;"> sourceURL </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> gParameters </td>
   <td style="text-align:left;"> data.table </td>
   <td style="text-align:left;"> Data table input with the parameters required in the ALT Solver. The columns of this data table are Landcover, d (damping depth), k (decay in annual temperature), b (the amplitude modifier), p (the period modifier). This input can be created using the GT_Calibration_SpaDES module if the parameters need to be calibrated for new environment and/or land cover types. Currently the parameters provided in this data table have been calibrated for peatland land covers. </td>
   <td style="text-align:left;"> NA </td>
  </tr>
  <tr>
   <td style="text-align:left;"> siteInfo </td>
   <td style="text-align:left;"> data.table </td>
   <td style="text-align:left;"> Data table input with the site information. The columns of this data table are Site (the site names), Class, Year, Ts (the annual ground surface temperature in Kelvin), and A (the ground surface temperature amplitude, the difference between the monthly maximum and minimum ground surface temperature). The class column a user defined division based on what impacts the parameters d and k.Sample data is provided to show module function but should be replaced with real data before use.This data table can be generated using the GS_Temp_SpaDES module. </td>
   <td style="text-align:left;"> NA </td>
  </tr>
</tbody>
</table>

#### Parameters

Summary of user-visible parameters (Table \@ref(tab:moduleParams-ALT_SpaDES))

<table class="table" style="margin-left: auto; margin-right: auto;">
<caption>(\#tab:moduleParams-ALT_SpaDES)(\#tab:moduleParams-ALT_SpaDES)List of (ref:ALT_SpaDES) parameters and their description.</caption>
 <thead>
  <tr>
   <th style="text-align:left;"> paramName </th>
   <th style="text-align:left;"> paramClass </th>
   <th style="text-align:left;"> default </th>
   <th style="text-align:left;"> min </th>
   <th style="text-align:left;"> max </th>
   <th style="text-align:left;"> paramDesc </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> .plots </td>
   <td style="text-align:left;"> character </td>
   <td style="text-align:left;"> screen </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> Used by Plots function, which can be optionally used here </td>
  </tr>
  <tr>
   <td style="text-align:left;"> .plotInitialTime </td>
   <td style="text-align:left;"> numeric </td>
   <td style="text-align:left;"> 0 </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> Describes the simulation time at which the first plot event should occur. </td>
  </tr>
  <tr>
   <td style="text-align:left;"> .plotInterval </td>
   <td style="text-align:left;"> numeric </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> Describes the simulation time interval between plot events. </td>
  </tr>
  <tr>
   <td style="text-align:left;"> grid_ppp </td>
   <td style="text-align:left;"> numeric </td>
   <td style="text-align:left;"> 25 </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> Sets the number of grid points per period. This determines how often the function is sampled within each sine wave. Increasing this value will ensure all crossings of temperature = 0 but can increase processing time. If this value is decreased processing time will increase but crossings may be missed. </td>
  </tr>
  <tr>
   <td style="text-align:left;"> months </td>
   <td style="text-align:left;"> numeric </td>
   <td style="text-align:left;"> 5, 10 </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> sets the months for which the ALT Solver is run and for which roots (i.e. active layer thicknesses) are calculated. These months should correspond to the timing of maximum thaw in order to accurately predict active layer thickness. Running for months where seasonal frost might be present may lead to errouneous estimations of ALT.months must include Septmember (9) inorder to run the module. This is typically the month with the maximum thaw and therefore should be included when calculated ALT. The default is May (5) to October (10). Increasing the number of months will increase processing time. </td>
  </tr>
  <tr>
   <td style="text-align:left;"> overresolve </td>
   <td style="text-align:left;"> numeric </td>
   <td style="text-align:left;"> 1.2 </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> multiplier than increases the number of grid points beyond the minimum required by grid_ppp. Increasing this value will increase processing time </td>
  </tr>
  <tr>
   <td style="text-align:left;"> plot_check </td>
   <td style="text-align:left;"> logical </td>
   <td style="text-align:left;"> FALSE </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> This replaces the .plot parameter for this module. The Default is FALSE. If set to TRUE module will create a diagnostic plot for each month showing the behavior of the ALT Solver Function and can indicate the solver is saving the correct z for each month. This can be used for validation and debugging, however it greatly increases the processing time. Plots can only be save to the screen. </td>
  </tr>
  <tr>
   <td style="text-align:left;"> tol </td>
   <td style="text-align:left;"> numeric </td>
   <td style="text-align:left;"> 1e-10 </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> tolerance which sets the numerical accuracy (number of decimal points) reported for the active layer thickness </td>
  </tr>
  <tr>
   <td style="text-align:left;"> verbose </td>
   <td style="text-align:left;"> logical </td>
   <td style="text-align:left;"> FALSE </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> If TRUE, gives diagnostice messages while the solver runs. Can be useful for development and debugging but increases processing time. The default is FALSE. </td>
  </tr>
  <tr>
   <td style="text-align:left;"> z_search </td>
   <td style="text-align:left;"> numeric </td>
   <td style="text-align:left;"> 0, 5 </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> Range of depths (z) in meters for the ALT Solver. Default is 0-5m. The module will produce results up to the maximum provided. This can lead to erroneous prediction of active layer thickness where no permafrost is present. As the parameters depend on calibration data it is recommended to keep the maximum for z_search within the calibration depth range. The default parameter values provided in the gParameters input were calibrated and validated for depths up to 3m therefore running the module for depths much greater than 3m may produce inaccurate results. It is recommended to limit the model run to within typical active layer thicknesses (&lt; 5m) as the model may still produces an ALT value which exceed any known ALT. </td>
  </tr>
  <tr>
   <td style="text-align:left;"> .seed </td>
   <td style="text-align:left;"> list </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> Named list of seeds to use for each event (names). </td>
  </tr>
  <tr>
   <td style="text-align:left;"> .useCache </td>
   <td style="text-align:left;"> logical </td>
   <td style="text-align:left;"> FALSE </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> Should caching of events or module be used? </td>
  </tr>
</tbody>
</table>

### Events

#### Init

This event sets up a data table to avoid a loop within the ALT Solver. First the two input data tables siteInfo and gParameters are combined based on land cover type into a siteParameters data table. It then creates a new data table of months (default 5-10). The new months data table and the siteParameters data table are combined to duplicate the rows of siteParameters for each month in the months data table and to create a new column months. This is done to avoid a loop within the ALT Solver. These changes are saved in a new data table called ALTparameters.

#### ALTcalc

This event runs the ALT Solver function for each row in the ALTparameters data table and saves the minimum depth (z) where temperature crosses 0. These are the monthly frost depths.

#### ALTfinal

This event calculates the final active layer thickness for each site and year provided in the siteInfo data table. The active layer thickness is the maximum depth (z) where temperature crosses 0 for each individual year and site (the maximum for each year and site saved in the ALTcalc event). There are a couple special rules during this event to account for different ALT scenarios. 
1. If an ALT is produced for all months (excluding some of the early spring months), the maximum is selected.
2. If all months produce NA than the final value selected is NA
3. If some months early in the thawing season produce an ALT, but the ALT for September (typically the peak thaw) is NA then NA is returned as the ALT value since the entire range of depths was unfrozen during the timing of peak thaw.

### Plotting

Plotting is controlled through the plot_check parameter not .plot for this module. Changing plot_check from the default (FALSE) to TRUE will result in plotting for monthly roots indicating the transition from thawed to frozen (f(z)\<0). These plots can be used to assess proper module function but will increasing processing time. Therefore it is recommended to leave plot_check as the default unless the user is validating module validity. Plots through this module can only be produced in the screen.

### Module outputs

(Table \@ref(tab:moduleOutputs-ALT_SpaDES)).

<table class="table" style="margin-left: auto; margin-right: auto;">
<caption>(\#tab:moduleOutputs-ALT_SpaDES)(\#tab:moduleOutputs-ALT_SpaDES)List of (ref:ALT_SpaDES) outputs and their description.</caption>
 <thead>
  <tr>
   <th style="text-align:left;"> objectName </th>
   <th style="text-align:left;"> objectClass </th>
   <th style="text-align:left;"> desc </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> ALTfinal </td>
   <td style="text-align:left;"> data.table </td>
   <td style="text-align:left;"> Data table containing the final active layer thickness (in meters) for each site and year in the siteInfo data table input. For sites with no permafrost and no ALT the module will out put an NA or a blank cell when converted to a .csv file. The month assigned to this value will be September (9). If September is not used the month assigned will be the earliest. </td>
  </tr>
</tbody>
</table>

### Links to other modules

The gParameters data table can be produced from the GT_Calibration_SpaDES module if parameters need to be calibrated for a new environment or land cover types.

The siteInfo data table can be produced from the GS_Temp_SpaDES module if the user does not have measured ground surface temperature and amplitude.

### Getting help

For help please contact Madeleine Garibaldi at madeleinegaribaldi9@gmail.com

## References

<!-- autogenerated from bibligraphy -->

SpaDES.core::moduleMetadata(
module = "ALT_SpaDES",
path = "."
)
