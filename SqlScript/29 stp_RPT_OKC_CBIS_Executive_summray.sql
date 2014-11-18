GO
USE [BHSDB_OKC];
GO

alter PROCEDURE dbo.stp_RPT_OKC_CBIS_Executive_Summray
		  @DTFROM datetime,
		  @DTTO datetime
AS
BEGIN
--1500P time stamp is the removed time
--Problem2: What is the location name of CBRA in IPR proceed location
--Problem3: In OKC, there is no ATR before the X-ray, and GID is changed after go into SS line

--1	Machine Clear / Operator Clear	MCOC
--2	Machine Alarm / Operator Clear	MAOC
--3	Machine Clear / Operator Alarm	MCOA
--4	Machine Alarm / Operator Alarm	MAOA
--5	Machine Clear / Operator Timed Out	MCOT
--6	Machine Alarm / Operator Timed Out	MAOT
--7	Error / Unknown	UNK/ERR

	--declare @DTFROM datetime='5/7/2014 9:00:00 AM'
	--declare @DTTO datetime='5/7/2014 12:00:00 PM'
	--DROP TABLE #CES_BAGICR_TEMP

	PRINT 'BAGTAG STORED PROCEDURE BEGIN';

	--DECLARE @SECONDRANGE INT=20;
	DECLARE @MINUTERANGE INT=60;

	--1. Get all bags screened by X-ray with decision result
	CREATE TABLE #CES_BAGICR_TEMP 
	(
		GID bigint,		
		EDS_Location varchar(20),

		Machine_Decision_Flag int,--decision made by Machine 
		Machine_Clear_Flag int,--Machine decision clear
		Machine_Alarm_Flag int,--Machine decision alarm

		OSR_Decision_Flag int,--decision made by OSR 
		OSR_Clear_Flag int,--OSR decision clear
		OSR_Alarm_Flag int,--OSR decision alarm
	);

	--Find all bags screened by EDS with screening result
	INSERT INTO #CES_BAGICR_TEMP
	SELECT DISTINCT ICR.GID, 
			LOC.LOCATION as EDS_Location,

			-----Machine Flag
			CASE 
				WHEN ICR.RESULT_TYPE!='7' THEN 1
				ELSE 0
			END	AS Machine_Decision_Flag,

			CASE 
				WHEN ICR.RESULT_TYPE='1' OR ICR.RESULT_TYPE='3' OR ICR.RESULT_TYPE='5' THEN 1
				ELSE 0
			END	AS Machine_Clear_Flag,

			CASE 
				WHEN ICR.RESULT_TYPE='2' OR ICR.RESULT_TYPE='4' OR ICR.RESULT_TYPE='6' THEN 1
				ELSE 0
			END AS Machine_Alarm_Flag,

			-----OSR Flag
			CASE 
				--WHEN ICR.RESULT_TYPE='1' OR ICR.RESULT_TYPE='2' OR ICR.RESULT_TYPE='3' OR ICR.RESULT_TYPE='4' THEN 1
				WHEN ICR.RESULT_TYPE!='7' THEN 1
				ELSE 0
			END	AS OSR_Decision_Flag,

			CASE 
				WHEN ICR.RESULT_TYPE='1' OR ICR.RESULT_TYPE='2' THEN 1
				ELSE 0
			END	AS OSR_Clear_Flag,

			CASE 
				WHEN ICR.RESULT_TYPE='3' OR ICR.RESULT_TYPE='4' OR ICR.RESULT_TYPE='5' OR ICR.RESULT_TYPE='6' THEN 1
				ELSE 0
			END AS OSR_Alarm_Flag

	FROM ITEM_SCREENED ICR, LOCATIONS LOC WITH(NOLOCK)
	WHERE ICR.TIME_STAMP BETWEEN @DTFROM AND @DTTO
		AND ICR.LOCATION=LOC.LOCATION_ID

	--2. Get all bags with ITEM_TRACKING before the x-ray machine
	--Flag them whether they are proceeded to Clear Line or CBRA
	CREATE TABLE #CES_BAG_PREITI_TEMP 
	(
		ITI_GID bigint,	
		PRE_ITI_Location varchar(20),
		EDS_Location varchar(20),

		CLEAR_DELIVERED_TIME DATETIME,
		Tracked_ToClear_Flag int,

		CBRA_DELIVERED_TIME DATETIME,
		Tracked_ToCBRA_Flag int --Indicate the bag proceeded to CBRA
	);

	--2.1 All bags with ITEM_TRACKING before the x-ray machine
	INSERT INTO #CES_BAG_PREITI_TEMP
	SELECT	ITI.GID AS ITI_GID,
			ELD.PRE_XM_LOCATION AS PRE_ITI_Location,
			ELD.EDS_LOCATION AS EDS_Location,
			NULL AS CLEAR_DELIVERED_TIME,
			0 AS Tracked_ToClear_Flag,
			NULL AS CBRA_DELIVERED_TIME,
			0 AS Tracked_ToCBRA_Flag
	FROM	ITEM_TRACKING ITI, GET_RPT_EDS_LINE_DEVICE() ELD, LOCATIONS LOC WITH(NOLOCK)
	WHERE	ITI.LOCATION=LOC.LOCATION_ID
		AND LOC.LOCATION=ELD.PRE_XM_LOCATION
		AND	ITI.TIME_STAMP BETWEEN @DTFROM AND @DTTO


	--2.2 Collect all ITEM_PROCEEDED information about Clear line and CBRA
	SELECT GID,PRDLOC,TIME_STAMP, IPRTYPE
	INTO #CES_RECENT_IPR_TEMP
	FROM (
			--a. Clear line on the SS line
			SELECT IPR.GID, ELD.CLEAR_LOCATION AS PRDLOC,IPR.TIME_STAMP, 'C' AS IPRTYPE
			FROM ITEM_PROCEEDED IPR,GET_RPT_EDS_LINE_DEVICE() ELD, LOCATIONS LOC, LOCATIONS PRDLOC WITH(NOLOCK)
			WHERE IPR.LOCATION=LOC.LOCATION_ID AND IPR.PROCEED_LOCATION=PRDLOC.LOCATION_ID
				AND ELD.CLEAR_LOCATION=LOC.LOCATION
				AND ELD.CLEAR_LOCATION_TO=PRDLOC.LOCATION
				AND IPR.TIME_STAMP BETWEEN DATEADD(MINUTE,-@MINUTERANGE,@DTFROM) AND DATEADD(MINUTE,@MINUTERANGE,@DTTO)
			--b. Clear line before going to CBRA
			UNION ALL
			SELECT IPR.GID, PRELOC.LOCATION AS PRDLOC, IPR.TIME_STAMP, 'C' AS IPRTYPE
			FROM ITEM_PROCEEDED IPR, LOCATIONS PRELOC WITH(NOLOCK)
			WHERE IPR.PROCEED_LOCATION=PRELOC.LOCATION_ID
				AND PRELOC.LOCATION='CL5-1'
				AND IPR.TIME_STAMP BETWEEN DATEADD(MINUTE,-@MINUTERANGE,@DTFROM) AND DATEADD(MINUTE,@MINUTERANGE,@DTTO)
			--c. AL line going to CBRA
			UNION ALL
			SELECT IPR.GID, PRELOC.LOCATION AS PRDLOC, IPR.TIME_STAMP, 'A' AS IPRTYPE
			FROM ITEM_PROCEEDED IPR, LOCATIONS PRELOC WITH(NOLOCK)
			WHERE IPR.PROCEED_LOCATION=PRELOC.LOCATION_ID
				AND PRELOC.SUBSYSTEM LIKE 'AL%'
				AND PRELOC.LOCATION='AL1-11'
				AND IPR.TIME_STAMP BETWEEN DATEADD(MINUTE,-@MINUTERANGE,@DTFROM) AND DATEADD(MINUTE,@MINUTERANGE,@DTTO)
		) AS ALLIPR;

	CREATE NONCLUSTERED INDEX #CES_BAG_PREITI_TEMP_GID ON #CES_BAG_PREITI_TEMP(ITI_GID);
	CREATE NONCLUSTERED INDEX #CES_RECENT_IPR_TEMP_GID ON #CES_RECENT_IPR_TEMP(GID);
	CREATE NONCLUSTERED INDEX #CES_RECENT_IPR_TEMP_TS ON #CES_RECENT_IPR_TEMP(TIME_STAMP);

	--2.3 Update CBRA Delivered conditon
	--If the bag has an ITI telegram, 
	--but it is not proceeded to CBRA with same GID, then this bag may be lost.
	UPDATE	CBPT
	SET		CBPT.CBRA_DELIVERED_TIME=ipr.TIME_STAMP, 
			CBPT.Tracked_ToCBRA_Flag=1
	FROM	#CES_RECENT_IPR_TEMP IPR,#CES_BAG_PREITI_TEMP CBPT WITH(NOLOCK)
	WHERE	IPR.GID=CBPT.ITI_GID
		AND IPR.IPRTYPE='A'
		AND IPR.TIME_STAMP=(SELECT MAX(TIME_STAMP) FROM #CES_RECENT_IPR_TEMP IPR2 WHERE IPR2.GID=IPR.GID);

	--2.4 Update Clear line proceeded condition
	UPDATE	CBPT
	SET		CBPT.CLEAR_DELIVERED_TIME=IPR.TIME_STAMP,
			CBPT.Tracked_ToClear_Flag = 1
	FROM	#CES_RECENT_IPR_TEMP IPR,#CES_BAG_PREITI_TEMP CBPT WITH(NOLOCK)
	WHERE	CBPT.ITI_GID=IPR.GID 
		AND IPR.IPRTYPE='C'
		AND IPR.TIME_STAMP=(SELECT MAX(TIME_STAMP) FROM #CES_RECENT_IPR_TEMP IPR2 WHERE IPR2.GID=IPR.GID);

	--SELECT * FROM #CES_BAGICR_TEMP;
	--SELECT * FROM #CES_BAG_PREITI_TEMP WHERE Tracked_ToClear_Flag=0 AND Tracked_ToCBRA_Flag=0 ORDER BY EDS_Location;

	--3. Analyse the Statistic data from #CES_BAGICR_TEMP, and insert into #CES_Statistic
	CREATE TABLE #CES_Statistic
	(	
		EDS_Location varchar(20),
		QTY_Total_Bags int,
		QTY_Machine_Total_Bags int,
		QTY_Machine_Clear int,
		QTY_Machine_Alarm int,
		QTY_OSR_Total_Bags int,
		QTY_OSR_Clear int,
		QTY_OSR_Alarm int,
		QTY_Tracked_ToClear int,
		QTY_Tracked_ToCBRA int
	);

	--3.1 Total bags screened for each EDS
	INSERT	INTO #CES_Statistic
	SELECT	EDS_Location,
			0 AS QTY_Total_Bags,
			SUM(Machine_Decision_Flag) AS QTY_Machine_Total_Bags,
			SUM(Machine_Clear_Flag) AS QTY_Machine_Clear,
			SUM(Machine_Alarm_Flag) AS QTY_Machine_Alarm,
			SUM(OSR_Decision_Flag) AS QTY_OSR_Total_Bags,
			SUM(OSR_Clear_Flag) AS QTY_OSR_Clear,
			SUM(OSR_Alarm_Flag) AS QTY_OSR_Alarm,
			0 AS QTY_Tracked_ToClear,
			0 AS QTY_Tracked_ToCBRA
	FROM	#CES_BAGICR_TEMP
	GROUP BY EDS_Location;

	--3.2 Update total bags based on ITI before X-ray machine
	--Update quantity of bags proceeded to Clear Line and CBRA
	UPDATE	CS
	SET		QTY_Total_Bags = CBRT.TOTAL_BAGS,
			QTY_Tracked_ToClear = CBRT.QTY_CLEAR,
			QTY_Tracked_ToCBRA = CBRT.QTY_CBRA
	FROM	#CES_Statistic CS,
			(
				SELECT	EDS_Location, 
						COUNT(ITI_GID) AS TOTAL_BAGS,
						SUM(Tracked_ToClear_Flag) AS QTY_CLEAR,
						SUM(Tracked_ToCBRA_Flag) AS QTY_CBRA
				FROM	#CES_BAG_PREITI_TEMP
				GROUP BY EDS_Location
			) CBRT
	WHERE	CS.EDS_Location=CBRT.EDS_Location

	SELECT * FROM #CES_Statistic
	ORDER BY EDS_Location;
END

--declare @dtfrom datetime='5/5/2014 2:58:46 PM'
--declare @dtto datetime='5/5/2014 11:05:46 PM'
--exec stp_RPT_OKC_CBIS_Executive_Summray @dtfrom,@dtto