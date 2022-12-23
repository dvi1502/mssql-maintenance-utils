
CREATE PROCEDURE [dbo].[BULKSHRINKDB]  
	@groupid int
	
AS
BEGIN

	DECLARE @dbname VARCHAR(50) -- database name  
	DECLARE @cmd VARCHAR(1024) -- database name  
 
	--DECLARE db_cursor CURSOR READ_ONLY FOR  
	--	SELECT name 
	--	FROM master.dbo.sysdatabases 
	--	WHERE name NOT IN ('master','model','msdb','tempdb')  -- exclude these databases
	--	WHERE name NOT IN ('master','msdb')  -- exclude these databases
 
	DECLARE db_cursor CURSOR READ_ONLY FOR  
		SELECT [name] FROM [dbo].[serviced_databases] WHERE [GroupId] = @groupid 


	OPEN db_cursor   
	FETCH NEXT FROM db_cursor INTO @dbname   
 
	WHILE @@FETCH_STATUS = 0   
	BEGIN   
		
		set @cmd = 'DBCC SHRINKDATABASE(N'''+@dbname+''', 10, TRUNCATEONLY)';
		exec(@cmd);
		print @cmd;


	--проверка целостности БД
	--DBCC CHECKDB(N'ReportServer$SQL2008R2') WITH NO_INFOMSGS

	
	--Задача "Обновление статистики"
	--UPDATE STATISTICS tablename WITH FULLSCAN --обновить статистику
	
	--перестройка индекса
	--ALTER INDEX [PK_ActiveSubscriptions] ON [dbo].[ActiveSubscriptions] REBUILD PARTITION = ALL WITH ( PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, ONLINE = OFF, SORT_IN_TEMPDB = OFF )

	--Задача "Очистка журнала"


	-- Задача "Реорганизация индекса"
	--ALTER INDEX [PK_ActiveSubscriptions] ON [dbo].[ActiveSubscriptions] REORGANIZE WITH ( LOB_COMPACTION = ON )

	--Очистка процедурного кэша СУБД 
	--DBCC FREEPROCCACHE

	   FETCH NEXT FROM db_cursor INTO @dbname   
	END   
 
	CLOSE db_cursor   
	DEALLOCATE db_cursor

END

