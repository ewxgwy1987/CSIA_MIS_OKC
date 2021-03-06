GO
USE [BHSDB_OKC];
GO

--Simple Bag Volume Statistics

ALTER PROCEDURE dbo.stp_RPT_OKC_Simple_TimeInSystem
		  @DTFrom DATETIME,
		  @DTTo DATETIME
AS
BEGIN
	DECLARE @HOURRANGE INT=1;
	DECLARE @DATERANGE INT=1;

	--Create table for all bags time detail
	--Start Time when bags entering into system BY GID at the SS Line
	--End Time when bags are sorted to MU BY GID after the mainline ATR
	--In OKC, only GID_USED on SS line can be used as begining time
	--From the SS line, tracking is carried on until to MU or SP1
	CREATE TABLE #TMP_STIS_BAGS_TIMEDETAIL
	(
		SS_LINE_GID varchar(10),
		STARTTIME datetime,
		ENDTIME datetime,
		TRAVEL_DURATION INT,
	);

	--1. Insert bag info(license plate) and entering time BY GID at the SS Line
	INSERT INTO #TMP_STIS_BAGS_TIMEDETAIL
	SELECT  GID.GID AS SS_LINE_GID,
			GID.TIME_STAMP AS STARTTIME,
			NULL AS ENDTIME,
			NULL AS TRAVEL_DURATION
	FROM	GID_USED GID, 
			LOCATIONS GID_LOC WITH(NOLOCK)
	WHERE	GID.TIME_STAMP BETWEEN @DTFROM AND @DTTO
		AND GID.LOCATION=GID_LOC.LOCATION_ID 
		AND GID.BAG_TYPE='01'
		AND GID_LOC.SUBSYSTEM LIKE 'SS%'
	
	--SELECT * FROM #TMP_STIS_BAGS_TIMEDETAIL;

	--2. Update the end time when bags are sorted to MU BY GID after the mainline ATR
	UPDATE SBT
	SET SBT.ENDTIME=IPR.TIME_STAMP
	FROM #TMP_STIS_BAGS_TIMEDETAIL SBT, 
		 ITEM_PROCEEDED IPR,
		 LOCATIONS PRD_LOC WITH(NOLOCK)
	WHERE	SBT.SS_LINE_GID=IPR.GID
		AND IPR.TIME_STAMP BETWEEN DATEADD(HOUR,-@HOURRANGE,@DTFROM) AND DATEADD(HOUR,@HOURRANGE,@DTTO)
		AND IPR.PROCEED_LOCATION=PRD_LOC.LOCATION_ID
		AND (PRD_LOC.SUBSYSTEM LIKE 'MU%' OR PRD_LOC.SUBSYSTEM LIKE 'SP%')

	--SELECT * FROM #TMP_STIS_BAGS_TIMEDETAIL;

	--6. Calculate the duration(SECONDS) between start time and end time
	UPDATE SBT
	SET SBT.TRAVEL_DURATION = DATEDIFF(SECOND,SBT.STARTTIME,SBT.ENDTIME)
	FROM #TMP_STIS_BAGS_TIMEDETAIL SBT
	WHERE SBT.ENDTIME IS NOT NULL AND SBT.STARTTIME IS NOT NULL;

	--SELECT * FROM #TMP_STIS_BAGS_TIMEDETAIL;

	DECLARE @MAX_TIME INT; --SECONDES
	DECLARE @MIN_TIME INT; --SECONDES
	DECLARE @AVG_TIME INT; --SECONDES

	SELECT	@MAX_TIME = MAX(SBT.TRAVEL_DURATION),
			@MIN_TIME = MIN(SBT.TRAVEL_DURATION),
			@AVG_TIME = AVG(SBT.TRAVEL_DURATION)
	FROM	#TMP_STIS_BAGS_TIMEDETAIL SBT

	IF @MAX_TIME IS NULL SET @MAX_TIME = 0;
	IF @MIN_TIME IS NULL SET @MIN_TIME = 0;
	IF @AVG_TIME IS NULL SET @AVG_TIME = 0;

	SELECT @MAX_TIME AS MAX_TIME, @MIN_TIME AS MIN_TIME, @AVG_TIME AS AVG_TIME
END

--DECLARE @DTFrom [datetime]='2014-5-7';
--DECLARE @DTTo [datetime]='2014-5-8';
--exec stp_RPT_OKC_Simple_TimeInSystem @DTFrom,@DTTo