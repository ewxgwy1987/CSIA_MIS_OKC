USE [BHSDB]
GO
/****** Object:  UserDefinedFunction [dbo].[GET_LATEST_TAGREAD]  */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE TYPE TAGREAD_TABLETYPE AS TABLE
( 
	GID VARCHAR(10),
	LICENSE_PLATE1 VARCHAR(10), 
	LICENSE_PLATE2 VARCHAR(10), 
	LOCATION VARCHAR(20), 
	TIME_STAMP DATETIME
);
GO

ALTER PROCEDURE dbo.stp_RPT_GET_LATEST_TAGREAD
	@TAGREAD_TABLE AS TAGREAD_TABLETYPE readonly
AS
BEGIN
	
	SELECT * INTO #TAGTMP FROM @TAGREAD_TABLE;

	CREATE NONCLUSTERED INDEX #TAGTMP_IDXTIME ON #TAGTMP(TIME_STAMP);

	--In Charlotte project, there are 2 ATRs and MES a bag may goes through. 
	--So stored procedure must find the lastest location where item_scanned telegram is sent ordered by time_stamp

	-- Cannot use following method, because this will lost tags. 
	-- The tags, no matter in LICENSE_PLATE1 or LICENSE_PLATE1, no matter it is IATA, Fallback or 4-digit, all should be included in result
	--SELECT 
	--	CASE
	--		--IATA TAG
	--		WHEN TGR.LICENSE_PLATE1 LIKE '0%' AND TGR.LICENSE_PLATE1<>'0000000000' AND TGR.LICENSE_PLATE1<>'999999999' AND LEN(TGR.LICENSE_PLATE1)=10
	--			THEN TGR.LICENSE_PLATE1
	--		WHEN TGR.LICENSE_PLATE2 LIKE '0%' AND TGR.LICENSE_PLATE2<>'0000000000' AND TGR.LICENSE_PLATE2<>'999999999' AND LEN(TGR.LICENSE_PLATE1)=10
	--			THEN TGR.LICENSE_PLATE2
	--		--FALLBACK TAG
	--		WHEN LEN(TGR.LICENSE_PLATE1)=10 AND TGR.LICENSE_PLATE1 LIKE '1%'
	--			THEN TGR.LICENSE_PLATE1 --NULL
	--		WHEN LEN(TGR.LICENSE_PLATE2)=10 AND TGR.LICENSE_PLATE2 LIKE '1%'
	--			THEN TGR.LICENSE_PLATE2 --NULL
	--		--4 DIGIT TAG
	--		WHEN LEN(TGR.LICENSE_PLATE1)=4
	--			THEN TGR.LICENSE_PLATE1
	--		WHEN LEN(TGR.LICENSE_PLATE2)=4
	--			THEN TGR.LICENSE_PLATE2
	--		ELSE TGR.LICENSE_PLATE1
	--	END AS LICENSE_PLATE,MAX(TIME_STAMP) AS TIME_STAMP
	--INTO #BT_TAGREAD_LATESTTIME
	--FROM #TAGTMP TGR
	--GROUP BY 
	--	CASE
	--		WHEN TGR.LICENSE_PLATE1 LIKE '0%' AND TGR.LICENSE_PLATE1<>'0000000000' AND TGR.LICENSE_PLATE1<>'999999999' AND LEN(TGR.LICENSE_PLATE1)=10
	--			THEN TGR.LICENSE_PLATE1
	--		WHEN TGR.LICENSE_PLATE2 LIKE '0%' AND TGR.LICENSE_PLATE2<>'0000000000' AND TGR.LICENSE_PLATE2<>'999999999' AND LEN(TGR.LICENSE_PLATE1)=10
	--			THEN TGR.LICENSE_PLATE2
	--		WHEN LEN(TGR.LICENSE_PLATE1)=10 AND TGR.LICENSE_PLATE1 LIKE '1%'
	--			THEN TGR.LICENSE_PLATE1 --NULL
	--		WHEN LEN(TGR.LICENSE_PLATE2)=10 AND TGR.LICENSE_PLATE2 LIKE '1%'
	--			THEN TGR.LICENSE_PLATE2 --NULL
	--		WHEN LEN(TGR.LICENSE_PLATE1)=4
	--			THEN TGR.LICENSE_PLATE1
	--		WHEN LEN(TGR.LICENSE_PLATE2)=4
	--			THEN TGR.LICENSE_PLATE2
	--		ELSE TGR.LICENSE_PLATE1
	--	END

	SELECT LICENSE_PLATE,MAX(TIME_STAMP) AS TIME_STAMP
	INTO #BT_TAGREAD_LATESTTIME
	FROM(
			SELECT TGR.LICENSE_PLATE1 AS LICENSE_PLATE,TIME_STAMP
			FROM #TAGTMP TGR
			--WHERE TGR.LICENSE_PLATE1<>'0000000000' 
			--AND TGR.LICENSE_PLATE1<>'999999999' 
			--AND LICENSE_PLATE1 LIKE '0%' 
			--AND LEN(TGR.LICENSE_PLATE1)=10
			UNION
			SELECT TGR.LICENSE_PLATE2 AS LICENSE_PLATE,TIME_STAMP
			FROM #TAGTMP TGR
			--WHERE  TGR.LICENSE_PLATE2<>'0000000000' 
			--AND TGR.LICENSE_PLATE2<>'999999999' 
			--AND LICENSE_PLATE2 LIKE '0%' 
			--AND LEN(TGR.LICENSE_PLATE2)=10
		 ) ALLTAG
	GROUP BY LICENSE_PLATE

	SELECT GID,TRLT.LICENSE_PLATE, LOCATION, TRLT.TIME_STAMP
	FROM #TAGTMP TGR,#BT_TAGREAD_LATESTTIME TRLT
	WHERE TGR.LICENSE_PLATE1=TRLT.LICENSE_PLATE
		AND TGR.TIME_STAMP=TRLT.TIME_STAMP
	UNION
	SELECT GID,TRLT.LICENSE_PLATE, LOCATION, TRLT.TIME_STAMP
	FROM #TAGTMP TGR,#BT_TAGREAD_LATESTTIME TRLT
	WHERE TGR.LICENSE_PLATE2=TRLT.LICENSE_PLATE
		AND TGR.TIME_STAMP=TRLT.TIME_STAMP
END