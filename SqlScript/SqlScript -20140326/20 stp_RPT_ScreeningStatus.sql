GO
USE [BHSDB];
GO

ALTER PROCEDURE [dbo].[stp_RPT_OKC_ScreeningStatus]
	@DTFrom [datetime],
	@DTTo [datetime]
AS
BEGIN
	SET NOCOUNT ON;

	--1	Machine Clear / Operator Clear	MCOC
	--2	Machine Alarm / Operator Clear	MAOC
	--3	Machine Clear / Operator Alarm	MCOA
	--4	Machine Alarm / Operator Alarm	MAOA
	--5	Machine Clear / Operator Timed Out	MCOT
	--6	Machine Alarm / Operator Timed Out	MAOT
	--7	Error / Unknown	UNK/ERR
	print '[stp_RPT22_ScreeningStatus_GWYTEST]';


	--1. Insert item_screened data into a temp table

	SELECT LOCATION,GID,SCREEN_LEVEL,TIME_STAMP,RESULT_TYPE
	INTO #EDS_ITEM_SCREENED_TEMP
	FROM ITEM_SCREENED WITH(NOLOCK)
	WHERE TIME_STAMP BETWEEN @DTFrom AND @DTTo;

	--2 select eds machine(level1) result detail into a temp table
	--SELECT ICR.GID, ICR.TIME_STAMP, 
	--	CASE 
	--		WHEN ICR.RESULT_TYPE LIKE '2%' THEN 'Cleared'
	--		WHEN ICR.RESULT_TYPE LIKE '1%' THEN 'Alarmed'
	--		ELSE 'Unknown'
	--	END AS RESULT
	--INTO #EDS_RESULT_TEMP
	--FROM #EDS_ITEM_SCREENED_TEMP ICR, LOCATIONS LOC
	--WHERE ICR.SCREEN_LEVEL='1'
	--	AND ICR.LOCATION=LOC.LOCATION_ID

	--SELECT * FROM #EDS_RESULT_TEMP;

	--3 update eds result for #EDS_RESULT_TEMP by level 2 screened result
	SELECT ICR.GID, ICR.TIME_STAMP, 
		CASE
			WHEN ICR.RESULT_TYPE='1' OR ICR.RESULT_TYPE='2' THEN 'Cleared'
			WHEN ICR.RESULT_TYPE='3' OR ICR.RESULT_TYPE='4' THEN 'Alarmed'
			WHEN ICR.RESULT_TYPE='5' OR ICR.RESULT_TYPE='6' THEN 'No Decision'
			ELSE 'Unknown'
		END AS RESULT
	INTO #EDS_RESULT_TEMP
	FROM #EDS_ITEM_SCREENED_TEMP ICR
	--WHERE ERT.GID=ICR.GID
		--AND ICR.SCREEN_LEVEL='2'

	--4 calculate the statistics result
	SELECT COUNT(GID) AS Number_Bags, ERT.RESULT AS Screening_Status
	FROM #EDS_RESULT_TEMP ERT
	GROUP BY ERT.RESULT

END

--DECLARE @DTFrom [datetime]='2014-1-11';
--DECLARE @DTTo [datetime]='2014-1-12';
--EXEC stp_RPT22_ScreeningStatus_GWYTEST @DTFrom,@DTTo;