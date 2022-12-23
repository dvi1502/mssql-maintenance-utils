CREATE PROCEDURE [dbo].[ALTER_INDEX_FOR_DB] 
	@dbname NVARCHAR(MAX),
    @IsOnline BIT = 0,
	@Fragmentation smallint = 30,
	@Show BIT = 0
AS
BEGIN

	DECLARE @SQL NVARCHAR(MAX)

	if object_id('tempdb..#alidx') is not null drop table #alidx;

	CREATE TABLE #alidx (
				[schema_name] varchar(256),
				obj_name varchar(256),
				idx_name varchar(256),
				avg_fragmentation_in_percent int,
				EditionID int,
				cmd varchar(max)
	)

	SELECT @SQL = '	
	DECLARE @IsDetailedScan BIT 
	SET @IsDetailedScan = 0;

	INSERT INTO #alidx ([schema_name],obj_name,idx_name,avg_fragmentation_in_percent,EditionID)
	SELECT 
	  SCHEMA_NAME(o.[schema_id]),o.name, i.name , s.avg_fragmentation_in_percent,CONVERT(int,SERVERPROPERTY(''EditionID'')) EditionID
	FROM (
		SELECT 
			  s.[object_id]
			, s.index_id
			, avg_fragmentation_in_percent = MAX(s.avg_fragmentation_in_percent)
		FROM ['+@dbname+'].sys.dm_db_index_physical_stats(DB_ID('''+@dbname+'''), NULL, NULL, NULL, 
								CASE WHEN @IsDetailedScan = 1 
									THEN ''DETAILED'' ELSE ''LIMITED''
								END) s
		WHERE s.page_count > 128 -- > 1 MB
			AND s.index_id > 0 -- <> HEAP
			AND s.avg_fragmentation_in_percent > 5
		GROUP BY s.[object_id], s.index_id
	) s
	JOIN ['+@dbname+'].sys.indexes i ON s.[object_id] = i.[object_id] AND s.index_id = i.index_id
	JOIN ['+@dbname+'].sys.objects o ON o.[object_id] = s.[object_id]	'

	--PRINT(@SQL);
	EXEC (@SQL);

	UPDATE #alidx
	SET cmd = 'ALTER INDEX [' + idx_name + N'] ON [' + [schema_name] + '].[' + obj_name + '] ' +
		CASE WHEN avg_fragmentation_in_percent > @Fragmentation
			THEN 'REBUILD WITH (SORT_IN_TEMPDB = ON'
				-- Enterprise, Developer
				+ CASE WHEN EditionID IN (1804890536, -2117995310) AND @IsOnline = 1
						THEN ', ONLINE = ON'
						ELSE ''
				  END + ')'
			ELSE 'REORGANIZE'
		END + ';
	'

	DECLARE cur CURSOR LOCAL READ_ONLY FORWARD_ONLY FOR
		SELECT cmd FROM #alidx

	OPEN cur

	FETCH NEXT FROM cur INTO @SQL

	WHILE @@FETCH_STATUS = 0 BEGIN

		BEGIN TRY

			IF @Show = 1 BEGIN
				PRINT @SQL;
			END ELSE BEGIN
				EXEC sys.sp_executesql @SQL;
			END

		END TRY

		BEGIN CATCH
			INSERT INTO dbo.BackupError (db, msg, cmd) VALUES (@dbname, ERROR_MESSAGE(),@sql)
		END CATCH

		FETCH NEXT FROM cur INTO @SQL
	
	END 

	CLOSE cur 
	DEALLOCATE cur 

END
