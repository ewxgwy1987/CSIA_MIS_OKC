GO
USE [BHSDB];
GO


ALTER PROCEDURE dbo.stp_RPT_OKC_BAGTAG
		  @SDO datetime 
AS
BEGIN
	-- NOTE: Tag report is based on IATA tag scanned by ATR or MES
	-- The license plates which are not scanned by ATR or MES will not be shown in this report
	DECLARE @DATERANGE INT=1;
	DECLARE @HOURRANGE INT = 4;

	SET @SDO = CONVERT(DATETIME,CONVERT(VARCHAR,@SDO,103),103);--ONLY DATE PART

	--Create temp table for final result
	CREATE TABLE #BT_BAG_TAG_TEMP 
	(
		GID BIGINT,
		LICENSE_PLATE VARCHAR(10),
		PAX_NAME VARCHAR(200),
		FLIGHT_NUMBER VARCHAR(5),
		AIRLINE VARCHAR(3),
		SDO DATETIME,
		STD DATETIME,
		TAG_READ_TIME DATETIME,
		TAG_READ_LOCATION VARCHAR(20),
		BAG_TYPE VARCHAR(15),
		ALLOC_MU VARCHAR(10),
		SORTED_MU VARCHAR(10)
	);

	--1. Query the ATR read info into temp table #BT_ITEM_TAGREAD_TEMP
	SELECT ISC.GID, ISC.LICENSE_PLATE1, ISC.LICENSE_PLATE2, ISC.LOCATION, ISC.TIME_STAMP 
	INTO #BT_ITEM_TAGREAD_TEMP
	FROM ITEM_SCANNED ISC WITH(NOLOCK)
	WHERE ISC.TIME_STAMP BETWEEN DATEADD(DAY,-@DATERANGE,@SDO) AND DATEADD(DAY,@DATERANGE,@SDO)
		AND (ISC.STATUS_TYPE='1' OR ISC.STATUS_TYPE='3' OR ISC.STATUS_TYPE='7')

	--2. Query the MES read info into temp table #BT_ITEM_TAGREAD_TEMP 
	INSERT INTO #BT_ITEM_TAGREAD_TEMP
	SELECT IER.GID,IER.LICENSE_PLATE AS LICENSE_PLATE1,'0000000000' AS LICENSE_PLATE2,IER.LOCATION,IER.TIME_STAMP 
	FROM ITEM_ENCODING_REQUEST IER WITH(NOLOCK)
	WHERE IER.TIME_STAMP BETWEEN DATEADD(DAY,-@DATERANGE,@SDO) AND DATEADD(DAY,@DATERANGE,@SDO)
	
	--3. In Oklahoma project, there are 1 ATR and 1 MES which a bag may goes through. 
	--So stored procedure must find the lastest location where item_scanned telegram is sent ordered by time_stamp
	DECLARE @TAGREAD_TABLE AS TAGREAD_TABLETYPE; --For the parameter of stp_RPT_GET_LATEST_TAGREAD

	INSERT INTO @TAGREAD_TABLE
	SELECT * FROM #BT_ITEM_TAGREAD_TEMP;
	
	CREATE TABLE #BT_TAGREAD_TEMP
	( 
		GID VARCHAR(10),
		LICENSE_PLATE VARCHAR(10),
		LOCATION VARCHAR(20), 
		TIME_STAMP DATETIME
	);

	INSERT INTO #BT_TAGREAD_TEMP
	EXEC dbo.stp_RPT_GET_LATEST_TAGREAD @TAGREAD_TABLE;

	CREATE NONCLUSTERED INDEX #BT_TAGREAD_TEMP_IDXLP ON #BT_TAGREAD_TEMP(LICENSE_PLATE);

	--4. Query the bags data from BSM into temp table #BT_BAG_SORTING_TEMP
	SELECT DISTINCT LICENSE_PLATE,SDO,GIVEN_NAME,SURNAME,OTHERS_NAME,FLIGHT_NUMBER,AIRLINE,SOURCE INTO #BT_BAG_SORTING_TEMP
	FROM 
	(
		SELECT LICENSE_PLATE,SDO,GIVEN_NAME,SURNAME,OTHERS_NAME,FLIGHT_NUMBER,AIRLINE,SOURCE
		FROM BAG_SORTING WITH(NOLOCK)
		WHERE SDO BETWEEN DATEADD(DAY,-@DATERANGE,@SDO) AND DATEADD(DAY,2*@DATERANGE,@SDO)
		UNION ALL
		SELECT LICENSE_PLATE,SDO,GIVEN_NAME,SURNAME,OTHERS_NAME,FLIGHT_NUMBER,AIRLINE,SOURCE
		FROM BAG_SORTING_HIS WITH(NOLOCK)
		WHERE SDO BETWEEN DATEADD(DAY,-@DATERANGE,@SDO) AND DATEADD(DAY,2*@DATERANGE,@SDO)

	) AS BAG_SORTING_ALL ;

	CREATE NONCLUSTERED INDEX #BT_BAG_SORTING_TEMP_IDXLP ON #BT_BAG_SORTING_TEMP(LICENSE_PLATE);

	--4. Insert bags TAG data WITH BSM ON @SDO into final table
	INSERT INTO #BT_BAG_TAG_TEMP
	SELECT BTR.GID,BTR.LICENSE_PLATE,
		(ISNULL(BST.GIVEN_NAME,'')+' '+ISNULL(BST.SURNAME,'')+' '+ISNULL(BST.OTHERS_NAME,'')) AS PAX_NAME,
		BST.FLIGHT_NUMBER, BST.AIRLINE, BST.SDO, NULL AS STD,
		BTR.TIME_STAMP AS TAG_READ_TIME,LOC.LOCATION AS TAG_READ_LOCATION,
		CASE BST.SOURCE
		   WHEN 'L' THEN 'outbound'
		   WHEN 'T' THEN 'transfer'
		   WHEN 'A' THEN 'inbound'
		   ELSE ''
		END AS BAG_TYPE,
		'' AS ALLOC_MU,'' AS SORTED_MU
	FROM #BT_TAGREAD_TEMP BTR,#BT_BAG_SORTING_TEMP BST, LOCATIONS LOC
	WHERE BST.SDO=@SDO
	AND BTR.LICENSE_PLATE=BST.LICENSE_PLATE
	AND BTR.LOCATION=LOC.LOCATION_ID

	--5. Insert bags TAG data WITHOUT BSM into final table
	INSERT INTO #BT_BAG_TAG_TEMP
	SELECT BTR.GID,BTR.LICENSE_PLATE,
		'' AS PAX_NAME,'' AS FLIGHT_NUMBER, '' AS AIRLINE, NULL AS SDO, NULL AS STD,
		BTR.TIME_STAMP AS TAG_READ_TIME,LOC.LOCATION AS TAG_READ_LOCATION,
		'' AS BAG_TYPE, '' AS ALLOC_MU,'' AS SORTED_MU
	FROM #BT_TAGREAD_TEMP BTR, LOCATIONS LOC
	WHERE NOT EXISTS (SELECT BST.LICENSE_PLATE FROM #BT_BAG_SORTING_TEMP BST WHERE BTR.LICENSE_PLATE=BST.LICENSE_PLATE)
	AND BTR.TIME_STAMP BETWEEN DATEADD(HOUR,@HOURRANGE,@SDO) AND DATEADD(DAY,@DATERANGE,@SDO)
	AND BTR.LOCATION=LOC.LOCATION_ID

	CREATE INDEX #BT_BAG_TAG_TEMP_IDXGID ON #BT_BAG_TAG_TEMP(GID);

	--6. Update Flight Allocation Make-up carousel(ALLOC_MU) into final table
	UPDATE BTT
	SET BTT.ALLOC_MU=FPA.RESOURCE
	FROM FLIGHT_PLAN_ALLOC FPA, #BT_BAG_TAG_TEMP BTT WITH(NOLOCK)
	WHERE FPA.AIRLINE=BTT.AIRLINE AND FPA.FLIGHT_NUMBER=BTT.FLIGHT_NUMBER
		AND FPA.SDO=@SDO;

	--7. Update STD into final table
	UPDATE BTT
	SET BTT.STD=CONVERT(DATETIME,CONVERT(VARCHAR,BTT.SDO,103) + ' ' + DBO.RPT_GETFORMATTEDSTO(FPS.STO),103)
	FROM FLIGHT_PLAN_SORTING FPS, #BT_BAG_TAG_TEMP BTT WITH(NOLOCK)
	WHERE BTT.SDO IS NOT NULL
		AND FPS.AIRLINE=BTT.AIRLINE AND FPS.FLIGHT_NUMBER=BTT.FLIGHT_NUMBER AND FPS.SDO=@SDO;
		

	--8. Update sorted MU(SORTED_MU) into final table
	UPDATE BTT
	SET BTT.SORTED_MU=LOC.LOCATION
	FROM ITEM_PROCEEDED IPR, LOCATIONS LOC,#BT_BAG_TAG_TEMP BTT WITH(NOLOCK)
	WHERE IPR.GID=BTT.GID AND BTT.GID IS NOT NULL
		AND IPR.PROCEED_LOCATION = LOC.LOCATION_ID
		AND LOC.SUBSYSTEM LIKE 'MU%'
		AND IPR.TIME_STAMP BETWEEN DATEADD(DAY,-@DATERANGE,@SDO) AND DATEADD(DAY,@DATERANGE,@SDO);

	SELECT	*
	FROM	#BT_BAG_TAG_TEMP
	WHERE GID IS NOT NULL
	ORDER BY LICENSE_PLATE;
	
	
END;


--DECLARE @SDO datetime='2014-3-17';
--EXEC DBO.stp_RPT_OKC_BAGTAG @SDO;