GO
USE [BHSDB_OKC];
GO

ALTER PROCEDURE dbo.stp_RPT_OKC_EDSOperation
		  @DTFrom datetime, 
		  @DTTo datetime
AS
BEGIN

	--From Phoenix
	--EDS Fault Start Time and End Time
	--SELECT ALM_ALMAREA1 AS XRAY_ID, ALM_STARTTIME AS FAULTSTART, ALM_ENDTIME AS FAULTEND
	--FROM MDS_ALARMS
	--WHERE ALM_ALMAREA2 = 'AA_NRRV' AND ALM_STARTTIME BETWEEN @DTFrom AND @DTTo
	--ORDER BY ALM_STARTTIME

	--EDS Startup time and Shutdown Time
	--SELECT ALM_ALMAREA1 AS XRAY_ID, ALM_STARTTIME AS STARTUP, ALM_ENDTIME AS SHUTDWN
	--FROM MDS_ALARMS 
	--WHERE ALM_ALMAREA2 = 'AA_XBPM' AND ALM_STARTTIME BETWEEN @DTFrom AND @DTTo
	--ORDER BY ALM_STARTTIME

	--EDS Operation Time
	--SELECT ALM_ALMAREA1 AS XRAY_ID,SUM(DATEDIFF(S,ALM_STARTTIME,ALM_ENDTIME)) AS TOTAL
	--FROM MDS_ALARMS
	--WHERE ALM_ALMAREA2 = 'AA_RDRV' AND ALM_STARTTIME BETWEEN @DTFrom AND @DTTo AND ALM_ENDTIME BETWEEN @DTFrom AND @DTTo
	--GROUP BY ALM_ALMAREA1

	CREATE TABLE #EDS_OPER_TEMP
	(
		EDS_ID VARCHAR(20),
		SUBSYSTEM VARCHAR(20),
		EDS_LOCATION VARCHAR(20),
		OPER_STARTTIME DATETIME,
		OPER_ENDTIME DATETIME,
		MANUAL_ENDTIME DATETIME,
		OPER_DURATION INT,
		BAGS_ALARM INT,
		BAGS_CLEAR INT
	);
	
	DECLARE @DAYRANGE INT=1;
	DECLARE @NOW DATETIME=GETDATE();

	--1. EDS Operation time
	INSERT INTO #EDS_OPER_TEMP
	SELECT	MALM.ALM_ALMEXTFLD2 AS EDS_ID,  --ELD.XRAY_ID AS EDS_ID, --ALM_ALMEXTFLD2
			MALM.ALM_ALMAREA1 AS SUBSYSTEM,
			ELD.EDS_LOCATION AS EDS_LOCATION,
			ALM_STARTTIME AS OPER_STARTTIME, 
			ALM_ENDTIME AS OPER_ENDTIME,
			CASE 
				WHEN ALM_ENDTIME IS NOT NULL THEN ALM_ENDTIME
				WHEN ALM_ENDTIME IS NULL AND @NOW<DATEADD(DAY,@DAYRANGE,CONVERT(DATETIME,CONVERT(VARCHAR,ALM_STARTTIME,103),103)) THEN @NOW
				ELSE NULL --HDATEADD(DAY,@DAYRANGE,CONVERT(DATETIME,CONVERT(VARCHAR,ALM_STARTTIME,103),103))
			END AS MANUAL_ENDTIME,
			0 AS OPER_DURATION,
			0 AS BAGS_ALARM,
			0 AS BAGS_CLEAR	
	FROM	DBO.GET_RPT_EDS_LINE_DEVICE() AS ELD,
			MDS_ALARMS AS MALM WITH(NOLOCK)
	WHERE	MALM.ALM_ALMAREA1=ELD.SUBSYSTEM
			--AND MALM.ALM_ALMEXTFLD2=DBO.RPT_FORMAT_LOCATION(ELD.EDS_LOCATION)
			AND ALM_STARTTIME BETWEEN @DTFrom AND @DTTo 
			AND MALM.ALM_MSGTYPE='ALARM'
			AND MALM.ALM_ALMAREA2='AA_RDRV'  --READY TO RECEIVE: OPERATION
	ORDER BY ALM_STARTTIME;

	UPDATE #EDS_OPER_TEMP
	SET OPER_DURATION=DATEDIFF(SECOND,OPER_STARTTIME,MANUAL_ENDTIME) 
	WHERE MANUAL_ENDTIME IS NOT NULL
	

	--2. the count of bag cleared during EDS operation time
	SELECT	EOT.SUBSYSTEM,EOT.EDS_LOCATION,EOT.OPER_STARTTIME,COUNT(ICR.GID) AS BAGS_CLEAR
	INTO	#EDS_EDSCLEAR_TEMP
	FROM	#EDS_OPER_TEMP EOT, 
			ITEM_SCREENED ICR,
			LOCATIONS LOC WITH(NOLOCK)
	WHERE	EOT.SUBSYSTEM=LOC.SUBSYSTEM --AND EOT.EDS_LOCATION=DBO.RPT_FORMAT_LOCATION(LOC.LOCATION)
		AND LOC.LOCATION_ID=ICR.LOCATION
		AND ICR.TIME_STAMP BETWEEN EOT.OPER_STARTTIME AND EOT.MANUAL_ENDTIME
		AND EOT.MANUAL_ENDTIME IS NOT NULL
		--AND (ICR.SCREEN_LEVEL='1' OR ICR.SCREEN_LEVEL='2' OR ICR.SCREEN_LEVEL='3')
		AND (ICR.RESULT_TYPE = '1' OR ICR.RESULT_TYPE = '3' OR ICR.RESULT_TYPE = '5') --MACHINE CLEAR
	GROUP BY EOT.SUBSYSTEM,EOT.EDS_LOCATION,EOT.OPER_STARTTIME;

	--3. the count of bag alarmed during EDS operation time
	SELECT	EOT.SUBSYSTEM,EOT.EDS_LOCATION,EOT.OPER_STARTTIME,COUNT(ICR.GID) AS BAGS_ALARM
	INTO	#EDS_EDSALARM_TEMP
	FROM	#EDS_OPER_TEMP EOT, 
			ITEM_SCREENED ICR,
			LOCATIONS LOC WITH(NOLOCK)
	WHERE	EOT.SUBSYSTEM=LOC.SUBSYSTEM --AND EOT.EDS_LOCATION=DBO.RPT_FORMAT_LOCATION(LOC.LOCATION)
		AND LOC.LOCATION_ID=ICR.LOCATION
		AND ICR.TIME_STAMP BETWEEN EOT.OPER_STARTTIME AND EOT.MANUAL_ENDTIME
		AND EOT.MANUAL_ENDTIME IS NOT NULL
		--AND (ICR.SCREEN_LEVEL='1' OR ICR.SCREEN_LEVEL='2'OR ICR.SCREEN_LEVEL='3')
		AND (ICR.RESULT_TYPE <> '1' AND ICR.RESULT_TYPE <> '3' AND ICR.RESULT_TYPE <> '5') --MACHINE ALARM
	GROUP BY EOT.SUBSYSTEM,EOT.EDS_LOCATION,EOT.OPER_STARTTIME;

	--4. update the counts of cleared bags and alarmed bags+
	UPDATE	EOT
	SET		EOT.BAGS_CLEAR=CLR.BAGS_CLEAR
	FROM	#EDS_OPER_TEMP EOT, #EDS_EDSCLEAR_TEMP CLR
	WHERE	EOT.SUBSYSTEM=CLR.SUBSYSTEM AND EOT.EDS_LOCATION=CLR.EDS_LOCATION
		AND EOT.OPER_STARTTIME=CLR.OPER_STARTTIME

	UPDATE	EOT
	SET		EOT.BAGS_ALARM=ALM.BAGS_ALARM
	FROM	#EDS_OPER_TEMP EOT, #EDS_EDSALARM_TEMP ALM
	WHERE	EOT.SUBSYSTEM=ALM.SUBSYSTEM AND EOT.EDS_LOCATION=ALM.EDS_LOCATION
		AND EOT.OPER_STARTTIME=ALM.OPER_STARTTIME;

	SELECT EOT.EDS_ID, EOT.OPER_STARTTIME, EOT.OPER_ENDTIME, EOT.OPER_DURATION, EOT.BAGS_ALARM, EOT.BAGS_CLEAR
	FROM #EDS_OPER_TEMP EOT;
END

--DECLARE	@DTFrom datetime='2014/1/10 18:45:06';
--DECLARE @DTTo datetime='2014/1/11 18:45:06';
--EXEC stp_RPT_CLT_EDSOperation @DTFrom,@DTTo
