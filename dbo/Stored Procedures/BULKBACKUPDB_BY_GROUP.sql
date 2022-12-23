CREATE PROCEDURE [dbo].[BULKBACKUPDB_BY_GROUP]  
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
		SET @cmd ='EXEC xp_cmdshell ''net use ' + @Disc + ' ' + @NetPath +' '+ @NetUser + ' /PERSISTENT:NO''';
		
		IF @show = 0 EXEC (@cmd) ELSE PRINT (@cmd) ;
	
	END
 
	DECLARE db_cursor CURSOR READ_ONLY FOR  
		SELECT [id], [name], [pathmask], [filemask] 
		FROM [dbo].[serviced_databases] 
		WHERE [GroupId] = @groupid 

	--	SELECT name 
	--	FROM master.dbo.sysdatabases 
	----	WHERE name NOT IN ('master','model','msdb','tempdb')  -- exclude these databases
	--	WHERE name IN ('ReportServer$SQL2008R2','ReportServer$SQL2008R2TempDB','utils_vs')  -- exclude these databases

	OPEN db_cursor   
	FETCH NEXT FROM db_cursor INTO @dbid, @dbname, @pathmask, @filemask  
 
	WHILE @@FETCH_STATUS = 0 BEGIN   
	
		print '--' + @dbname;
		IF DB_ID(@dbname) IS NOT NULL BEGIN

			SET @dbpath = dbo.MASKPROCESSOR(@Disc+'\'+@pathmask,GETDATE(),@dbname,@strDif);	
			SET @dbfile = dbo.MASKPROCESSOR(@filemask,GETDATE(),@dbname,@strDif);	
			
			SET @cmd = 'EXEC xp_cmdshell ''if not exist '+@dbpath+' mkdir '+@dbpath+'''';
			IF @show = 0 EXEC (@cmd) ELSE PRINT (@cmd);

			SET @fileName = REPLACE(@dbpath+'\'+@dbfile,'\\','\'); 
			
			IF @isDif = 1 BEGIN
				--SET @cmd = 'BACKUP DATABASE '+@dbname+' TO DISK = '''+@fileName+''' WITH DIFFERENTIAL,COMPRESSION,NOFORMAT,NOINIT,SKIP,CHECKSUM';
				SET @cmd = 'BACKUP DATABASE '+@dbname+' TO DISK = '''+@fileName+''' WITH DIFFERENTIAL, COMPRESSION;';
			END
			ELSE BEGIN
				--SET @cmd = 'BACKUP DATABASE '+@dbname+' TO DISK = '''+@fileName+''' WITH COMPRESSION,NOFORMAT,NOINIT,SKIP,CHECKSUM';
				SET @cmd = 'BACKUP DATABASE '+@dbname+' TO DISK = '''+@fileName+''' WITH COMPRESSION; ';
			END;

			BEGIN TRY
			
				IF @show = 0 BEGIN 
					
					EXEC (@cmd) 
					INSERT INTO [dbo].[backup_list]([databaseid],[backupdate],[backupdrive],[backupfile])VALUES(@dbid,getdate(),COALESCE(@NetPath,'(local)'),@fileName)
					
				END ELSE PRINT (@cmd);
				
			END TRY

			BEGIN CATCH
				INSERT INTO dbo.BackupError (db, msg, cmd) VALUES (@dbname, ERROR_MESSAGE(),@cmd)
			END CATCH
		END
			
		FETCH NEXT FROM db_cursor INTO @dbid, @dbname, @pathmask, @filemask  
	      
	END   
 
	CLOSE db_cursor   
	DEALLOCATE db_cursor

	IF @NetPath IS NOT NULL BEGIN
		SET @cmd = 'EXEC xp_cmdshell ''net use '+ @Disc+' /delete ''';
		IF @show = 0 EXEC (@cmd) ELSE PRINT (@cmd) ;
	END

END
