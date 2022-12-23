CREATE FUNCTION [dbo].[MASKPROCESSOR] (
	@mask NVARCHAR(1024),
	@curdt DATETIME ,
	@dbname NVARCHAR(1024) = '',
	@dif NVARCHAR(1024) = ''
)
RETURNS VARCHAR(1024)
AS
BEGIN

	DECLARE @res NVARCHAR(1024);
	--DECLARE @curdt DATETIME;
	
	--SET @curdt = GETDATE();
	SET @res = REPLACE(@mask,'{DD}',  RIGHT('00'+CONVERT(varchar(2),DATEPART(DAY,@curdt)),2));
	SET @res = REPLACE(@res,'{MM}',   RIGHT('00'+CONVERT(varchar(2),DATEPART(MONTH,@curdt)),2));
	SET @res = REPLACE(@res,'{YYYY}', CONVERT(varchar(4),DATEPART(YEAR,@curdt)));
	SET @res = REPLACE(@res,'{YY}',   RIGHT(CONVERT(varchar(4),DATEPART(YEAR,@curdt)),2));
	SET @res = REPLACE(@res,'{HH}',   RIGHT('00'+CONVERT(varchar(2),DATEPART(HOUR,@curdt)),2));
	SET @res = REPLACE(@res,'{MI}',   RIGHT('00'+CONVERT(varchar(2),DATEPART(MI,@curdt)),2));
	SET @res = REPLACE(@res,'{WEEK}',   CONVERT(varchar(2),DATEPART(WEEK,@curdt)));
	SET @res = REPLACE(@res,'{WEEKDAY}',   CONVERT(varchar(2),DATEPART(WEEKDAY,@curdt)));
	SET @res = REPLACE(@res,'{DW}',   CONVERT(varchar(2),DATEPART(DW,@curdt)));
	SET @res = REPLACE(@res,'{DY}',   CONVERT(varchar(3),DATEPART(DY,@curdt)));
	SET @res = REPLACE(@res,'{QQ}',   CONVERT(varchar(3),DATEPART(QQ,@curdt)));
	SET @res = REPLACE(@res,'{DBNAME}', @dbname);
	SET @res = REPLACE(@res,'{ISDIF}',  @dif);

	-- Return the result of the function
	RETURN REPLACE( @res ,'\\','\');

END
