GO
USE [BHSDB_CLT];
GO

CREATE PROCEDURE dbo.stp_RPT_OKC_SysCommBehavior
		  @DTFrom datetime, 
		  @DTTo datetime
AS
BEGIN
	DECLARE @FaultType varchar(max)='';

	SELECT	ALM_ALMEXTFLD2 AS ALARM_EQUIPMENTID, --AS ALM_EQUIPID, 
			ALM_STARTTIME,
			ALM_ENDTIME,
			ALM_MSGDESC,
			CASE
				WHEN ALM_ENDTIME IS NOT NULL THEN DATEDIFF(SECOND,ALM_STARTTIME,ALM_ENDTIME)
				ELSE 0
			END  AS ALM_DURATION,
			MDSLOC.INTERNAL_LOC AS HIDDEN_LOC
	FROM	MDS_ALARMS, LOCATIONS MDSLOC WITH(NOLOCK)
	WHERE	ALM_UNCERTAIN = 0
			AND ALM_STARTTIME BETWEEN @DTFrom AND @DTTo
			AND ALM_ALMAREA2 IN (SELECT * FROM dbo.RPT_GETPARAMETERS(@FaultType))
			AND ALM_ALMAREA1=MDSLOC.SUBSYSTEM AND ALM_ALMEXTFLD2=MDSLOC.LOCATION
	ORDER BY MDSLOC.SUBSYSTEM,MDSLOC.INTERNAL_LOC,ALM_STARTTIME
END