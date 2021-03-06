require(tidyverse)
require(readxl)
require(sf)

source("src/functions.R")

# Load data
legacy <- read_excel(
  "input/Cook Farm All years all points.xlsx",
  na = c("-99999", "-77777", -99999))

# Keep only values from grid point project
legacy <- legacy %>% filter(Project == "grid points" | Project == "Grid Points")

# Merge the data based on col and row2
df <- append_georef_to_df(legacy, "Row Letter", "Column")

# Check that merged ID2 matches with Sample Location ID (it does)
id.errors <- df %>%
  mutate(`Sample Location ID` = as.numeric(`Sample Location ID`)) %>%
  mutate(`ID2` = as.numeric(`ID2`)) %>%
  filter(`Sample Location ID` != `ID2`) %>%
  select(`Sample Location ID`, `ID2`)
if(nrow(id.errors) > 0) { warning("Merge check failed") }

# Remove ID2 values with NA (fields north of current CookEast used to be sampled)
df <- df %>% filter(!is.na(ID2))

# Compare yields with those that Kadar used for relative yield project (which is last known (to me) yield data that Dave looked at)
check_yields(df, "99", 1999, "Yield _1999")
check_yields(df, "00", 2000, "Yield _2000")
check_yields(df, "01", 2001, "Yield _2001")
check_yields(df, "02", 2002, "Yield _2002")
check_yields(df, "03", 2003, "Yield_2003")
check_yields(df, "04", 2004, "Yield_2004")
check_yields(df, "05", 2005, "Yield_2005")
check_yields(df, "06", 2006, "Yield_2006")
check_yields(df, "07", 2007, "Yield_2007")
check_yields(df, "08", 2008, "Yield_2008")
check_yields(df, "09", 2009, "Yield_2009")

# Check for differences between duplicated column names
compare_cols(df, "Grain Carbon %..11", "Grain Carbon %..21")
compare_cols(df, "Grain Sulfur %..12", "Grain Sulfur %..20")
compare_cols(df, "Grain Nitrogen %..13", "Grain Nitrogen %..19")
compare_cols(df, "Crop..3", "Crop..22")

# Check that residue was calculated correctly (11 obs had error)
residue.check <- df %>%
  select(Year,
         ID2,
         `Residue plus Grain Wet Weight (grams)`,
         `Residue sample Grain Wet Weight (grams)`,
         `Total Residue Wet Weight (grams)`,
         `Non-Residue Grain Wet Weight (grams)`) %>%
  mutate(ResidueWetWeightCalc = `Residue plus Grain Wet Weight (grams)` - `Residue sample Grain Wet Weight (grams)`) %>%
  filter(abs(ResidueWetWeightCalc - `Total Residue Wet Weight (grams)`) > 0.01)
if(nrow(residue.check) > 0) { warning("Residue column is not trustworthy; review dataframe 'residue.check'") }

# No need to check yield, the calculation is in the excel sheet and passes muster

# Calculate residue values, don't use supplied since it seems to have errors
# Also calc HI for review
df <- df %>%
  mutate(ResidueWetMass = `Residue plus Grain Wet Weight (grams)` - `Residue sample Grain Wet Weight (grams)`) %>%
  mutate(ResidueMoistureProportion = (`Residue Sub-Sample Wet Weight (grams)` - `Residue Sub-Sample Dry Weight (grams)`) / `Residue Sub-Sample Wet Weight (grams)`) %>%
  mutate(ResidueDry = ResidueWetMass * (1 - ResidueMoistureProportion)) %>%
  mutate(ResidueMassDryPerArea = ResidueDry / `Residue Sample Area (square meters)`) %>%
  mutate(HarvestIndex = `total grain yield dry(grams/M2)` / (ResidueMassDryPerArea + `total grain yield dry(grams/M2)`))

# TODO: Need to rename columns, finalize ones to include
df.clean <- df %>%
  mutate(Comments = coalesce(`Grain Harvest Comments`, `Residue Sample Comments`)) %>%
  select(Year,
         Crop..3, X, Y, ID2,
         `total grain yield dry(grams/M2)`,
         `Grain Carbon %..11`, `Grain Nitrogen %..13`, `Grain Sulfur %..12`,
         ResidueMassDryPerArea,
         `Residue Carbon %`,`Residue Nitrogen %`, `Residue Sulfur %`,
         Comments) %>%
  rename(HarvestYear = Year,
         Crop = Crop..3,
         Latitude = Y,
         Longitude = X,
         ID2 = ID2,
         GrainYieldDryPerArea = `total grain yield dry(grams/M2)`,
         GrainCarbon = `Grain Carbon %..11`,
         GrainNitrogen = `Grain Nitrogen %..13`,
         GrainSulfur = `Grain Sulfur %..12`,
         ResidueCarbon = `Residue Carbon %`,
         ResidueNitrogen = `Residue Nitrogen %`,
         ResidueSulfur = `Residue Sulfur %`,
         Comments = Comments) %>%
  replace(. == "winter wheat", "WW") %>%
  replace(. == "spring wheat", "SW") %>%
  replace(. == "spring barley", "SB") %>%
  replace(. == "spring canola", "SC") %>%
  replace(. == "spring pea", "SP") %>%
  replace(. == "winter barley", "WB") %>%
  replace(. == "winter pea", "WP") %>%
  replace(. == "winter canola", "WC") %>%
  replace(. == "Winter Canola", "WC") %>%
  replace(. == "winter lentil", "WL") %>%
  replace(. == "Garbonzo Beans", "GB") %>%
  mutate(HarvestYear = as.integer(HarvestYear)) %>%
  filter(!is.na(ID2), Crop != "Fallow") %>%
  arrange(HarvestYear, ID2)

df.cn1999 <- read_xlsx(
  "input/CAF N data set.xlsx",
  sheet = "1999",
  col_names = TRUE,
  na = c("na")
) %>% 
  select(c(1:14))
df.cn2000 <- read_xlsx(
  "input/CAF N data set.xlsx",
  sheet = "2000",
  col_names = TRUE,
  na = c("na")
) %>% 
  select(c(1:14))
df.cn2001 <- read_xlsx(
  "input/CAF N data set.xlsx",
  sheet = "2001",
  col_names = TRUE,
  na = c("na")
) %>% 
  select(c(1:14))

# Compare 1999 yield values
df %>% 
  filter(Year == 1999) %>% 
  left_join(df.cn, by = c("Column" = "COLUMN", "Row2" = "ROW2")) %>% 
  mutate(UngerYield = `Total grain weight (dry) (g)` / `total area harvested (M2)`) %>% 
  filter(`total grain yield dry(grams/M2)` != UngerYield)

# 0 values don't match -- groovy

# Check c n values... anything new?
df %>% 
  filter(Year == 1999) %>% 
  left_join(df.cn1999, by = c("Column" = "COLUMN", "Row2" = "ROW2")) %>% 
  filter(abs(`Grain Carbon %..21` - `SW (%C)`) > 0.1) %>% 
  select(ID2, `Grain Carbon %..21`, `SW (%C)`, Column, Row2)

# Hmmm, three values but in different order...
# Unger provided notes on source of her data, searched G Drive for "Minimal Cunningham Yields and Residue HRSW 1999.xls" - looks like her dataset was in error.

df %>% 
  filter(Year == 2000) %>% 
  left_join(df.cn2000, by = c("Column" = "COLUMN", "Row2" = "ROW2")) %>% 
  filter(abs(`Grain Carbon %..21` - `SB (%C)`) > 0.1) %>% 
  select(ID2, `Grain Carbon %..21`, `SB (%C)`, Column, Row2)

# There's a better way to do this...

getUngerDF <- function(worksheet) {
  df <- read_xlsx(
    "input/CAF N data set.xlsx",
    sheet = worksheet,
    col_names = TRUE,
    na = c("na", "NA")
  )  %>% 
    select(c(1:14)) %>% 
    mutate(Year = as.numeric(worksheet)) %>% 
    rename(GrainCarbon = contains("%C"),
           GrainNitrogen = contains("%N"),
           GrainProtein = contains("rotein")) %>% 
    mutate(Column = as.integer(COLUMN),
           Row2 = as.character(ROW2),
           GrainMassDry = as.numeric(`Total grain weight (dry) (g)`),
           GrainCarbon = as.numeric(GrainCarbon),
           GrainNitrogn = as.numeric(GrainNitrogen),
           GrainProtein = as.numeric(GrainProtein)) %>% 
    select(Year,
           Column, 
           Row2,
           Crop,
           GrainMassDry,
           GrainCarbon,
           GrainNitrogen,
           GrainProtein)
  
  return(df)
}

# Get all data from Unger, merge together
df.unger <- bind_rows(
  getUngerDF("1999"),
  getUngerDF("2000"),
  getUngerDF("2001"),
  getUngerDF("2002"),
  getUngerDF("2003"),
  getUngerDF("2004"),
  getUngerDF("2005"),
  getUngerDF("2006"),
  getUngerDF("2007"),
  getUngerDF("2008"),
  getUngerDF("2009"))

# Compare all years

df %>% 
  left_join(df.unger, by = c("Year", "Column" , "Row2")) %>%
  filter(abs(`total grain yield dry (grams)` - GrainMassDry) > 0.1) %>% 
  select(Year, ID2, `total grain yield dry (grams)`, GrainMassDry, `Grain Carbon %..21`, GrainCarbon, Column, Row2, Crop..3) %>% 
  print(n=500)

# 125 values do not match, majority of them in 2001

df %>% 
  left_join(df.unger, by = c("Year", "Column" , "Row2")) %>%
  filter(abs(`Grain Carbon %..21` - GrainCarbon) > 0.01) %>% 
  select(Year, ID2, `Grain Carbon %..21`, GrainCarbon, Column, Row2, Crop..3) %>% 
  print(n=500)

# 171 values do not match

df %>% 
  left_join(df.unger, by = c("Year", "Column" , "Row2")) %>%
  filter(abs(`Grain Nitrogen %..19` - GrainNitrogen) > 0.01) %>% 
  select(Year, ID2, `Grain Nitrogen %..19`, GrainNitrogen, Column, Row2, Crop..3) %>% 
  print(n=500)

# 164 values do not match

# Check values present in "Yields and Residue 2007 a.xls" that have the odd "+4 g" added stuff
df %>% 
  left_join(df.unger, by = c("Year", "Column" , "Row2")) %>%
  filter(Year == 2007 & (ID2 == 21 | ID2 == 45 | ID2 == 46 | ID2 == 71)) %>% 
  select(Year, ID2, `total grain yield dry (grams)`, GrainMassDry, `Grain Carbon %..21`, GrainCarbon, Column, Row2, Crop..3) %>% 
  print(n=500)
# They match.  Asked Dave Huggins, he says that's actually correct (due to bag weight)

df.merged <- df %>% 
  left_join(df.unger, by = c("Year", "Column" , "Row2"))

# Looking at mean and SE by crop
df.merged %>% 
  filter(abs(`Grain Nitrogen %..19` - GrainNitrogen) > 0.01) %>% 
  group_by(Crop..3) %>% 
  summarize(meanU = mean(`Grain Nitrogen %..19`, na.rm = T), 
            meanR = mean(GrainNitrogen, na.rm = T),
            seU = sd(`Grain Nitrogen %..19`, na.rm = T)/sqrt(length(`Grain Nitrogen %..19`)),
            seR = sd(GrainNitrogen, na.rm = T)/sqrt(length(GrainNitrogen)))

# Get mean and SE of difference between %N values by crop
df.merged %>% 
  mutate(diffN = abs(`Grain Nitrogen %..19` - GrainNitrogen)) %>%
  filter(diffN > 0) %>% 
  group_by(Crop..3) %>% 
  summarize(meanDiff = mean(diffN, na.rm = T), 
            seDiff = sd(diffN, na.rm = T)/sqrt(length(diffN)),
            nU = length(`Grain Nitrogen %..19`),
            nR = length(GrainNitrogen))


# Get mean and SE of difference between %N values by crop (dropping zeros)
df.merged %>% 
  mutate(diffN = abs(`Grain Nitrogen %..19` - GrainNitrogen)) %>%
  filter(diffN > 0) %>% 
  group_by(Crop..3) %>% 
  summarize(meanDiff = mean(diffN, na.rm = T), 
            seDiff = sd(diffN, na.rm = T)/sqrt(length(diffN)),
            nU = length(`Grain Nitrogen %..19`),
            nR = length(GrainNitrogen))

# Get mean and SE of difference between %N values by crop (dropping zeros)
df.diffN <- df.merged %>% 
  mutate(diffN = abs(`Grain Nitrogen %..19` - GrainNitrogen)) %>%
  filter(diffN > 0)

# Testing normality (http://www.sthda.com/english/wiki/normality-test-in-r) ----
library(ggpubr)
dff.SW <- df.merged %>% 
  filter(Year == 2003 & Crop == "SW")
ggdensity(dff.SW$`Grain Nitrogen %..19`)
ggqqplot(dff.SW$`Grain Nitrogen %..19`)

dff.WW <- df.merged %>% 
  filter(Year == 2003 & Crop == "WW")
ggdensity(dff.WW$`Grain Nitrogen %..19`)
ggqqplot(dff.WW$`Grain Nitrogen %..19`)

ggdensity(df.merged$`Grain Nitrogen %..19`)
ggqqplot(df.merged$GrainNitrogen)

ggdensity(df.diffN$diffN)
ggqqplot(df.diffN$diffN)


# Playing with libraries to remove outliers (https://www.r-bloggers.com/identify-describe-plot-and-remove-the-outliers-from-the-dataset/) ----
#source("http://goo.gl/UUyEzD")
#outlierKD(dff.SW, `Grain Nitrogen %..19`)

# Actually, just create own outlier function (find extreme outliers 3*IQR)
removeOutliers <- function(x, na.rm = TRUE) {
  qnt <- quantile(x, probs=c(0.25, 0.75), na.rm = na.rm)
  H <- 3 * IQR(x, na.rm = na.rm)
  y <- x
  y[x < (qnt[1] - H)] <- NA
  y[x > (qnt[2] + H)] <- NA
  return(y)
}

# Does it work?
removeOutliers(dff.SW$`Grain Nitrogen %..19`)

# Can I use group_by and mutate with the function?
df.merged %>%
  group_by(Year, Crop) %>% 
  mutate(PerNUbbie = removeOutliers(`Grain Nitrogen %..19`),
         PerNUnger = removeOutliers(GrainNitrogen)) %>% 
  mutate(PerNFinal = case_when(!is.na(PerNUbbie) & !is.na(PerNUnger) ~ (PerNUbbie + PerNUnger) / 2,
                               is.na(PerNUbbie) & !is.na(PerNUnger) ~ PerNUnger,
                               !is.na(PerNUbbie) & is.na(PerNUnger) ~ PerNUbbie)) %>% 
  filter(Year == 2003) %>% 
  select(Year, ID2, `Grain Nitrogen %..19`, GrainNitrogen, Column, Row2, PerNUbbie, PerNUnger, PerNFinal) %>% 
  print(n=100)

# I can!  So now save to variable and compare cleaned and dirty versions
df.merged.cleanedN <- df.merged %>%
  group_by(Year, Crop) %>% 
  mutate(PerNUbbie = removeOutliers(`Grain Nitrogen %..19`),
         PerNUnger = removeOutliers(GrainNitrogen)) %>% 
  mutate(PerNFinal = case_when(!is.na(PerNUbbie) & !is.na(PerNUnger) ~ (PerNUbbie + PerNUnger) / 2,
                               is.na(PerNUbbie) & !is.na(PerNUnger) ~ PerNUnger,
                               !is.na(PerNUbbie) & is.na(PerNUnger) ~ PerNUbbie))

# Histograms
df.merged.cleanedN %>% 
  ggplot(aes(x = `Grain Nitrogen %..19`)) +
  geom_histogram() +
  facet_grid(rows = vars(Crop), cols = vars(Year))
df.merged.cleanedN %>% 
  ggplot(aes(x = GrainNitrogen)) +
  geom_histogram() +
  facet_grid(rows = vars(Crop), cols = vars(Year))
df.merged.cleanedN %>% 
  ggplot(aes(x = PerNFinal)) +
  geom_histogram() +
  facet_grid(rows = vars(Crop), cols = vars(Year))

# Summary
df.merged.cleanedN %>% 
  mutate(`Grain Nitrogen %..19` = case_when(`Grain Nitrogen %..19` > 0 ~ `Grain Nitrogen %..19`)) %>% 
  select(Year, Crop, `Grain Nitrogen %..19`, GrainNitrogen, PerNFinal) %>% 
  group_by(Year, Crop) %>% 
  summarize(meanUbbie = mean(`Grain Nitrogen %..19`, na.rm = T), 
            meanUnger = mean(GrainNitrogen, na.rm = T),
            meanFinal = mean(PerNFinal, na.rm = T),
            seUbbie = sd(`Grain Nitrogen %..19`, na.rm = T)/sqrt(length(`Grain Nitrogen %..19`)),
            seUnger = sd(GrainNitrogen, na.rm = T)/sqrt(length(GrainNitrogen)),
            seFinal = sd(PerNFinal, na.rm = T)/sqrt(length(PerNFinal)),
            nUbbie = length(`Grain Nitrogen %..19`[!is.na(`Grain Nitrogen %..19`)]),
            nUnger = length(GrainNitrogen[!is.na(GrainNitrogen)]),
            nFinal = length(PerNFinal[!is.na(PerNFinal)])) %>% 
  print(n = 100)

# Looks pretty good, but forgot to do some stuff.  Need to scrub some of Unger's data due to apparent copy/paste erros in excel and scrub 0 values from both
df.merged.rm.zeros.outliersN <- df.merged %>% 
  group_by(Year, Crop) %>% 
  mutate(GrainNUbbie = case_when(`Grain Nitrogen %..19` > 0 ~ `Grain Nitrogen %..19`),
         GrainNUnger = case_when(GrainNitrogen > 0 ~ GrainNitrogen,
                                 Year == 1999 & Crop == "SW" ~ NA_real_,
                                 Year == 2001 & Crop == "WW" ~ NA_real_)) %>% 
  mutate(GrainNUbbieRmOutlier = removeOutliers(GrainNUbbie),
         GrainNUngerRmOutlier = removeOutliers(GrainNUnger)) %>% 
  mutate(GrainNFinal = case_when(!is.na(GrainNUbbieRmOutlier) & !is.na(GrainNUngerRmOutlier) ~ (GrainNUbbieRmOutlier + GrainNUngerRmOutlier) / 2,
                                 is.na(GrainNUbbieRmOutlier) & !is.na(GrainNUngerRmOutlier) ~ GrainNUngerRmOutlier,
                                 !is.na(GrainNUbbieRmOutlier) & is.na(GrainNUngerRmOutlier) ~ GrainNUbbieRmOutlier))

df.merged.rm.zeros.outliersN %>% 
  ggplot(aes(x = GrainNUbbieRmOutlier)) +
  geom_histogram() +
  facet_grid(rows = vars(Crop), cols = vars(Year))

# Write for Huggins to review changes
df.merged.rm.zeros.outliersN %>% 
  select(Year, ID2, Crop, `Grain Nitrogen %..19`, GrainNitrogen, GrainNUbbie, GrainNUnger, GrainNUbbieRmOutlier, GrainNUngerRmOutlier, GrainNFinal) %>% 
  write_csv("output/nitrogenExportForReview_20190311.csv")

# Now lets clean C and grain mass
df.merged.rm.zeros.outliersC <- df.merged %>% 
  group_by(Year, Crop) %>% 
  mutate(GrainCUbbie = case_when(`Grain Carbon %..21` > 0 ~ `Grain Carbon %..21`),
         GrainCUnger = case_when(GrainCarbon > 0 ~ GrainCarbon,
                                 Year == 1999 & Crop == "SW" ~ NA_real_,
                                 Year == 2001 & Crop == "WW" ~ NA_real_)) %>% 
  mutate(GrainCUbbieRmOutlier = removeOutliers(GrainCUbbie),
         GrainCUngerRmOutlier = removeOutliers(GrainCUnger)) %>% 
  mutate(GrainCFinal = case_when(!is.na(GrainCUbbieRmOutlier) & !is.na(GrainCUngerRmOutlier) ~ (GrainCUbbieRmOutlier + GrainCUngerRmOutlier) / 2,
                                 is.na(GrainCUbbieRmOutlier) & !is.na(GrainCUngerRmOutlier) ~ GrainCUngerRmOutlier,
                                 !is.na(GrainCUbbieRmOutlier) & is.na(GrainCUngerRmOutlier) ~ GrainCUbbieRmOutlier))

df.merged.rm.zeros.outliersC %>% 
  ggplot(aes(x = GrainCFinal)) +
  geom_histogram() +
  facet_grid(rows = vars(Crop), cols = vars(Year))

df.merged.rm.zeros.outliersC %>% 
  group_by(Year, Crop) %>% 
  summarize(maxUbbie = max(`Grain Carbon %..21`, na.rm = T),
            maxUnger = max(GrainCarbon, na.rm = T),
            maxFinal = max(GrainCFinal, na.rm = T),
            meanUbbie = mean(`Grain Carbon %..21`, na.rm = T), 
            meanUnger = mean(GrainCarbon, na.rm = T),
            meanFinal = mean(GrainCFinal, na.rm = T),
            seUbbie = sd(`Grain Carbon %..21`, na.rm = T)/sqrt(length(`Grain Carbon %..21`)),
            seUnger = sd(GrainCarbon, na.rm = T)/sqrt(length(GrainCarbon)),
            seFinal = sd(GrainCFinal, na.rm = T)/sqrt(length(GrainCFinal)),
            nUbbie = length(`Grain Carbon %..21`[!is.na(`Grain Carbon %..21`)]),
            nUnger = length(GrainCarbon[!is.na(GrainCarbon)]),
            nFinal = length(GrainCFinal[!is.na(GrainCFinal)])) %>% 
  print(n = 100)

# Some odd results in summary, like; why did 20 values from Unger get scrubbed 2001 SC?  Is outlier test testing something outside of what I expected?

# Write to review changes
df.merged.rm.zeros.outliersC %>% 
  select(Year, ID2, Crop, `Grain Carbon %..21`, GrainCarbon, GrainCUbbie, GrainCUnger, GrainCUbbieRmOutlier, GrainCUngerRmOutlier, GrainCFinal) %>% 
  write_csv("output/carbonExportForReview_20190311.csv")

# Ahhh... Eff, forgot to group_by year and crop.  Added to previous code.

# Any reason to scrub outliers from Ubbies grain data?
df.merged.rm.zeros.outliersMass <- df.merged %>% 
  group_by(Year, Crop) %>% 
  mutate(GrainMassUbbie = case_when(`total grain yield dry (grams)` > 0 ~ `total grain yield dry (grams)`)) %>% 
  mutate(GrainMassUbbieRmOutlier = removeOutliers(GrainMassUbbie)) %>% 
  mutate(GrainMassFinal = GrainMassUbbieRmOutlier)

df.merged.rm.zeros.outliersMass %>% 
  ggplot(aes(x = GrainMassUbbie)) +
  geom_histogram() +
  facet_grid(rows = vars(Crop), cols = vars(Year))

df.merged.rm.zeros.outliersMass %>% 
  ggplot(aes(x = GrainMassFinal)) +
  geom_histogram() +
  facet_grid(rows = vars(Crop), cols = vars(Year))

df.merged.rm.zeros.outliersMass %>% 
  group_by(Year, Crop) %>% 
  summarize(maxUbbie = max(`total grain yield dry (grams)`, na.rm = T),
            maxFinal = max(GrainMassFinal, na.rm = T),
            meanUbbie = mean(`total grain yield dry (grams)`, na.rm = T),
            meanFinal = mean(GrainMassFinal, na.rm = T),
            seUbbie = sd(`total grain yield dry (grams)`, na.rm = T)/sqrt(length(`total grain yield dry (grams)`)),
            seFinal = sd(GrainMassFinal, na.rm = T)/sqrt(length(GrainMassFinal)),
            nUbbie = length(`total grain yield dry (grams)`[!is.na(`total grain yield dry (grams)`)]),
            nFinal = length(GrainMassFinal[!is.na(GrainMassFinal)])) %>% 
  print(n = 100)

# Yeah, there are some apparent extremem outliers.

# Okay, do it all together now, output for review:
df.merged.rm.zeros.outliers <- df.merged %>% 
  group_by(Year, Crop) %>% 
  mutate(GrainNUbbie = case_when(`Grain Nitrogen %..19` > 0 ~ `Grain Nitrogen %..19`),
         GrainNUnger = case_when(GrainNitrogen > 0 ~ GrainNitrogen,
                                 Year == 1999 & Crop == "SW" ~ NA_real_,
                                 Year == 2001 & Crop == "WW" ~ NA_real_)) %>% 
  mutate(GrainNUbbieRmOutlier = removeOutliers(GrainNUbbie),
         GrainNUngerRmOutlier = removeOutliers(GrainNUnger)) %>% 
  mutate(GrainNFinal = case_when(!is.na(GrainNUbbieRmOutlier) & !is.na(GrainNUngerRmOutlier) ~ (GrainNUbbieRmOutlier + GrainNUngerRmOutlier) / 2,
                                 is.na(GrainNUbbieRmOutlier) & !is.na(GrainNUngerRmOutlier) ~ GrainNUngerRmOutlier,
                                 !is.na(GrainNUbbieRmOutlier) & is.na(GrainNUngerRmOutlier) ~ GrainNUbbieRmOutlier)) %>% 
  mutate(GrainCUbbie = case_when(`Grain Carbon %..21` > 0 ~ `Grain Carbon %..21`),
         GrainCUnger = case_when(GrainCarbon > 0 ~ GrainCarbon,
                                 Year == 1999 & Crop == "SW" ~ NA_real_,
                                 Year == 2001 & Crop == "WW" ~ NA_real_)) %>% 
  mutate(GrainCUbbieRmOutlier = removeOutliers(GrainCUbbie),
         GrainCUngerRmOutlier = removeOutliers(GrainCUnger)) %>% 
  mutate(GrainCFinal = case_when(!is.na(GrainCUbbieRmOutlier) & !is.na(GrainCUngerRmOutlier) ~ (GrainCUbbieRmOutlier + GrainCUngerRmOutlier) / 2,
                                 is.na(GrainCUbbieRmOutlier) & !is.na(GrainCUngerRmOutlier) ~ GrainCUngerRmOutlier,
                                 !is.na(GrainCUbbieRmOutlier) & is.na(GrainCUngerRmOutlier) ~ GrainCUbbieRmOutlier)) %>% 
  mutate(GrainMassUbbie = case_when(`total grain yield dry (grams)` > 0 ~ `total grain yield dry (grams)`)) %>% 
  mutate(GrainMassUbbieRmOutlier = removeOutliers(GrainMassUbbie)) %>% 
  mutate(GrainMassFinal = GrainMassUbbieRmOutlier)

df.merged.rm.zeros.outliers %>% 
  select(Year, ID2, Crop, 
         `total grain yield dry (grams)`, GrainMassFinal,
         `Grain Nitrogen %..19`, GrainNitrogen, GrainNUbbie, GrainNUnger, GrainNUbbieRmOutlier, GrainNUngerRmOutlier, GrainNFinal,
         `Grain Carbon %..21`, GrainCarbon, GrainCUbbie, GrainCUnger, GrainCUbbieRmOutlier, GrainCUngerRmOutlier, GrainCFinal) %>% 
  write_csv("output/MassCNExportForReview_20190311.csv", na = "")
