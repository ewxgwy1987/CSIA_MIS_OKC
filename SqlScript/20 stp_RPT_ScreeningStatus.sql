GO
USE [BHSDB];
GO

ALTER PROCEDURE [dbo].[stp_RPT22_ScreeningStatus_GWYTEST]
	@DTFrom [datetime],
	@DTTo [datetime]
AS
BEGIN
	SET NOCOUNT ON;

	--11	Machine Alarm / operator alarm			ALARM
	--12	Machine Alarm / operator clear			CLEAR
	--13	Machine Alarm / operator unknown		ALARM
	--14	Machine Alarm / operator pending		NO DECISION
	--15	Machine Alarm / operator timed out		NO DECISION
	--21	Machine clear / operator alarm			ALARM
	--22	Machine clear / operator clear			CLEAR
	--23	Machine clear / operator unknown		ALARM
	--24	Machine clear / operator pending		NO DECISION
	--25	Machine clear / Operator timed out		NO DECISION
	--33	Error / Unknown							UNKNOWN
	--X	Error / Unknown								UNKNOWN
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
			WHEN ICR.RESULT_TYPE='12' OR ICR.RESULT_TYPE='22' THEN 'Cleared'
			WHEN ICR.RESULT_TYPE='11' OR ICR.RESULT_TYPE='21' OR ICR.RESULT_TYPE='13' OR ICR.RESULT_TYPE='23' THEN 'Alarmed'
			WHEN ICR.RESULT_TYPE='14' OR ICR.RESULT_TYPE='24' OR ICR.RESULT_TYPE='15' OR ICR.RESULT_TYPE='25' THEN 'No Decision'
			ELSE 'Unknown'
		END AS RESULT
	INTO #EDS_RESULT_TEMP
	FROM #EDS_ITEM_SCREENED_TEMP ICR
	--WHERE ERT.GID=ICR.GID
		--AND ICR.SCREEN_LEVEL='2'

	--4 calculate the statistics result
	SELECT COUNT(GID) AS Number_Bags, ERT.RESULT
	FROM #EDS_RESULT_TEMP ERT
	GROUP BY ERT.RESULT

END

--DECLARE @DTFrom [datetime]='2014-1-11';
--DECLARE @DTTo [datetime]='2014-1-12';
--EXEC stp_RPT22_ScreeningStatus_GWYTEST @DTFrom,@DTTo;