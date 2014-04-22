GO
USE [BHSDB_OKC];
GO


ALTER PROCEDURE dbo.stp_RPT_OKC_EquipOperation_JAMPHOTOCELL
		@DTFrom [datetime],
		@DTTo [datetime],
		@SubSystem varchar(MAX)
AS
BEGIN


	--SELECT	MBCR.SUBSYSTEM, 
	--		MBCR.LOCATION AS PhotoCellID, 
	--		SUM(DIFFERENT) AS TOTAL_BAGS
	--FROM	MDS_COUNT MBC, 
	--		MDS_COUNTERS MBCR,
	--		LOCATIONS LOC WITH(NOLOCK)
	--WHERE	MBC.COUNTER_ID=MBCR.COUNTER_ID
	--		AND MBCR.SUBSYSTEM=LOC.SUBSYSTEM AND MBCR.LOCATION=LOC.LOCATION
	--		AND LOC.TRACKED<>1 --NOT TRACKING PHOTOCELL
	--		AND MBCR.SUBSYSTEM IN (SELECT * FROM RPT_GETPARAMETERS(@SubSystem))
	--		AND MBC.TIME_STAMP BETWEEN @DTFrom AND @DTTo 
	--GROUP BY MBCR.SUBSYSTEM,MBCR.LOCATION


	SELECT	ALM_ALMAREA1 AS SUBSYSTEM 
			,ALM_ALMEXTFLD2 AS PhotoCellID 
			,COUNT(ALM_ALMEXTFLD2) AS JAM_BAGS
	FROM	MDS_ALARMS MALM
			,LOCATIONS LOC WITH(NOLOCK)
	WHERE	ALM_STARTTIME BETWEEN @DTFrom AND @DTTo 
			AND ALM_UNCERTAIN = 0 
			AND ALM_ALMAREA1 IN (SELECT * FROM  RPT_GETPARAMETERS(@SubSystem)) 
			AND ALM_ALMAREA2 = 'AA_BJAM'
			AND MALM.ALM_ALMAREA1=LOC.SUBSYSTEM AND MALM.ALM_ALMEXTFLD2=LOC.LOCATION
			AND LOC.TRACKED<>1 --NOT TRACKING PHOTOCELL
			--AND EXISTS (SELECT LOCATION FROM LOCATIONS WHERE TRACKED = 1 AND ALM_ALMEXTFLD2=LOCATIONS.LOCATION) 
	GROUP BY ALM_ALMAREA1, ALM_ALMEXTFLD2

END

--DECLARE @DTFrom datetime='2013-11-01';
--DECLARE @DTTo datetime='2013-12-25';
--DECLARE @Subsystem varchar(max)='ED1,ED2,ED3,ED4,SS1,SS2';
--EXEC stp_RPT06_EquipOperation_JAMPHOTOCELL @DTFrom,@DTTo,@Subsystem;