-- SQL SCRIPT FOR BOSTON ENERGY, WATER, AND GHG EMISSION METRICS
-- SKILLS: Joins, CTE's, Temp Tables, Windows Functions, Aggregate Functions, Creating Views, Converting Data Types

-- the first table contains measurements of metrics for each years and property described by the address and property name
SELECT * FROM Portfolio..Boston_Metrics;

-- the second table has values for each property including the Street, Zip, Year Built, Property Type, and Uses
SELECT * FROM Portfolio..Boston_Prop_Info;

-- DATA CLEANING

-- some of the zip codes are missing leading 0
SELECT DISTINCT [Property Name], [Address] FROM Portfolio..Boston_Prop_Info
WHERE lEN([ Zip]) = 5;

-- fix zip codes
-- change the datatype of the zip code column
ALTER TABLE Portfolio..Boston_Prop_Info
ALTER COLUMN [ Zip] VARCHAR(10);

-- ADD 0 to the Zip's with length 4
SELECT
CONCAT('0',[ Zip])
FROM Portfolio..Boston_Prop_Info
WHERE LEN([ Zip]) = 4;

-- update this in the table
UPDATE Portfolio..Boston_Prop_Info
SET [ Zip] = CONCAT('0',[ Zip])
WHERE LEN([ Zip]) = 4;

-- there are cases with longer Zip codes
SELECT COUNT(*) FROM Portfolio..Boston_Prop_Info
WHERE LEN([ Zip]) > 5;

-- limit the zip codes to length 5
SELECT LEFT([ Zip], 5)
FROM Portfolio..Boston_Prop_Info
WHERE LEN([ Zip]) > 5;

-- update these incorrect entries
UPDATE Portfolio..Boston_Prop_Info
SET [ Zip] = LEFT([ Zip], 5)
WHERE LEN([ Zip]) > 5;

-- update the text so its all upper case
UPDATE Portfolio..Boston_Metrics SET Address = UPPER(Address);
UPDATE Portfolio..Boston_Metrics SET [Property Name] = UPPER([Property Name]);

UPDATE Portfolio..Boston_Prop_Info SET [Property Type] = UPPER([Property Type]);
UPDATE Portfolio..Boston_Prop_Info SET [Property Name] = UPPER([Property Name]);
UPDATE Portfolio..Boston_Prop_Info SET [Property Uses] = UPPER([Property Uses]);
UPDATE Portfolio..Boston_Prop_Info SET [Address] = UPPER([Address]);
UPDATE Portfolio..Boston_Prop_Info SET [Street] = UPPER([Street]);


-- Incorrect values in the year built column
SELECT [Year Built], COUNT([Year Built]) FROM Portfolio..Boston_Prop_Info GROUP BY [Year Built] ORDER BY [Year Built] DESC;

UPDATE Portfolio..Boston_Prop_Info
SET [Year Built] = '2000'
WHERE [Year Built] = '1000';

UPDATE Portfolio..Boston_Prop_Info
SET [Year Built] = '1889'
WHERE [Year Built] = '889';

-- looked the property up to confirm the year
UPDATE Portfolio..Boston_Prop_Info
SET [Year Built] = '1910'
WHERE [Year Built] = '1111';

-- looked the property up to confirm the year
UPDATE Portfolio..Boston_Prop_Info
SET [Year Built] = '1928'
WHERE [Year Built] = '1028';

-- make year built an int
ALTER TABLE Portfolio..Boston_Prop_Info
ALTER COLUMN [Year Built] INT;


-- delete rows without property ID
DELETE FROM Portfolio..Boston_Metrics WHERE [Property Name] is null AND Address is null;

-- replace [Site EUI (kBtu/ft²)] with calculation using [Total Site Energy (kBTU)] and Gross Area
-- the calculation is the same as the reported value
SELECT [Total Site Energy (kBTU)], [Site EUI (kBtu/ft²)], [Gross Area (sq ft) _],
CASE WHEN [Gross Area (sq ft) _] = 0 THEN null ELSE ROUND([Total Site Energy (kBTU)] / [Gross Area (sq ft) _], 1)
END AS Calculation
FROM Portfolio..Boston_Metrics
WHERE [Site EUI (kBtu/ft²)] is null;

-- do the replacement
UPDATE Portfolio..Boston_Metrics
SET [Site EUI (kBtu/ft²)] = 
CASE WHEN 
[Gross Area (sq ft) _] = 0 THEN null ELSE ROUND([Total Site Energy (kBTU)] / [Gross Area (sq ft) _], 1)
END 
WHERE [Site EUI (kBtu/ft²)] is null;

-- check that it works
-- in places with values for Area and Total Energy there is a value for Site EUI
SELECT SUM(CASE WHEN [Total Site Energy (kBTU)] is not null AND [Site EUI (kBtu/ft²)] 
is null AND [Gross Area (sq ft) _] is not null 
AND not [Gross Area (sq ft) _] = 0
THEN 1 ELSE 0 END) AS Number_Null
FROM Portfolio..Boston_Metrics;

-- no places to replace Total Site Enery with a calculation
SELECT SUM(CASE WHEN [Total Site Energy (kBTU)] is null AND [Site EUI (kBtu/ft²)] 
is not null AND [Gross Area (sq ft) _] is not null 
AND not [Gross Area (sq ft) _] = 0
THEN 1 ELSE 0 END) AS Number_Null
FROM Portfolio..Boston_Metrics;


-- can do the same replace with GHG Emisson and GHG Intensity and Gross Area 
-- only a place to do it to replace the intensity not to replace Emissions
SELECT 
SUM(CASE WHEN [GHG Emissions (MTCO2e)] is not null and [GHG Intensity (kgCO2/sf)] is null and [Onsite Renewable (kWh)] is not null THEN 1 ELSE 0 END) AS Number_Null
FROM Portfolio..Boston_Metrics;

-- need to convert units as well
SELECT [GHG Emissions (MTCO2e)], [GHG Intensity (kgCO2/sf)], [Gross Area (sq ft) _],
CASE WHEN [Gross Area (sq ft) _] = 0 THEN null ELSE ROUND(POWER(10, 3)*[GHG Emissions (MTCO2e)] / [Gross Area (sq ft) _], 1)
END AS Calculation
FROM Portfolio..Boston_Metrics
WHERE [GHG Intensity (kgCO2/sf)] is null and [GHG Emissions (MTCO2e)] is not null;

UPDATE Portfolio..Boston_Metrics
SET [GHG Intensity (kgCO2/sf)] = 
CASE WHEN 
[Gross Area (sq ft) _] = 0 THEN null ELSE ROUND(POWER(10, 3)*[GHG Emissions (MTCO2e)] / [Gross Area (sq ft) _], 1)
END 
WHERE [GHG Intensity (kgCO2/sf)] is null;

-- fix the mistake classifier in Property Type
UPDATE Portfolio..Boston_Prop_Info
SET [Property Type] = NULL
WHERE [Property Type] like '%NOT AVEAILABLE%';

-- DATA EXPLORATION

-- Fill in the Zip codes and Year Built Values
SELECT DISTINCT bid.[Building ID], bpi.[ Zip], 
bpi.[Property Type], bpi.[Year Built], bpi.[Street], bpi.[Property Uses], bmet.[Gross Area (sq ft) _], bmet.Year
FROM #Building_ID bid
LEFT JOIN Portfolio..Boston_Metrics bmet
	ON bmet.[Property Name] = bid.[Property Name]
	AND bmet.Address = bid.Address
LEFT JOIN Portfolio..Boston_Prop_Info bpi
	ON bid.[Property Name] = bpi.[Property Name]
	AND bid.Address = bpi.Address;


-- group the ZIP with the averages of each metric
-- INNER JOIN used because we are calculating averages for each Zip so we don't need data that doesn't have metrics and a zip code as it will be excluded anyway

-- create a temp table to aid the calculation
DROP TABLE IF exists #Zip
CREATE TABLE #Zip
(Zip nvarchar(5), [Site EUI (kBtu/ft²)] numeric, [Total Site Energy (kBTU)] numeric, [Water Intensity (gal/sf)] numeric, 
[GHG Emissions (MTCO2e)] numeric, [GHG Intensity (kgCO2/sf)] numeric)

INSERT INTO #Zip
SELECT bprop.[ Zip], bmet.[Site EUI (kBtu/ft²)], bmet.[Total Site Energy (kBTU)], bmet.[Water Intensity (gal/sf)], 
bmet.[GHG Emissions (MTCO2e)], bmet.[GHG Intensity (kgCO2/sf)]
FROM Portfolio..Boston_Prop_Info bprop
INNER JOIN Portfolio..Boston_Metrics bmet
	ON bprop.[Property Name] = bmet.[Property Name]
	AND bprop.[Address] = bmet.[Property Name]
WHERE bprop.[ Zip] is not null;

SELECT * FROM #Zip;


SELECT Zip, AVG([Site EUI (kBtu/ft²)]) as [Avg Site EUI], AVG([Total Site Energy (kBTU)]) as [Avg Total Site Energy], AVG([Water Intensity (gal/sf)])
as [Avg Water Intensity], 
AVG([GHG Emissions (MTCO2e)]) as [Avg GHG Emissions], AVG([GHG Intensity (kgCO2/sf)]) as [Avg GHG Intensity]
FROM #Zip
GROUP BY Zip
ORDER BY [Avg Site EUI] desc;

-- look at the median differences
-- for visualizations might want to use median as there are outliers that skew the average

SELECT DISTINCT Zip, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY [Site EUI (kBtu/ft²)]) OVER (PARTITION BY Zip) as [Median Site EUI], 
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY [Total Site Energy (kBTU)]) OVER (PARTITION BY Zip) as [Median Total Site Energy],
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY [Water Intensity (gal/sf)]) OVER (PARTITION BY Zip) as [Median Water Intensity],
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY [GHG Emissions (MTCO2e)]) OVER (PARTITION BY Zip) as [Median GHG Emissions],
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY [GHG Intensity (kgCO2/sf)]) OVER (PARTITION BY Zip) as [Median GHG Intensity]
FROM #Zip
ORDER BY [Median Site EUI] desc;

-- look at differences across the years
-- there appears to be some difference across years
-- could be due to reporting issues or actual trend (2017 has a lot of energy use)

SELECT Year, AVG([Site EUI (kBtu/ft²)]) as [Avg Site EUI], AVG([Total Site Energy (kBTU)]) as [Avg Total Site Energy], AVG([Water Intensity (gal/sf)])
as [Avg Water Intensity], 
AVG([GHG Emissions (MTCO2e)]) as [Avg GHG Emissions], AVG([GHG Intensity (kgCO2/sf)]) as [Avg GHG Intensity]
FROM Portfolio..Boston_Metrics
GROUP BY Year
ORDER BY [Avg Site EUI] DESC;

-- the medians are much closer to each other than the averages
SELECT DISTINCT Year, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY [Site EUI (kBtu/ft²)]) OVER (PARTITION BY Year) as [Median Site EUI], 
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY [Total Site Energy (kBTU)]) OVER (PARTITION BY Year) as [Median Total Site Energy],
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY [Water Intensity (gal/sf)]) OVER (PARTITION BY Year) as [Median Water Intensity],
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY [GHG Emissions (MTCO2e)]) OVER (PARTITION BY Year) as [Median GHG Emissions],
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY [GHG Intensity (kgCO2/sf)]) OVER (PARTITION BY Year) as [Median GHG Intensity]
FROM Portfolio..Boston_Metrics
ORDER BY [Median Site EUI] DESC;

-- look at the min/max values
SELECT Street FROM Portfolio..Boston_Prop_Info;

-- try the streets
DROP TABLE IF exists #Street
CREATE TABLE #Street
(Street nvarchar(250), [Site EUI (kBtu/ft²)] numeric, [Total Site Energy (kBTU)] numeric, [Water Intensity (gal/sf)] numeric, 
[GHG Emissions (MTCO2e)] numeric, [GHG Intensity (kgCO2/sf)] numeric)

INSERT INTO #Street
SELECT bprop.Street, bmet.[Site EUI (kBtu/ft²)], bmet.[Total Site Energy (kBTU)], bmet.[Water Intensity (gal/sf)], 
bmet.[GHG Emissions (MTCO2e)], bmet.[GHG Intensity (kgCO2/sf)]
FROM Portfolio..Boston_Prop_Info bprop
INNER JOIN Portfolio..Boston_Metrics bmet
	ON bprop.[Property Name] = bmet.[Property Name]
	AND bprop.[Address] = bmet.[Property Name]
WHERE bprop.Street is not null;

SELECT * FROM #Street;

SELECT Street, AVG([Site EUI (kBtu/ft²)]) as [Avg Site EUI], AVG([Total Site Energy (kBTU)]) as [Avg Total Site Energy], AVG([Water Intensity (gal/sf)])
as [Avg Water Intensity], 
AVG([GHG Emissions (MTCO2e)]) as [Avg GHG Emissions], AVG([GHG Intensity (kgCO2/sf)]) as [Avg GHG Intensity]
FROM #Street
WHERE [Site EUI (kBtu/ft²)] is not null
GROUP BY Street
ORDER BY [Avg Site EUI] desc;

-- look at the min/max values

SELECT Street, AVG([Site EUI (kBtu/ft²)]) as [Avg Site EUI], AVG([Total Site Energy (kBTU)]) as [Avg Total Site Energy], AVG([Water Intensity (gal/sf)])
as [Avg Water Intensity], 
AVG([GHG Emissions (MTCO2e)]) as [Avg GHG Emissions], AVG([GHG Intensity (kgCO2/sf)]) as [Avg GHG Intensity]
FROM #Street
WHERE [Site EUI (kBtu/ft²)] is not null
GROUP BY Street
ORDER BY [Avg Site EUI] desc;


-- look at the ranges
SELECT Street, MAX([Site EUI (kBtu/ft²)]) - MIN([Site EUI (kBtu/ft²)]) as [Range Site EUI], 
MAX([Total Site Energy (kBTU)]) - MIN([Total Site Energy (kBTU)]) as [Range Total Site Energy],
MAX([Water Intensity (gal/sf)]) - MIN([Water Intensity (gal/sf)]) as [Range Water Intensity],
MAX([GHG Emissions (MTCO2e)]) - MIN([GHG Emissions (MTCO2e)]) as [Range GHG Emissions],
MAX([GHG Intensity (kgCO2/sf)]) - MIN([GHG Intensity (kgCO2/sf)]) as [Range GHG Intensity]
FROM #Street
WHERE [Site EUI (kBtu/ft²)] is not null
GROUP BY Street
ORDER BY [Range Site EUI] desc;


-- look at SENIOR, K 12 School, Single Family Home, PRE SCHOOL, RACE TRACK, STADIUM, HOSPITAL, LABORATORY, OFFICE, DATA CENTER, ect.
-- CTE makes calculation easier
WITH GroupPropertyType ([Property Type], [Site EUI (kBtu/ft²)], [Total Site Energy (kBTU)], [Water Intensity (gal/sf)], 
[GHG Emissions (MTCO2e)], [GHG Intensity (kgCO2/sf)])
AS
(
SELECT bprop.[Property Type], bmet.[Site EUI (kBtu/ft²)], bmet.[Total Site Energy (kBTU)], bmet.[Water Intensity (gal/sf)], 
bmet.[GHG Emissions (MTCO2e)], bmet.[GHG Intensity (kgCO2/sf)]
FROM Portfolio..Boston_Prop_Info bprop
INNER JOIN Portfolio..Boston_Metrics bmet
	ON bprop.[Property Name] = bmet.[Property Name]
	AND bprop.[Address] = bmet.[Property Name]
)
SELECT [Property Type], AVG([Site EUI (kBtu/ft²)]) as [Avg Site EUI], AVG([Total Site Energy (kBTU)]) as [Avg Total Site Energy], AVG([Water Intensity (gal/sf)])
as [Avg Water Intensity], 
AVG([GHG Emissions (MTCO2e)]) as [Avg GHG Emissions], AVG([GHG Intensity (kgCO2/sf)]) as [Avg GHG Intensity]
FROM GroupPropertyType
WHERE [Site EUI (kBtu/ft²)] is not null
GROUP BY [Property Type]
ORDER BY [Avg Site EUI] desc;


-- Look at ranges of year built values
SELECT MAX([Year Built]) as [Max Year Built], MIN([Year Built]) as [Min Year Built] FROM Portfolio..Boston_Prop_Info;

-- Group the years in to 25 year segments and look at metrics across each section
WITH GroupYearBuilt ([Year Built], [Site EUI (kBtu/ft²)], [Total Site Energy (kBTU)], [Water Intensity (gal/sf)], 
[GHG Emissions (MTCO2e)], [GHG Intensity (kgCO2/sf)])
AS
(
SELECT bprop.[Year Built], bmet.[Site EUI (kBtu/ft²)], bmet.[Total Site Energy (kBTU)], bmet.[Water Intensity (gal/sf)], 
bmet.[GHG Emissions (MTCO2e)], bmet.[GHG Intensity (kgCO2/sf)]
FROM Portfolio..Boston_Prop_Info bprop
INNER JOIN Portfolio..Boston_Metrics bmet
	ON bprop.[Property Name] = bmet.[Property Name]
	AND bprop.[Address] = bmet.[Property Name]
)
SELECT t.Range as [Year Range], AVG([Site EUI (kBtu/ft²)]) as [Avg Site EUI], AVG([Total Site Energy (kBTU)]) as [Avg Total Site Energy],
AVG([Water Intensity (gal/sf)]) as [Avg Water Intensity], 
AVG([GHG Emissions (MTCO2e)]) as [Avg GHG Emissions], AVG([GHG Intensity (kgCO2/sf)]) as [Avg GHG Intensity]
FROM (
      SELECT [Year Built], [Site EUI (kBtu/ft²)], [Total Site Energy (kBTU)], [Water Intensity (gal/sf)], 
		[GHG Emissions (MTCO2e)], [GHG Intensity (kgCO2/sf)],
		 CASE WHEN [Year Built] BETWEEN 1800 AND 1824 THEN '1800-1824'
         WHEN [Year Built] BETWEEN 1825 AND 1849 THEN '1825-1849'
		 WHEN [Year Built] BETWEEN 1850 AND 1874 THEN '1850-1874'
		 WHEN [Year Built] BETWEEN 1875 AND 1899 THEN '1875-1899'
		 WHEN [Year Built] BETWEEN 1900 AND 1924 THEN '1900-1924'
		 WHEN [Year Built] BETWEEN 1925 AND 1949 THEN '1925-1949'
		 WHEN [Year Built] BETWEEN 1950 AND 1974 THEN '1950-1974'
		 WHEN [Year Built] BETWEEN 1975 AND 1999 THEN '1977-1999'
         ELSE '2000-2020' END as Range
     FROM GroupYearBuilt) t
GROUP BY t.range;

-- The data for visualization
-- Want a column with year ranges
-- Want a column with Total Water this can be calculated from Gross Area and Water Intensity


-- Create a view of the data for visulatization
-- Use CTE to get the Building IDs
-- Join the 3 tables on [Property Name] and [Address]
-- Add Total Water and Year Built Range columns

CREATE VIEW Boston_Metrics_IDs AS
WITH Building_ID ([Property Name], Address, [Building ID])
AS
(
SELECT [Property Name], Address, ROW_NUMBER() OVER (ORDER BY [Property Name], Address DESC) AS [Building ID]
FROM (SELECT DISTINCT [Property Name], Address
FROM Portfolio..Boston_Metrics) AS internalQuery
WHERE [Property Name] is not null and [Address] is not null
)
SELECT bid.[Building ID], bpi.Street, bpi.[ Zip], bpi.[Year Built],
CASE WHEN bpi.[Year Built] BETWEEN 1800 AND 1824 THEN '1800-1824'
         WHEN bpi.[Year Built] BETWEEN 1825 AND 1849 THEN '1825-1849'
		 WHEN bpi.[Year Built] BETWEEN 1850 AND 1874 THEN '1850-1874'
		 WHEN bpi.[Year Built] BETWEEN 1875 AND 1899 THEN '1875-1899'
		 WHEN bpi.[Year Built] BETWEEN 1900 AND 1924 THEN '1900-1924'
		 WHEN bpi.[Year Built] BETWEEN 1925 AND 1949 THEN '1925-1949'
		 WHEN bpi.[Year Built] BETWEEN 1950 AND 1974 THEN '1950-1974'
		 WHEN bpi.[Year Built] BETWEEN 1975 AND 1999 THEN '1977-1999'
         ELSE '2000-2020' END as [Year Built Range],
bpi.[Property Type], bpi.[Property Uses],
bmet.Year, bmet.[Gross Area (sq ft) _], bmet.[Site EUI (kBtu/ft²)], bmet.[ENERGY STAR Score],
bmet.[Total Site Energy (kBTU)], bmet.[Water Intensity (gal/sf)],
bmet.[Water Intensity (gal/sf)] * bmet.[Gross Area (sq ft) _] as [Total Water (gal)], 
bmet.[GHG Emissions (MTCO2e)], bmet.[GHG Intensity (kgCO2/sf)],
[Onsite Renewable (kWh)]
FROM Building_ID bid
INNER JOIN Portfolio..Boston_Metrics bmet
	ON bid.[Property Name] = bmet.[Property Name]
	AND bid.[Address] = bmet.[Address]
INNER JOIN Portfolio..Boston_Prop_Info bpi
	ON bid.[Property Name] = bpi.[Property Name]
	AND bid.[Address] = bpi.[Address]
WHERE bmet.[Site EUI (kBtu/ft²)] is not null OR 
	bmet.[ENERGY STAR Score] is not null OR
	bmet.[Total Site Energy (kBTU)] is not null OR
	bmet.[Water Intensity (gal/sf)] is not null OR
	bmet.[GHG Emissions (MTCO2e)] is not null OR
	bmet.[GHG Intensity (kgCO2/sf)] is not null OR
	bmet.[Onsite Renewable (kWh)] is not null;


-- notes for visualizations
-- the WANG Theature had a large amount of electricity use in 2017 this will impact results if using average

SELECT * FROM Boston_Metrics_IDs WHERE [Site EUI (kBtu/ft²)] is not null ORDER BY [Site EUI (kBtu/ft²)] DESC;

SELECT * FROM Portfolio..Boston_Prop_Info WHERE Street like 'Tremont St';
