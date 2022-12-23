



CREATE PROCEDURE [dbo].[RotationBACKUPDB_BY_GROUP]  
	@groupid int,
	@isDif bit = 0,
	@show bit = 0
AS
BEGIN

	DECLARE 
		@cmd varchar(max),
		@Disc varchar(256),
		@NetPath varchar(256),
		@NetUser varchar(256),
		@NetPass varchar(256),
		@strDif varchar(10)

	DECLARE @dbname VARCHAR(50) -- database name  
	DECLARE @dbid int -- database id
	DECLARE @pathmask VARCHAR(2048) -- database path  
	DECLARE @filemask VARCHAR(2048) -- database path  
	DECLARE @dbpath VARCHAR(2048) -- database path  
	DECLARE @dbfile VARCHAR(2048) -- database path  
	DECLARE @fileName VARCHAR(2048) -- database path  
	DECLARE @dt datetime;
	DECLARE @everyDaySaveFile int;
	DECLARE @everyWeekSaveFile int;


	SELECT 
		@Disc=Disc,@NetPath=NetPath,@NetUser=COALESCE(NetUser,''),@NetPass=COALESCE(NetPass,''),
		@strDif = CASE WHEN @isDif = 1 THEN 'dif' ELSE 'full' END
	FROM [dbo].[serviced_groups] WHERE id = @groupid

	IF @NetPath IS NOT NULL BEGIN
	
		-- To allow advanced options to be changed.
		IF @show = 0 
		EXEC ('EXEC sp_configure ''show advanced options'', 1')
		ELSE PRINT 'EXEC sp_configure ''show advanced options'', 1'
		
		-- To update the currently configured value for advanced options.
		IF @show = 0 
		EXEC ('RECONFIGURE')
		ELSE PRINT 'RECONFIGURE'
		
		-- To enable the feature.
		IF @show = 0 
		EXEC ('EXEC sp_configure ''xp_cmdshell'', 1')
		ELSE PRINT 'EXEC sp_configure ''xp_cmdshell'', 1'
		
		-- To update the currently configured value for this feature.
		IF @show = 0 
		EXEC ('RECONFIGURE')
		ELSE PRINT 'RECONFIGURE'

		-- Connecting NAS Drive
		SET @cmd ='EXEC xp_cmdshell ''net use ' + @Disc + ' ' + @NetPath + ' ' + @NetUser + ' /PERSISTENT:NO''';
		
		IF @show = 0 EXEC (@cmd) ELSE PRINT (@cmd) ;
	
	END
 
 
-- build calendar >>
	declare 
		@dt_start datetime, @dt_finish datetime,
		@qdt_start datetime, @qdt_finish datetime,
		@wdt_start datetime, @wdt_finish datetime,
		@d datetime;

	select	@dt_start = CONVERT(datetime,CONVERT(int,DATEADD(YEAR,-1,getdate()))), 
			@dt_finish = CONVERT(datetime,CONVERT(int,getdate())),
			@d = getdate()
			--,@wdt_finish = CONVERT(datetime,CONVERT(int,DATEADD(d,@everyDaySaveFile,@d))) -- ежеденевный
			--,@wdt_start = DATEADD(SECOND,24*60*60-1,CONVERT(datetime,CONVERT(int,DATEADD(d ,@everyWeekSaveFile,@d)))); --еженедельный
			;
---------------------------------------------------------------------------------------------------------------------
--                           @wdt_start                                  @wdt_finish                   @d      
-----------------------------0-------------------------------------------0-----------------------------0-------------> t
--   только  ежемесячный    / \        только еженедельные              / \          ежедневные       /
---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------


	if OBJECT_ID ('tempdb..#calendar') is not null drop table #calendar;
	create table #calendar (dt datetime);
		
	with cte
	as (
		select @dt_start dt
		union all
		select dateadd( d, 1, dt ) 
			from cte
			where dt < @dt_finish
	)
	insert into #calendar (dt)
	select dt 
	from cte
	option (maxrecursion 1000)

-- build calendar <<

 
	DECLARE db_cursor CURSOR READ_ONLY FOR  
		SELECT [id], [name], [pathmask], [filemask], [EveryDaySaveFile], [EveryWeekSaveFile] 
		FROM [dbo].[serviced_databases] 
		WHERE [GroupId] = @groupid 

	OPEN db_cursor   
	
	FETCH NEXT FROM db_cursor INTO @dbid, @dbname, @pathmask, @filemask,@everyDaySaveFile,@everyWeekSaveFile  
 
	WHILE @@FETCH_STATUS = 0 BEGIN   
		SET @everyDaySaveFile = -1*ABS(@everyDaySaveFile);
		SET @everyWeekSaveFile = -1*ABS(@everyWeekSaveFile);
		SET @wdt_finish = CONVERT(datetime,CONVERT(int,DATEADD(d,@everyDaySaveFile,@d))); -- ежеденевный
		SET @wdt_start = DATEADD(SECOND,24*60*60-1,CONVERT(datetime,CONVERT(int,DATEADD(d ,@everyWeekSaveFile,@d)))); --еженедельный
		
		print @dbname
		print @wdt_start
		print @wdt_finish

		print @everyDaySaveFile
		print @everyWeekSaveFile

		DECLARE dt_cursor CURSOR READ_ONLY FOR  

				SELECT DISTINCT dbpath,dbfile,dt FROM (
				
				SELECT dt,
					dbo.MASKPROCESSOR(@Disc+'\'+@pathmask,dt,@dbname,@strDif) dbpath,
					dbo.MASKPROCESSOR(@filemask,dt,@dbname,@strDif) dbfile
				FROM #calendar
				WHERE 
					dt not in (
						SELECT dt
						FROM #calendar
						WHERE datediff( d, 0, dt ) % 7 = 6
						and dt between @wdt_start and @wdt_finish
					)
					and dt between @wdt_start and @wdt_finish
					and DATEPART(day,dt) <> 1 

				UNION ALL
				SELECT dt,
					dbo.MASKPROCESSOR(@Disc+'\'+@pathmask,dt,@dbname,@strDif),
					dbo.MASKPROCESSOR(@filemask,dt,@dbname,@strDif)
				FROM #calendar
				WHERE 
					dt not in (
						SELECT * 
						FROM #calendar
						WHERE DATEPART(day,dt) = 1
							and dt < @wdt_start
					)
					and dt < @wdt_start
				) D	ORDER BY dt	DESC			

		OPEN dt_cursor   
		FETCH NEXT FROM dt_cursor INTO @dbpath,@dbfile,@dt
	 
		WHILE @@FETCH_STATUS = 0 BEGIN   

			SET @fileName = REPLACE(@dbpath+'\'+@dbfile,'\\','\'); 
			SET @fileName = REPLACE(@fileName,'\\','\'); 
			
			SET @cmd = 'EXEC xp_cmdshell ''if exist '+@fileName+' del /Q /F '+@fileName+'''';

			BEGIN TRY
				IF @show = 0 BEGIN EXEC (@cmd) END ELSE PRINT (@cmd);
			END TRY

			BEGIN CATCH
				INSERT INTO dbo.BackupError (db, msg, cmd) VALUES (@dbname, ERROR_MESSAGE(),@cmd)
			END CATCH

			FETCH NEXT FROM dt_cursor INTO @dbpath,@dbfile,@dt
	      
		END   
 
		CLOSE dt_cursor   
		DEALLOCATE dt_cursor
			
		FETCH NEXT FROM db_cursor INTO @dbid, @dbname, @pathmask, @filemask,@everyDaySaveFile,@everyWeekSaveFile  
	      
	END   
 
	CLOSE db_cursor   
	DEALLOCATE db_cursor

	IF @NetPath IS NOT NULL BEGIN
		SET @cmd = 'EXEC xp_cmdshell ''net use '+ @Disc+' /delete ''';
		IF @show = 0 EXEC (@cmd) ELSE PRINT (@cmd) ;
	END

END



