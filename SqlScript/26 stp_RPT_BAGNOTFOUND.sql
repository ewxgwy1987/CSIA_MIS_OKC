GO
USE [BHSDB];
GO

ALTER PROCEDURE dbo.stp_RPT_OKC_BAGNOTFOUND
		  @DTFROM datetime, 
		  @DTTO datetime
AS
BEGIN
	PRINT 'BAGTAG STORED PROCEDURE BEGIN';
	DECLARE @DATERANGE INT=1;

	--1.Query the bags data from BSM into temp table #BNF_BAG_SORTING_TEMP
	SELECT DISTINCT LICENSE_PLATE,GIVEN_NAME,SURNAME,OTHERS_NAME,FLIGHT_NUMBER,AIRLINE INTO #BNF_BAG_SORTING_TEMP
	FROM 
	(
		SELECT LICENSE_PLATE,GIVEN_NAME,SURNAME,OTHERS_NAME,FLIGHT_NUMBER,AIRLINE
		FROM BAG_SORTING WITH(NOLOCK)
		WHERE TIME_STAMP BETWEEN DATEADD(DAY,-@DATERANGE,@DTFROM) AND DATEADD(DAY,@DATERANGE,@DTTO)
		UNION ALL
		SELECT LICENSE_PLATE,GIVEN_NAME,SURNAME,OTHERS_NAME,FLIGHT_NUMBER,AIRLINE
		FROM BAG_SORTING_HIS WITH(NOLOCK)
		WHERE TIME_STAMP BETWEEN DATEADD(DAY,-@DATERANGE,@DTFROM) AND DATEADD(DAY,@DATERANGE,@DTTO) 
	) AS BAG_SORTING_ALL ;

	CREATE NONCLUSTERED INDEX #BNF_BAG_SORTING_TEMP_IDXLP ON #BNF_BAG_SORTING_TEMP(LICENSE_PLATE);

	--2.Query the bags INFO from BAG_INFO into temp table #BNF_BAG_INFO_TEMP
	SELECT DISTINCT GID,LOCATION AS LOCATION_SEEN,TIME_STAMP,LICENSE_PLATE1,LICENSE_PLATE2 INTO #BNF_BAG_INFO_TEMP
	FROM 
	(
		SELECT GID,LOC.LOCATION,TIME_STAMP,BI.LICENSE_PLATE1,BI.LICENSE_PLATE2
		FROM BAG_INFO BI, LOCATIONS LOC WITH(NOLOCK)
		WHERE TIME_STAMP BETWEEN DATEADD(DAY,-@DATERANGE,@DTFROM) AND DATEADD(DAY,@DATERANGE,@DTTO)
			AND BI.LAST_LOCATION=LOC.LOCATION_ID
		UNION ALL
		SELECT GID,LOC.LOCATION,TIME_STAMP,BI.LICENSE_PLATE1,BI.LICENSE_PLATE2
		FROM BAG_INFO BI, LOCATIONS LOC  WITH(NOLOCK)
		WHERE TIME_STAMP BETWEEN DATEADD(DAY,-@DATERANGE,@DTFROM) AND DATEADD(DAY,@DATERANGE,@DTTO) 
			AND BI.LAST_LOCATION=LOC.LOCATION_ID
	) AS BAG_INFO_ALL

	CREATE NONCLUSTERED INDEX ##BNF_BAG_INFO_TEMP_GIDXLP ON #BNF_BAG_INFO_TEMP(GID);

	--3. Query bag data in ITEM_REDIRECT with No flight or No allocation
	SELECT MAX(TIME_STAMP) AS TIME_STAMP, GID
	INTO #BNF_ITEM_REDIRECT_TEMP
	FROM ITEM_REDIRECT IRD WITH(NOLOCK)
	WHERE IRD.TIME_STAMP BETWEEN @DTFROM AND @DTTO
		AND (IRD.REASON='11' OR IRD.REASON='13') --No flight or No allocation
	GROUP BY GID;

	CREATE NONCLUSTERED INDEX #BNF_ITEM_REDIRECT_TEMP_IDXGID ON #BNF_ITEM_REDIRECT_TEMP(GID);

	--4.Query Bag BSM Data and Item Scanned Data for each not found baggage
	SELECT	BSG.AIRLINE AS CARRIER_ID, 
			BSG.LICENSE_PLATE AS TAG_NUMBER,
			BI.TIME_STAMP AS TIME_SEEN,
			BI.LOCATION_SEEN,
			(ISNULL(GIVEN_NAME,'')+' '+ISNULL(SURNAME,'')+' '+ISNULL(OTHERS_NAME,'')) AS PAX_NAME,
			(BSG.AIRLINE+BSG.FLIGHT_NUMBER) AS FLTNUM			
	FROM	#BNF_ITEM_REDIRECT_TEMP IRD
	--LEFT JOIN ITEM_SCANNED ISC WITH(NOLOCK) 
	--	ON	IRD.GID=ISC.GID 
	--	AND ISC.TIME_STAMP BETWEEN DATEADD(DAY,-@DATERANGE,@DTFROM) AND DATEADD(DAY,@DATERANGE,@DTTO)
	LEFT JOIN #BNF_BAG_INFO_TEMP BI
		ON	IRD.GID=BI.GID 
	--INNER JOIN LOCATIONS LOC WITH(NOLOCK) ON ISC.LOCATION=LOC.LOCATION_ID
	LEFT JOIN #BNF_BAG_SORTING_TEMP BSG ON (BSG.LICENSE_PLATE=BI.LICENSE_PLATE1 OR BSG.LICENSE_PLATE=BI.LICENSE_PLATE2)

		--AND IRD.TIME_STAMP BETWEEN DATEADD(DAY,-@DATERANGE,@DTFROM) AND DATEADD(DAY,@DATERANGE,@DTTO)
		--AND (IRD.REASON='11' OR IRD.REASON='13'); --No flight or No allocation

END

--DECLARE @DTFrom [datetime]='2013-12-19';
--DECLARE @DTTo [datetime]='2014-12-21';
--exec stp_RPT_OKC_BAGNOTFOUND @DTFrom,@DTTo;