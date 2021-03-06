USE [BHSDB]
GO
/****** Object:  UserDefinedFunction [dbo].[RPT_GETPARAMETERS]    Script Date: 26-Dec-13 11:02:43 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER FUNCTION [dbo].[RPT_GETPARAMETERS]
(
 @parameter varchar(max)
)
RETURNS 
@temp  TABLE 
(
	PAR NVARCHAR(50)
)
AS
BEGIN

/*
	DECLARE @d char(1)
	DECLARE @Start int
	DECLARE @End int
	SET @d = ',';

	WITH CSVCTE (StartPos, EndPos, Value) AS
	( SELECT 1 AS StartPos, CHARINDEX(@d , @Parameter + @d) AS EndPos,
		SUBSTRING(@Parameter,1,CHARINDEX(@d , @Parameter + @d)-1)
				 UNION ALL
	  SELECT EndPos + 1 AS StartPos , 
		CHARINDEX(@d,@Parameter + @d , EndPos + 1) AS EndPos,
		SUBSTRING(@Parameter,EndPos + 1, CHARINDEX(@d,@Parameter + @d , EndPos + 1)-(EndPos + 1))
	FROM CSVCTE WHERE CHARINDEX(@d, @Parameter + @d, EndPos + 1) <> 0)	      
	     
	 INSERT INTO @temp (PAR ) SELECT LTRIM(RTRIM(Value)) FROM CSVCTE
*/

DECLARE @d char(1)=','
set @Parameter= @Parameter +@d 
DECLARE @PLen int= len(@Parameter)
DECLARE @SIndex int=1
DECLARE @EIndex int= 0


	WHILE (@PLen > @EIndex)
	Begin
	SET @EIndex = CHARINDEX(@d , @Parameter)-1
	INSERT INTO @temp (PAR ) VALUES (LTRIM(RTRIM(SUBSTRING(@Parameter,@SIndex ,@EIndex))))
	SET @SIndex = CHARINDEX(@d , @Parameter)+1
	SET @Parameter =  SUBSTRING(@Parameter, @SIndex, @PLen )
	SET @SIndex = 1
	SET @EIndex = 0
	SET @PLen = LEN(@Parameter)
	End
	
	RETURN
END
