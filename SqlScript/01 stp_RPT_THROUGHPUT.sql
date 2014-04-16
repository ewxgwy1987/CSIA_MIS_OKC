GO
USE [BHSDB];
GO

ALTER PROCEDURE dbo.stp_RPT_OKC_THROUGHTPUT
		  @DTFROM DATETIME,
		  @DTTO DATETIME,
		  @INTERVAL INT,--MINUTES
		  @SUBSYSTEM_TYPE VARCHAR(MAX)
AS
BEGIN
	PRINT 'BAGTAG STORED PROCEDURE BEGIN';
	DECLARE @DATERANGE INT=1;

	--Create temp table for final result
	CREATE TABLE #TRPT_FINALRESULT_TEMP
	(
		STARTTIME DATETIME,
		DEVICE_LOCATION VARCHAR(20),
		TRPT_COUNT INT
	);

	DECLARE @STARTTIME_IDX DATETIME = @DTFROM;
	DECLARE @ENDTIME_IDX DATETIME = DATEADD(MINUTE,@INTERVAL,@STARTTIME_IDX);

	WHILE(@STARTTIME_IDX < @DTTO)
	BEGIN
		IF (@ENDTIME_IDX > @DTTO)
		BEGIN
		SET @ENDTIME_IDX=@DTTO;
		END

		--1. EDS IS COUNTED BASED ON ITEM_TRACKING BEFORE X-RAY
		IF @SUBSYSTEM_TYPE='EDS'
		BEGIN
			--1. count the bags for EDS line
			INSERT INTO #TRPT_FINALRESULT_TEMP
			SELECT	@STARTTIME_IDX AS STARTTIME,SC.DETECT_LOCATION, COUNT(DISTINCT ITI.GID) AS TRPT_COUNT
			FROM	MIS_SubsystemCatalog SC,LOCATIONS LOC,ITEM_TRACKING ITI WITH(NOLOCK)
			WHERE	SC.SUBSYSTEM_TYPE=@SUBSYSTEM_TYPE
				AND SC.SUBSYSTEM=LOC.SUBSYSTEM
				AND SC.DETECT_LOCATION=LOC.LOCATION
				AND LOC.LOCATION_ID=ITI.LOCATION 
				AND ITI.TIME_STAMP BETWEEN @STARTTIME_IDX AND @ENDTIME_IDX 
				--AND SC.MDS_DATA=0
			GROUP BY SC.DETECT_LOCATION
		END
		--2. IF SUBSYSTEM TYPE IS NOT EDS, THE COUNT IS BASED ON ITEM_PROCEEDED AND MDS_BAG_COUNT
		ELSE
		BEGIN
			--2.1 count the total bags for normal subsystems by item_proceed
			INSERT INTO #TRPT_FINALRESULT_TEMP
			SELECT	@STARTTIME_IDX AS STARTTIME,SC.DETECT_LOCATION, COUNT(DISTINCT IPR.GID) AS TOTAL_BAGS
			FROM	MIS_SubsystemCatalog SC,ITEM_PROCEEDED IPR, LOCATIONS LOC WITH(NOLOCK)
			WHERE	SC.SUBSYSTEM_TYPE=@SUBSYSTEM_TYPE
				AND SC.SUBSYSTEM=LOC.SUBSYSTEM
				AND SC.DETECT_LOCATION=LOC.LOCATION
				AND LOC.LOCATION_ID=IPR.PROCEED_LOCATION
				AND IPR.TIME_STAMP BETWEEN @STARTTIME_IDX AND @ENDTIME_IDX 
				AND NOT EXISTS(SELECT LNST.DEVICE_LOCATION FROM #TRPT_FINALRESULT_TEMP LNST WHERE LNST.DEVICE_LOCATION=SC.DETECT_LOCATION AND LNST.STARTTIME=@STARTTIME_IDX)
				--AND SC.MDS_DATA=0
			GROUP BY SC.DETECT_LOCATION

			--2.2 count the total bags for normal subsystems by MDS_BAG_COUNT
			INSERT INTO #TRPT_FINALRESULT_TEMP
			SELECT	@STARTTIME_IDX AS STARTTIME,SC.DETECT_LOCATION, SUM(MC.DIFFERENT) AS TOTAL_BAGS
			FROM	MIS_SubsystemCatalog SC, MDS_COUNT MC, MDS_COUNTERS MCR WITH(NOLOCK)
			WHERE	SC.SUBSYSTEM_TYPE=@SUBSYSTEM_TYPE
				AND SC.SUBSYSTEM=MCR.SUBSYSTEM
				AND SC.DETECT_LOCATION=MCR.LOCATION
				AND MCR.TYPE='CV'
				AND MCR.COUNTER_ID=MC.COUNTER_ID
				AND MC.TIME_STAMP BETWEEN @STARTTIME_IDX AND @ENDTIME_IDX
				AND NOT EXISTS(SELECT LNST.DEVICE_LOCATION FROM #TRPT_FINALRESULT_TEMP LNST WHERE LNST.DEVICE_LOCATION=SC.DETECT_LOCATION AND LNST.STARTTIME=@STARTTIME_IDX)
				--AND SC.MDS_DATA=1 
			GROUP BY SC.DETECT_LOCATION


		END
		SET @STARTTIME_IDX = DATEADD(MINUTE,@INTERVAL,@STARTTIME_IDX);
		SET @ENDTIME_IDX = DATEADD(MINUTE,@INTERVAL,@STARTTIME_IDX);
	END
	
	SELECT * FROM #TRPT_FINALRESULT_TEMP;
END

--DECLARE @DTFrom [datetime]='2014-1-1';
--DECLARE @DTTo [datetime]='2014-1-3';
--DECLARE @INTERVAL INT =60;
--DECLARE @SUBSYSTEM VARCHAR(MAX)='ED1,ED2,ED3,ED4,ML01,ML02,ML03,ML04,MU,ME1,ME2,ME3';
--EXEC stp_RPT_OKC_THROUGHTPUT @DTFROM,@DTTO,@INTERVAL,@SUBSYSTEM;