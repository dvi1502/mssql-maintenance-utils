CREATE PROCEDURE [dbo].[UPDATE_STATISTICS_FOR_DB]
	@dbname NVARCHAR(MAX),
	@Show bit = 0
AS
BEGIN

	DECLARE @SQL NVARCHAR(MAX)

	if object_id('tempdb..#stats') is not null drop table #stats;

	CREATE TABLE #stats (
				[schema_name] varchar(256),
				obj_name varchar(256),
				sch_name varchar(256),
				no_recompute int,
				cmd varchar(max)
	)

	SET @SQL = 	'
		DECLARE @DateNow DATETIME
		SELECT @DateNow = DATEADD(dd, 0, DATEDIFF(dd, 0, GETDATE()))
	
		INSERT INTO #stats ([schema_name],obj_name,sch_name,no_recompute)
		SELECT SCHEMA_NAME(o.[schema_id]),o.name,s.name,s.no_recompute
		FROM (
			SELECT 
				  [object_id]
				, name
				, stats_id
				, no_recompute
				, last_update = STATS_DATE([object_id], stats_id)
			FROM ['+@dbname+'].sys.stats WITH(NOLOCK)
			WHERE auto_created = 0
				--AND is_temporary = 0 -- 2012+
		) s
		JOIN ['+@dbname+'].sys.objects o WITH(NOLOCK) ON s.[object_id] = o.[object_id]
		JOIN (
			SELECT
				  p.[object_id]
				, p.index_id
				, total_pages = SUM(a.total_pages)
			FROM ['+@dbname+'].sys.partitions p WITH(NOLOCK)
			JOIN ['+@dbname+'].sys.allocation_units a WITH(NOLOCK) ON p.[partition_id] = a.container_id
			GROUP BY 
				  p.[object_id]
				, p.index_id
		) p ON o.[object_id] = p.[object_id] AND p.index_id = s.stats_id
		WHERE o.[type] IN (''U'', ''V'')
			AND o.is_ms_shipped = 0
			AND (
				  last_update IS NULL AND p.total_pages > 0 -- never updated and contains rows
				OR
				  last_update <= DATEADD(dd, 
					CASE WHEN p.total_pages > 4096 -- > 4 MB
						THEN -2 -- updated 3 days ago
						ELSE 0 
					END, @DateNow)
			)'
	
	--PRINT(@SQL);
	EXEC (@SQL);

	UPDATE #stats 
	SET cmd = 'UPDATE STATISTICS ['+@dbname+'].[' + [schema_name] + '].[' + [obj_name] + '] [' + [sch_name] + ']
			WITH FULLSCAN' 
			--+ CASE WHEN no_recompute = 1 THEN ', NORECOMPUTE' ELSE '' END 
			+ ';'


	DECLARE cur CURSOR LOCAL READ_ONLY FORWARD_ONLY FOR
		SELECT cmd FROM #stats

	OPEN cur

	FETCH NEXT FROM cur INTO @SQL

	WHILE @@FETCH_STATUS = 0 BEGIN

		--print @SQL
		BEGIN TRY
			IF( @Show = 1 ) 
			BEGIN 
				print @SQL;
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
