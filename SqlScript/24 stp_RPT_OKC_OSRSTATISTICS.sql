GO
USE [BHSDB_OKC];
GO


ALTER PROCEDURE dbo.stp_RPT_OKC_OSRSTATISTICS
		  @DTFROM datetime , 
		  @DTTO datetime 
AS
BEGIN
	DECLARE @MINRANGE INT = 10;

	CREATE TABLE #OSR_STAT_TEMP
	(
		OSR_ID VARCHAR(20),
		EDS_ID VARCHAR(20),
		TOTAL_BAGS INT,
		CLEARED_BAGS INT,
		AVG_TIME INT,--SECONDS
	)
	--0. PREPARE ITEM_SCREENED WITH LEVEL 2
	SELECT ICR.GID,ICR.TIME_STAMP,ICR.RESULT_TYPE,ICR.SCREEN_LEVEL,LOC.SUBSYSTEM,LOC.LOCATION
	INTO #OSR_ITEM_SCREENED_TEMP
	FROM ITEM_SCREENED ICR, LOCATIONS LOC WITH(NOLOCK)
	WHERE ICR.TIME_STAMP BETWEEN @DTFROM AND @DTTO
		AND ICR.SCREEN_LEVEL='2'
		AND ICR.LOCATION=LOC.LOCATION_ID

	--1. INSERT THE QUANTITY OF TOTAL BAGS FROM DIFFERENT EDS TO OSR
	INSERT INTO #OSR_STAT_TEMP
	SELECT	'OSR1' AS OSR_ID,
			ICR.LOCATION AS EDS_ID,
			COUNT(DISTINCT ICR.GID) AS TOTAL_BAGS,
			0 AS CLEARED_BAGS, 0 AS AVG_TIME
	FROM	#OSR_ITEM_SCREENED_TEMP ICR
	GROUP BY ICR.LOCATION


	--2. UPDATE THE QUANTITY OF CLEARED BAGS
	UPDATE	#OSR_STAT_TEMP
	SET		CLEARED_BAGS=CLR_BAGS.CLR_BAGS
	FROM	(
				SELECT	ICR.LOCATION AS EDS_ID,COUNT(DISTINCT ICR.GID) AS CLR_BAGS
				FROM	#OSR_ITEM_SCREENED_TEMP ICR
				WHERE	(ICR.RESULT_TYPE='1' OR ICR.RESULT_TYPE='2')
				GROUP BY ICR.LOCATION
			) CLR_BAGS, #OSR_STAT_TEMP AS STAT
	WHERE	CLR_BAGS.EDS_ID=STAT.EDS_ID

	--3. CALCULATE AVERAGE PROCESS TIME

	--3.1 ITEM_TRACKING TIME STAMP FOR EDS
	SELECT	ITI.GID,LOC.SUBSYSTEM,LOC.LOCATION,ITI.TIME_STAMP
	INTO	#EDS_ITEM_TRACKING_TEMP
	FROM	ITEM_TRACKING ITI,LOCATIONS LOC WITH(NOLOCK)
	WHERE	ITI.TIME_STAMP BETWEEN DATEADD(MINUTE,-@MINRANGE,@DTFROM) AND DATEADD(MINUTE,@MINRANGE,@DTTO)
		AND ITI.LOCATION=LOC.LOCATION_ID;

	--3.2 TIME STAMP FOR ENTERING X-RAY, EXITING X-RAY AND GETTING RESULT OF ICR
	SELECT ICR.LOCATION AS EDS_ID, ICR.GID,PREITI.TIME_STAMP AS ENTER_TIME, POSTITI.TIME_STAMP AS EXIT_TIME, ICR.TIME_STAMP AS ICR_TIME
	INTO #EDS_BAG_TIME
	FROM #OSR_ITEM_SCREENED_TEMP ICR, #EDS_ITEM_TRACKING_TEMP PREITI, #EDS_ITEM_TRACKING_TEMP POSTITI, GET_RPT_EDS_LINE_DEVICE() ELD
	WHERE ICR.GID=PREITI.GID AND ICR.GID=POSTITI.GID
		AND ICR.SUBSYSTEM=ELD.SUBSYSTEM
		AND ELD.PRE_XM_LOCATION=PREITI.LOCATION AND ELD.POST_XM_LOCATION=POSTITI.LOCATION

	--3.3 TIME DURATION
	SELECT EDS_ID, EBT.GID, DATEDIFF(SECOND,EBT.EXIT_TIME,EBT.ICR_TIME) AS L2_DURATION, DATEDIFF(SECOND,EBT.ENTER_TIME,EBT.ICR_TIME) AS PROC_DURATION
	INTO #EDS_BAG_DURATION
	FROM #EDS_BAG_TIME EBT

	--3.4 AVERAGE PROCESS TIME FOR OSR
	UPDATE #OSR_STAT_TEMP
	SET AVG_TIME =  ICR_AVG.AVG_TIME
	FROM	(	SELECT EDS_ID, AVG(EBD.L2_DURATION) AS AVG_TIME
				FROM #EDS_BAG_DURATION EBD
				WHERE EBD.L2_DURATION IS NOT NULL AND EBD.L2_DURATION>0
				GROUP BY EDS_ID
			) ICR_AVG, #OSR_STAT_TEMP STAT
	WHERE	ICR_AVG.EDS_ID=STAT.EDS_ID

	--return 
	SELECT * FROM #OSR_STAT_TEMP
END