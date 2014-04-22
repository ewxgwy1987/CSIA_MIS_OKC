GO
USE [BHSDB_OKC];
GO

ALTER PROCEDURE dbo.stp_RPT_OKC_INDIVIDUAL_EDS
		  @DTFROM DATETIME,
		  @DTTO DATETIME,
		  @SUBSYSTEM VARCHAR(20)
AS
BEGIN
	DECLARE @MINRANGE INT = 30;

	CREATE TABLE #INDIV_EDS_STATUS(
		EDS_NAME varchar(50) NULL,
		SW_TYPE varchar(50) NULL,
		SW_REV varchar(50) NULL,
		KEY_POS varchar(50) NULL,
		EDS_STATUS varchar(20) NULL,
		PLC_SCAN_TIME varchar(30) NULL,
		ESTOP int NULL,
		FAULTS int NULL,
		RTR_HIGH int NULL,
		RTR_LOW int NULL,
		JAMS int NULL,
		BAGS_SCR int NULL,
		BAGS_CLR int NULL,
		BAGS_ALM int NULL,
		BAGS_EDS_UNKNOWN int NULL,
		BAGS_SEEN int NULL,
		BAGS_BHS_UNKNOWN int NULL,
		BAGS_BHS_UNKNOWN_PERC float NULL,
		BAGS_TIMEOUTS int NULL,
		AVG_L2_DECISION_TIME float NULL,
		AVG_BAG_PROC_TIME float NULL
	) 

	--EDS STATUS
	--1. INSERT INTO EDS_NAME
	DECLARE @EDS_NAME VARCHAR(50);
	
	SELECT	@EDS_NAME = LTRIM(RTRIM(MSTAT.STATUS))
	FROM	MDS_STATUS MSTAT
	WHERE	MSTAT.TYPE_STATUS = 'NAME' AND LOCATION=@SUBSYSTEM AND MSTAT.TYPE='EDS';

	INSERT INTO #INDIV_EDS_STATUS 
	VALUES(@EDS_NAME,'','','','','',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);

	--2. UPDATE SW_TYPE
	UPDATE	#INDIV_EDS_STATUS
	SET		SW_TYPE=LTRIM(RTRIM(MSTAT.STATUS))
	FROM	MDS_STATUS MSTAT
	WHERE	LTRIM(RTRIM(MSTAT.TYPE_STATUS))='SW_TYPE' AND MSTAT.LOCATION=@SUBSYSTEM;

	--3. UPDATE SW_REV
	UPDATE	#INDIV_EDS_STATUS
	SET		SW_REV=LTRIM(RTRIM(MSTAT.STATUS))
	FROM	MDS_STATUS MSTAT
	WHERE	LTRIM(RTRIM(MSTAT.TYPE_STATUS))='SW_VER' AND MSTAT.LOCATION=@SUBSYSTEM;

	--4. UPDATE KEY_POS
	UPDATE	#INDIV_EDS_STATUS
	SET		KEY_POS=LTRIM(RTRIM(MSTAT.STATUS))
	FROM	MDS_STATUS MSTAT
	WHERE	LTRIM(RTRIM(MSTAT.TYPE_STATUS))='KEY_POS' AND MSTAT.LOCATION=@SUBSYSTEM;

	--5. UPDATE EDS_STATUS
	DECLARE @STATUS INT;
	SELECT	@STATUS=CAST(LTRIM(RTRIM(MSTAT.STATUS)) AS INT)
	FROM	MDS_STATUS MSTAT
	WHERE	LTRIM(RTRIM(MSTAT.TYPE_STATUS))='STATUS' AND MSTAT.LOCATION=@SUBSYSTEM;

	UPDATE	#INDIV_EDS_STATUS
	SET		EDS_STATUS=(SELECT LTRIM(RTRIM(DESCRIPTION)) FROM MDS_STATUS_LK WHERE MIN<=@STATUS AND @STATUS<=ISNULL(MAX,65535) AND TYPE='EDS');
	
	--6. UPDATE PLC_SCAN_TIME
	DECLARE @PLC_NAME VARCHAR(50);
	DECLARE @PLC_SCANTIME VARCHAR(50);

	SELECT	@PLC_NAME='PLC-'+LTRIM(RTRIM(MSTAT.STATUS))
	FROM	MIS_DEVICE_PLC_MAP DPM, MDS_STATUS MSTAT
	WHERE	DPM.EQUIP_SUBSYSTEM=@SUBSYSTEM 
		AND DPM.PLC_OTHERNAME=MSTAT.LOCATION
		AND MSTAT.TYPE='PLC'
		AND	MSTAT.STATUS_ID LIKE '%NAME';

	SELECT	@PLC_SCANTIME=LTRIM(RTRIM(MSTAT.STATUS))/1000
	FROM	MIS_DEVICE_PLC_MAP DPM, MDS_STATUS MSTAT
	WHERE	DPM.EQUIP_SUBSYSTEM=@SUBSYSTEM 
		AND DPM.PLC_OTHERNAME=MSTAT.LOCATION
		AND MSTAT.TYPE='PLC'
		AND	MSTAT.STATUS_ID LIKE '%SCANTIME%';

	PRINT @PLC_SCANTIME

	UPDATE	#INDIV_EDS_STATUS
	SET		PLC_SCAN_TIME=ISNULL(@PLC_SCANTIME,'')+'ms ('+@PLC_NAME+')';

	--EDS Fault
	DECLARE @EQUIP_ID VARCHAR(20)='XR-'+@SUBSYSTEM;

	--1. ESTOP 
	UPDATE	#INDIV_EDS_STATUS
	SET		ESTOP = dbo.RPT_GET_FAULT_DURATION(@DTFROM,@DTTO,@SUBSYSTEM,@EQUIP_ID,'AA_ESTP')

	--2. FAULTS
	UPDATE	#INDIV_EDS_STATUS
	SET		FAULTS = dbo.RPT_GET_FAULT_DURATION(@DTFROM,@DTTO,@SUBSYSTEM,@EQUIP_ID,'AA_FT,AA_XMAL')

	--3. RTR_HIGH
	UPDATE	#INDIV_EDS_STATUS
	SET		RTR_HIGH = dbo.RPT_GET_FAULT_DURATION(@DTFROM,@DTTO,@SUBSYSTEM,@EQUIP_ID,'AA_RDRV')

	--4. RTR_LOW
	UPDATE	#INDIV_EDS_STATUS
	SET		RTR_LOW = dbo.RPT_GET_FAULT_DURATION(@DTFROM,@DTTO,@SUBSYSTEM,@EQUIP_ID,'AA_NRRV')

	--5. JAMS
	UPDATE	#INDIV_EDS_STATUS
	SET		JAMS = dbo.RPT_GET_FAULT_DURATION(@DTFROM,@DTTO,@SUBSYSTEM,@EQUIP_ID,'AA_BJAM')


	--EDS STATISTICS
	--1. Insert item_screened data into a temp table
	SELECT	GID,SCREEN_LEVEL,TIME_STAMP,RESULT_TYPE,LOC.SUBSYSTEM,LOC.LOCATION
	INTO	#EDS_ITEM_SCREENED_TEMP
	FROM	ITEM_SCREENED ICR,LOCATIONS LOC WITH(NOLOCK)
	WHERE	TIME_STAMP BETWEEN @DTFrom AND @DTTo
		AND ICR.LOCATION=LOC.LOCATION_ID
		AND LOC.SUBSYSTEM=@SUBSYSTEM;

	CREATE NONCLUSTERED INDEX #EDS_ITEM_SCREENED_TEMP_IDXGID ON #EDS_ITEM_SCREENED_TEMP(GID);

	--2. UPDATE BAGS_SCR
	UPDATE #INDIV_EDS_STATUS
	SET BAGS_SCR = 
	(SELECT COUNT(ICR.GID)
	FROM #EDS_ITEM_SCREENED_TEMP ICR);

	--3. UPDATE BAGS_CLR
	UPDATE #INDIV_EDS_STATUS
	SET BAGS_CLR =  
	(SELECT COUNT(ICR.GID)
	FROM #EDS_ITEM_SCREENED_TEMP ICR
	WHERE ICR.RESULT_TYPE='1' OR ICR.RESULT_TYPE='2');

	--4. UPDATE BAGS_ALM
	UPDATE #INDIV_EDS_STATUS
	SET BAGS_ALM =  
	(SELECT COUNT(ICR.GID)
	FROM #EDS_ITEM_SCREENED_TEMP ICR
	WHERE ICR.RESULT_TYPE='3' OR ICR.RESULT_TYPE='4');

	--5. UPDATE BAGS_EDS_UNKNOWN
	UPDATE #INDIV_EDS_STATUS
	SET BAGS_EDS_UNKNOWN =  
	(SELECT COUNT(ICR.GID)
	FROM #EDS_ITEM_SCREENED_TEMP ICR
	WHERE ICR.RESULT_TYPE='7');

	--6. BAGS_SEEN
	UPDATE #INDIV_EDS_STATUS
	SET BAGS_SEEN =  
	(SELECT SUM(MBC.DIFFERENT)
	FROM MDS_COUNT MBC, MDS_COUNTERS MBCR, GET_RPT_EDS_LINE_DEVICE() ELD
	WHERE MBC.TIME_STAMP BETWEEN @DTFrom AND @DTTo
		AND MBC.COUNTER_ID=MBCR.COUNTER_ID
		AND MBCR.TYPE='CV'
		AND MBCR.SUBSYSTEM=ELD.SUBSYSTEM AND ELD.SUBSYSTEM=@SUBSYSTEM
		AND MBCR.LOCATION=ELD.PRE_XM_LOCATION);

	--7. BAGS_BHS_UNKNOWN
	UPDATE #INDIV_EDS_STATUS
	SET BAGS_BHS_UNKNOWN= 
	(SELECT COUNT(GID.GID)
	FROM #EDS_ITEM_SCREENED_TEMP ICR, GID_USED GID
	WHERE ICR.GID=GID.GID 
		AND GID.TIME_STAMP BETWEEN DATEADD(MINUTE,-@MINRANGE,@DTFROM) AND @DTTO
		AND GID.BAG_TYPE='02');

	--8. BAGS_BHS_UNKNOWN_PERC
	DECLARE @BAG_SEEN_CNT INT = (SELECT BAGS_SEEN FROM #INDIV_EDS_STATUS)
	IF @BAG_SEEN_CNT != 0
	BEGIN
		UPDATE #INDIV_EDS_STATUS
		SET BAGS_BHS_UNKNOWN_PERC=CAST(BAGS_BHS_UNKNOWN AS FLOAT)/CAST(BAGS_SEEN AS FLOAT)
	END
	ELSE
	BEGIN
		UPDATE #INDIV_EDS_STATUS
		SET BAGS_BHS_UNKNOWN_PERC=-1;
	END

	--9. BAGS_TIMEOUTS
	UPDATE #INDIV_EDS_STATUS
	SET BAGS_TIMEOUTS =  
	(SELECT COUNT(ICR.GID)
	FROM #EDS_ITEM_SCREENED_TEMP ICR
	WHERE ICR.RESULT_TYPE='5' OR ICR.RESULT_TYPE='6');

	--TIME STAMP FOR EDS
	SELECT	ITI.GID,LOC.SUBSYSTEM,LOC.LOCATION,ITI.TIME_STAMP
	INTO	#EDS_ITEM_TRACKING_TEMP
	FROM	ITEM_TRACKING ITI,LOCATIONS LOC WITH(NOLOCK)
	WHERE	ITI.TIME_STAMP BETWEEN DATEADD(MINUTE,-@MINRANGE,@DTFROM) AND DATEADD(MINUTE,@MINRANGE,@DTTO)
		AND ITI.LOCATION=LOC.LOCATION_ID
		AND LOC.SUBSYSTEM=@SUBSYSTEM;

	CREATE NONCLUSTERED INDEX #EDS_ITEM_TRACKING_TEMP_IDXGID ON #EDS_ITEM_TRACKING_TEMP(GID);

	SELECT ICR.GID,PREITI.TIME_STAMP AS ENTER_TIME, POSTITI.TIME_STAMP AS EXIT_TIME, ICR.TIME_STAMP AS ICR_TIME
	INTO #EDS_BAG_TIME
	FROM #EDS_ITEM_SCREENED_TEMP ICR, #EDS_ITEM_TRACKING_TEMP PREITI, #EDS_ITEM_TRACKING_TEMP POSTITI, GET_RPT_EDS_LINE_DEVICE() ELD
	WHERE ICR.GID=PREITI.GID AND ICR.GID=POSTITI.GID
		AND ICR.SUBSYSTEM=ELD.SUBSYSTEM
		AND ELD.PRE_XM_LOCATION=PREITI.LOCATION AND ELD.POST_XM_LOCATION=POSTITI.LOCATION

	--TIME DURATION
	SELECT EBT.GID, DATEDIFF(SECOND,EBT.EXIT_TIME,EBT.ICR_TIME) AS L2_DURATION, DATEDIFF(SECOND,EBT.ENTER_TIME,EBT.ICR_TIME) AS PROC_DURATION
	INTO #EDS_BAG_DURATION
	FROM #EDS_BAG_TIME EBT


	--10.AVG_L2_DECISION_TIME
	UPDATE #INDIV_EDS_STATUS
	SET AVG_L2_DECISION_TIME =  
	ISNULL(	(	SELECT AVG(EBD.L2_DURATION)
				FROM #EDS_BAG_DURATION EBD
				WHERE EBD.L2_DURATION IS NOT NULL AND EBD.L2_DURATION>0
			),0)

	--11.AVG_BAG_PROC_TIME
	UPDATE #INDIV_EDS_STATUS
	SET AVG_BAG_PROC_TIME =  
	ISNULL(	(	SELECT AVG(EBD.PROC_DURATION)
				FROM #EDS_BAG_DURATION EBD
				WHERE EBD.PROC_DURATION IS NOT NULL AND EBD.PROC_DURATION>0
			),0)

	SELECT * FROM #INDIV_EDS_STATUS;
END

--DECLARE @DTFROM DATETIME='2014-04-05'
--DECLARE @DTTO DATETIME='2014-04-06'
--DECLARE @SUBSYSTEM VARCHAR(20)='ED1'
--EXEC stp_RPT_CLT_INDIVIDUAL_EDS @DTFROM,@DTTO,@SUBSYSTEM