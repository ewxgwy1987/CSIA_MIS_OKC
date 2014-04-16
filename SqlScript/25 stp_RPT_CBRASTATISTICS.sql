GO
USE [BHSDB];
GO


ALTER PROCEDURE dbo.stp_RPT_OKC_CBRASTATISTICS
		  @DTFROM datetime , 
		  @DTTO datetime 
AS
BEGIN
	PRINT 'BAGTAG STORED PROCEDURE BEGIN';
	DECLARE @DATERANGE INT=1;

	CREATE TABLE #CBRA_STATISTICS_TEMP
	(
		CBRA_ID varchar(20),
		INSPECTION_TABLE_ID varchar(20),
		BAGS_RECEIVED INT,
		BAGS_CLEARED INT,
		PERCENTAGE float
	);

	--1.Query CBRA info(1500P) into temp table
	SELECT P1500.LOCATION,P1500.BIT_STATION,P1500.LICENSE_PLATE,P1500.BAG_STATUS
	INTO #CBRA_ITEM_1500P_TEMP
	FROM ITEM_1500P AS P1500 WITH(NOLOCK)
	WHERE P1500.TIME_STAMP BETWEEN @DTFROM AND @DTTO;

	--1. Insert CBRA info and BAGS_RECEIVED into final table
	INSERT INTO #CBRA_STATISTICS_TEMP
	SELECT	CBRA_LOC.SUBSYSTEM AS CBRA_ID, 
			'BIT'+ P1500.BIT_STATION AS INSPECTION_TABLE_ID,
			COUNT(P1500.LICENSE_PLATE) AS BAGS_RECEIVED,
			0 AS BAGS_CLEARED,
			0 AS PERCENTAGE
	FROM	#CBRA_ITEM_1500P_TEMP AS P1500 WITH(NOLOCK)
	LEFT JOIN LOCATIONS CBRA_LOC ON P1500.LOCATION=CBRA_LOC.LOCATION_ID
	GROUP BY CBRA_LOC.SUBSYSTEM,
			'BIT'+ P1500.BIT_STATION;
	 -- MAY BE PROBELMS

	-------------------------------------Commented by Guo Wenyu 2014/01/07-------------------------------------
	-------------Because the number of BAGS_CLEARED is counted from MDS_BAG_COUNT
	----2.UPDATE the BAGS_CLEARED
	--UPDATE CST
	--SET  CST.BAGS_CLEARED=CLEARED_1500P.BAGS_CLEARED
	--FROM (
	--		SELECT	P1500.LOCATION AS CBRA_LOCATIONID,
	--				P1500.BIT_STATION AS TABLE_LOCATIONID,
	--				COUNT(P1500.LICENSE_PLATE) AS BAGS_CLEARED
	--		FROM	#CBRA_ITEM_1500P_TEMP P1500
	--		WHERE	P1500.BAG_STATUS='1'
	--		GROUP BY P1500.LOCATION,P1500.BIT_STATION
	--	 ) AS CLEARED_1500P, #CBRA_STATISTICS_TEMP AS CST
	--WHERE CLEARED_1500P.CBRA_LOCATIONID=CST.CBRA_LOCATIONID AND CLEARED_1500P.TABLE_LOCATIONID=CST.TABLE_LOCATIONID;

	-------------------------------------New Code added by Guo Wenyu 2014/01/07-------------------------------------
	--2.INSERT the BAGS_CLEARED only for group CBRA
	INSERT INTO #CBRA_STATISTICS_TEMP
	SELECT	MCCD.CBRA_ID,
			'CBRA' AS INSPECTION_TABLE_ID,
			0 AS BAGS_RECEIVED,
			SUM(MBC.DIFFERENT) AS BAGS_CLEARED,
			0 AS PERCENTAGE
	FROM	MDS_COUNT MBC, MDS_COUNTERS MBCR, MIS_CBRA_CLEARLINE_DEVICE MCCD
	WHERE	MBC.COUNTER_ID=MBCR.COUNTER_ID
		AND MBCR.SUBSYSTEM=MCCD.CLEARLINE_ID
		AND MBCR.TYPE='CV'
		AND MBC.TIME_STAMP BETWEEN @DTFROM AND @DTTO
	GROUP BY MCCD.CBRA_ID;

	-------------------------------------END by Guo Wenyu 2014/01/07 END-------------------------------------

	----3. UPDATE the PERCENTAGE
	--UPDATE CST 
	--SET CST.PERCENTAGE=CAST(CST.BAGS_CLEARED AS float)/CAST(CST.BAGS_RECEIVED AS float)*100
	--FROM #CBRA_STATISTICS_TEMP AS CST;

	SELECT * FROM #CBRA_STATISTICS_TEMP;
END

--DECLARE @DTFrom [datetime]='2014-1-7';
--DECLARE @DTTo [datetime]='2014-1-8';

--EXEC stp_RPT25_CBRASTATISTICS_GWYTEST @DTFrom,@DTTo