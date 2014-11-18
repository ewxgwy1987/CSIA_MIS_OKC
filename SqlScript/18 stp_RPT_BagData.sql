GO
USE [BHSDB_OKC];
GO

ALTER PROCEDURE dbo.stp_RPT_OKC_BagData
		  @DTFROM datetime,
		  @DTTO datetime
AS
BEGIN
--1500P time stamp is the removed time
--Problem2: What is the location name of CBRA in IPR proceed location
--Problem3: In OKC, there is no ATR before the X-ray, and GID is changed after go into SS line

	PRINT 'BAGTAG STORED PROCEDURE BEGIN';

	DECLARE @MINUTERANGE INT=60;

	--Create temp table for final result
	CREATE TABLE #BD_BAGDATA_TEMP 
	(
		GID bigint,		
		ATR_LICENSE_PLATE VARCHAR(30),
		--BMA_TIMESTAMP DATETIME,
		BMAM_BAG_TYPE varchar(15),
		ENTER_TIMESTAMP datetime,

		LEVEL1_SCREEN_STATUS varchar(1),
		LEVEL1_SCREENED_TIME datetime,
		LEVEL2_SCREEN_STATUS varchar(1),
		LEVEL2_SCREENED_TIME datetime,

		EDS_CLEARTIME DATETIME,
		EDS_CLEARLOCATION VARCHAR(20),

		CBRA_DELIVERED_TIME datetime,
		CBRA_REMOVED_TIME datetime,
	);

	---------------#REGION 1 FOR IN-SPEC(NORMAL) BAGGAGES
	--1. Query baggage measure info into final table
	--DECLARE @NEW_SCREEN_DATE datetime=CONVERT(datetime,CONVERT(varchar,@SCREEN_DATE,103),103);

	-------------------------------------Commented by Guo Wenyu 2014/1/4-------------------------------------
	--Because some bags are lost during moving, so the GID from GID_USED should be used as the index in the report
	--INSERT INTO #BD_BAGDATA_TEMP
	--SELECT DISTINCT im.GID,
	--	   'In-Spec' AS BMAM_BAG_TYPE,
	--	   NULL AS EDS_SN, 
	--	   NULL AS ENTER_TIMESTAMP, 
	--	   NULL AS LEVEL1_SCREEN_STATUS, 
	--	   NULL AS LEVEL1_SCREENED_TIME, 
	--	   NULL AS LEVEL2_SCREEN_STATUS, 
	--	   NULL AS LEVEL2_SCREENED_TIME, 
	--	   NULL AS CBRA_DELIVERED_TIME, 
	--	   NULL AS CBRA_REMOVED_TIME,
	--	   NULL AS CBRA_ETDSTATION#
	--FROM ITEM_MEASURED im WITH(NOLOCK)
	--WHERE im.TIME_STAMP BETWEEN @DTFROM AND @DTTO
	--	AND IM.TYPE='2'; --'in-Spec'NORMAL BAG
	-------------------------------------New Code added by Guo Wenyu 2014/1/4-------------------------------------
	INSERT INTO #BD_BAGDATA_TEMP
	SELECT DISTINCT GID.GID, 
		   CASE 
				WHEN ISC.LICENSE_PLATE1 NOT LIKE '1%' AND ISC.LICENSE_PLATE1<>'0000000000' AND ISC.LICENSE_PLATE1<>'999999999' AND LEN(LICENSE_PLATE1)=10
					THEN ISC.LICENSE_PLATE1
				WHEN ISC.LICENSE_PLATE2 NOT LIKE '1%' AND ISC.LICENSE_PLATE2<>'0000000000' AND ISC.LICENSE_PLATE2<>'999999999' AND LEN(LICENSE_PLATE2)=10
					THEN ISC.LICENSE_PLATE2
				WHEN ISC.LICENSE_PLATE1 IS NOT NULL AND LTRIM(RTRIM(ISC.LICENSE_PLATE1))!=''
					THEN ISC.LICENSE_PLATE1
				WHEN ISC.LICENSE_PLATE2 IS NOT NULL AND LTRIM(RTRIM(ISC.LICENSE_PLATE2))!=''
					THEN ISC.LICENSE_PLATE2
				ELSE ISC.LICENSE_PLATE1
		   END AS ATR_LICENSE_PLATE,
		   'In-Spec'AS BMAM_BAG_TYPE,
		   NULL AS ENTER_TIMESTAMP, 
		   NULL AS LEVEL1_SCREEN_STATUS, 
		   NULL AS LEVEL1_SCREENED_TIME, 
		   NULL AS LEVEL2_SCREEN_STATUS, 
		   NULL AS LEVEL2_SCREENED_TIME, 
		   NULL AS EDS_CLEARTIME,
		   NULL AS EDS_CLEARLOCATION,
		   NULL AS CBRA_DELIVERED_TIME, 
		   NULL AS CBRA_REMOVED_TIME
	FROM LOCATIONS LOC,GID_USED GID WITH(NOLOCK)
	LEFT JOIN ITEM_SCANNED ISC WITH(NOLOCK)
		ON GID.GID=ISC.GID
		AND ISC.TIME_STAMP BETWEEN DATEADD(MINUTE,-@MINUTERANGE,@DTFROM) AND DATEADD(MINUTE,@MINUTERANGE,@DTTO)
	WHERE GID.TIME_STAMP BETWEEN @DTFROM AND @DTTO
		AND GID.LOCATION=LOC.LOCATION_ID
		AND (LOC.SUBSYSTEM LIKE 'SS%' OR LOC.SUBSYSTEM LIKE 'OSR%' OR LOC.SUBSYSTEM LIKE 'AL%');
	-------------------------------------END by Guo Wenyu 2014/1/4 END-------------------------------------

	--select * from #BD_BAGDATA_TEMP where gid='2331006623';

	CREATE NONCLUSTERED INDEX #BD_BAGDATA_TEMP_GID ON #BD_BAGDATA_TEMP(GID);

	--2. Update the time(ENTER_TIMESTAMP) when the bags entering into the EDS machine
	UPDATE BBT
	SET BBT.ENTER_TIMESTAMP=ITI.TIME_STAMP
	FROM #BD_BAGDATA_TEMP BBT, ITEM_TRACKING ITI, LOCATIONS LOC  WITH(NOLOCK)
	WHERE BBT.GID=ITI.GID
		AND ITI.LOCATION=LOC.LOCATION_ID
		AND  EXISTS(
					SELECT ELD.POST_XM_LOCATION 
					FROM GET_RPT_EDS_LINE_DEVICE() ELD
					WHERE ELD.SUBSYSTEM=LOC.SUBSYSTEM AND ELD.PRE_XM_LOCATION=LOC.LOCATION 
				  )
		AND ITI.TIME_STAMP BETWEEN DATEADD(MINUTE,-@MINUTERANGE,@DTFROM) AND DATEADD(MINUTE,@MINUTERANGE,@DTTO)

	--3. Query screen info into a tempary table #EI_ITEM_SCREENED_TEMP
	SELECT icr.GID, icr.SCREEN_LEVEL, ICR.LOCATION, icr.TIME_STAMP, icr.RESULT_TYPE 
	INTO #EI_ITEM_SCREENED_TEMP
	FROM ITEM_SCREENED icr, LOCATIONS loc, #BD_BAGDATA_TEMP BBT WITH(NOLOCK)
	WHERE BBT.GID=icr.GID
		AND (icr.SCREEN_LEVEL='1' OR icr.SCREEN_LEVEL='2' OR icr.SCREEN_LEVEL='3')
		AND icr.TIME_STAMP BETWEEN DATEADD(MINUTE,-@MINUTERANGE,@DTFROM) AND DATEADD(MINUTE,@MINUTERANGE,@DTTO)
		AND icr.LOCATION=loc.LOCATION_ID;
		--AND BBT.BMAM_BAG_TYPE='in-Spec';


	--4. Update LEVE1 screen info(LEVEL1_SCREEN_STATUS,LEVEL1_SCREENED_TIME) into final table
	UPDATE BBT
	SET BBT.LEVEL1_SCREEN_STATUS=
				CASE 
					WHEN ICR.RESULT_TYPE='1' OR ICR.RESULT_TYPE='3' OR ICR.RESULT_TYPE='5' THEN 'A'
					ELSE 'R'
				END	, 
		BBT.LEVEL1_SCREENED_TIME=ITI.TIME_STAMP,
		BBT.LEVEL2_SCREEN_STATUS=
				CASE 
					WHEN ICR.RESULT_TYPE='1' OR ICR.RESULT_TYPE='2' THEN 'A'
					ELSE 'R'
				END, 
		BBT.LEVEL2_SCREENED_TIME=ICR.TIME_STAMP
	FROM #EI_ITEM_SCREENED_TEMP ICR,#BD_BAGDATA_TEMP BBT
	LEFT JOIN ITEM_TRACKING ITI WITH(NOLOCK)
		ON BBT.GID=ITI.GID 
		AND ITI.TIME_STAMP BETWEEN  DATEADD(MINUTE,-@MINUTERANGE,@DTFROM) AND DATEADD(MINUTE,@MINUTERANGE,@DTTO)
		AND EXISTS(
					SELECT ELD.POST_XM_LOCATION 
					FROM GET_RPT_EDS_LINE_DEVICE() ELD, LOCATIONS LOC
					WHERE ELD.SUBSYSTEM=LOC.SUBSYSTEM AND ELD.POST_XM_LOCATION=LOC.LOCATION 
						AND ITI.LOCATION=LOC.LOCATION_ID
				  )
	WHERE BBT.GID=icr.GID;
		--AND icr.SCREEN_LEVEL='1';

	--5. Update EDS Clear Time AND EDS CLEAR LOCATION
	SELECT GID,PRDLOC,TIME_STAMP AS TIME_STAMP
	INTO #BD_RECENT_IPR_TEMP
	FROM (
			SELECT IPR.GID, ELD.CLEAR_LOCATION AS PRDLOC,IPR.TIME_STAMP
			FROM ITEM_PROCEEDED IPR,GET_RPT_EDS_LINE_DEVICE() ELD, LOCATIONS LOC, LOCATIONS PRDLOC WITH(NOLOCK)
			WHERE IPR.LOCATION=LOC.LOCATION_ID AND IPR.PROCEED_LOCATION=PRDLOC.LOCATION_ID
				--AND ELD.SUBSYSTEM=LOC.SUBSYSTEM
				AND ELD.CLEAR_LOCATION=LOC.LOCATION
				AND ELD.CLEAR_LOCATION_TO=PRDLOC.LOCATION
				AND IPR.TIME_STAMP BETWEEN DATEADD(MINUTE,-@MINUTERANGE,@DTFROM) AND DATEADD(MINUTE,@MINUTERANGE,@DTTO)
			UNION ALL
			SELECT IPR.GID, PRELOC.LOCATION AS PRDLOC, IPR.TIME_STAMP
			FROM ITEM_PROCEEDED IPR, LOCATIONS PRELOC WITH(NOLOCK)
			WHERE IPR.PROCEED_LOCATION=PRELOC.LOCATION_ID
				AND PRELOC.LOCATION='CL5-1'
				AND IPR.TIME_STAMP BETWEEN DATEADD(MINUTE,-@MINUTERANGE,@DTFROM) AND DATEADD(MINUTE,@MINUTERANGE,@DTTO)
		) AS ALLIPR;

	UPDATE BBT
	SET BBT.EDS_CLEARTIME=IPR.TIME_STAMP,
		BBT.EDS_CLEARLOCATION = IPR.PRDLOC
	FROM #BD_BAGDATA_TEMP BBT
	LEFT JOIN #BD_RECENT_IPR_TEMP IPR
		ON BBT.GID=IPR.GID AND IPR.TIME_STAMP=(SELECT MAX(TIME_STAMP) FROM #BD_RECENT_IPR_TEMP IPR2 WHERE IPR2.GID=IPR.GID);
	
	--5. Update LEVE1 screen info(LEVEL2_SCREEN_STATUS,LEVEL2_SCREENED_TIME) into final table
	--UPDATE BBT
	--SET BBT.LEVEL2_SCREEN_STATUS=
	--			CASE 
	--				WHEN ICR.RESULT_TYPE='12' OR ICR.RESULT_TYPE='22' THEN 'A'
	--				ELSE 'R'
	--			END, 
	--	BBT.LEVEL2_SCREENED_TIME=ICR.TIME_STAMP
	--FROM #EI_ITEM_SCREENED_TEMP ICR, #BD_BAGDATA_TEMP BBT
	--WHERE BBT.GID=icr.GID 
	--	AND ICR.SCREEN_LEVEL='2';
	--------------------END #REGION 1 END----------------------

	---------------#REGION 2 FOR OOG BAGGAGES------------------
	
	--9. Insert OOG bags GID into final table from the oog lines
	INSERT INTO #BD_BAGDATA_TEMP
	SELECT
		   GID,
		   NULL AS ATR_LICENSE_PLATE,
		   'OOG' AS BMAM_BAG_TYPE,
		   NULL AS ENTER_TIMESTAMP, 
		   NULL AS LEVEL1_SCREEN_STATUS, 
		   NULL AS LEVEL1_SCREENED_TIME, 
		   NULL AS LEVEL2_SCREEN_STATUS, 
		   NULL AS LEVEL2_SCREENED_TIME, 
		   NULL AS EDS_CLEARTIME,
		   NULL AS EDS_CLEARLOCATION,
		   NULL AS CBRA_DELIVERED_TIME, 
		   NULL AS CBRA_REMOVED_TIME
	FROM GID_USED GID, LOCATIONS LOC WITH(NOLOCK)
	WHERE GID.TIME_STAMP BETWEEN @DTFROM AND @DTTO
		AND GID.LOCATION=LOC.LOCATION_ID
		AND (LOC.LOCATION = 'OG1-11');

	----11. Update OOG identified time
	----An oog bag cannot get the identified time from BMAM, because the GID is changed after oog line
	--UPDATE BBT
	--SET BBT.ENTER_TIMESTAMP=IM.TIME_STAMP
	--FROM #BD_BAGDATA_TEMP BBT, ITEM_MEASURED IM, LOCATIONS LOC WITH(NOLOCK)
	--WHERE BBT.GID=IM.GID
	--	AND BBT.BMAM_BAG_TYPE='OOG'
	--	AND IM.LOCATION=LOC.LOCATION_ID
	--	AND LOC.LOCATION IN ('SS1-2','SS2-2','SS3-2','SS4-2')
	--	AND IM.TIME_STAMP BETWEEN DATEADD(MINUTE,-@MINUTERANGE,@DTFROM) AND DATEADD(MINUTE,@MINUTERANGE,@DTTO)

	--------------------END #REGION 2 END----------------------

	--7. Update CBRA Delivered time(CBRA_DELIVERED_TIME) into final table
	UPDATE BBT
	SET BBT.CBRA_DELIVERED_TIME=ipr.TIME_STAMP
	FROM ITEM_PROCEEDED ipr, LOCATIONS loc, #BD_BAGDATA_TEMP BBT WITH(NOLOCK)
	WHERE ipr.GID=BBT.GID AND BBT.GID IS NOT NULL
		AND ipr.PROCEED_LOCATION=loc.LOCATION_ID 
		AND loc.SUBSYSTEM LIKE 'AL%'--Maybe another name
		AND LOC.LOCATION='AL1-11'
		AND ipr.TIME_STAMP BETWEEN DATEADD(MINUTE,-@MINUTERANGE,@DTFROM) AND DATEADD(MINUTE,@MINUTERANGE,@DTTO)



	--8. Update CBRA Removed time and new GID(CBRA_REMOVED_TIME) into final table
	--some problem here
	--PROBLEM: Telegram 1500P is not sent when bags are removed, but before bags are moved to inspection tables.
	UPDATE BBT
	SET BBT.CBRA_REMOVED_TIME=i1500.TIME_STAMP
	FROM #BD_BAGDATA_TEMP BBT, ITEM_1500P i1500 WITH(NOLOCK)
	LEFT JOIN LOCATIONS LOC ON  i1500.LOCATION=LOC.LOCATION_ID
	--LEFT JOIN  MIS_CBRA_ETD#2LOCATION_MAP CELM ON LOC.LOCATION=CELM.LOCATION
	WHERE i1500.GID=BBT.GID
		AND i1500.TIME_STAMP BETWEEN DATEADD(MINUTE,-@MINUTERANGE,@DTFROM) AND DATEADD(MINUTE,@MINUTERANGE,@DTTO)
	

	SELECT * FROM #BD_BAGDATA_TEMP
	ORDER BY ENTER_TIMESTAMP;
END

--declare @DTFROM datetime='2013-12-27';
--declare @DTTO datetime='2013-12-28';
--exec stp_RPT_OKC_BagData @DTFROM,@DTTO;

--SELECT * FROM ITEM_1500P WHERE GID='3110000515';