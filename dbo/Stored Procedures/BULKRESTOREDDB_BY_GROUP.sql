
CREATE PROCEDURE [dbo].[BULKRESTOREDDB_BY_GROUP]
	@groupid int,
	@show bit = 0

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE 
		@cmd varchar(max),
		@Disc varchar(256),
		@NetPath varchar(256),
		@NetUser varchar(256),
		@NetPass varchar(256),
		@backupfile VARCHAR(max),
		@destdb VARCHAR(max)

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
		
	IF @show = 0 EXEC (@cmd) ELSE PRINT (@cmd) ;

	DECLARE db_cursor CURSOR READ_ONLY FOR  
	SELECT backupfile,NetPath,COALESCE(NetUser,''),COALESCE(NetPass,''),[copydb] destdb,Disc
	FROM [dbo].[backup_list] bl
	INNER JOIN (
	SELECT l.databaseid, MAX(backupdate) backupdate
	  FROM [dbo].[backup_list] l
	  WHERE backupfile like '%full%'
	GROUP BY l.databaseid
	) l
		ON bl.databaseid = l.databaseid AND bl.backupdate = l.backupdate
	INNER JOIN [dbo].[serviced_databases] db
		ON bl.databaseid = db.id
	INNER JOIN [dbo].[serviced_groups] gdb
		ON db.GroupId = gdb.id and isActual=1
	INNER JOIN [dbo].[restored_databases] rdb
		ON db.id = rdb.[databaseid]

	OPEN db_cursor   
	FETCH NEXT FROM db_cursor INTO @backupfile,@NetPath,@NetUser,@NetPass,@destdb,@Disc  
 
	WHILE @@FETCH_STATUS = 0 BEGIN   
	
		SET @cmd ='EXEC xp_cmdshell ''net use ' + @Disc + ' ' + @NetPath + ' ' + @NetUser + ' /PERSISTENT:NO''';
		IF @show = 0 EXEC (@cmd) ELSE PRINT (@cmd);
		
		BEGIN TRY
			DECLARE @ExecuteRestoreImmediately VARCHAR(50);

			IF (@show = 0)  SET @ExecuteRestoreImmediately = '@ExecuteRestoreImmediately = N''Y'',' 
			ELSE SET @ExecuteRestoreImmediately = ''
			
			IF DB_ID(@destdb) IS NULL BEGIN
				SET @cmd ='CREATE DATABASE ' + @destdb + '';
				IF @show = 0 EXEC (@cmd) ELSE PRINT (@cmd);
			END

			SET @cmd = 'EXECUTE [dbo].[RestoreDatabase_SQL2008] 
				@BackupFile = N'''+@backupfile+''',
				@NewDatabaseName = N'''+@destdb+''',' +
				@ExecuteRestoreImmediately +
				'@AdditionalOptions=N''STATS=5, REPLACE'''

			IF @show = 0 EXEC (@cmd) ELSE PRINT (@cmd);

		END TRY

		BEGIN CATCH
			INSERT INTO dbo.BackupError (db, msg, cmd) VALUES (@destdb, ERROR_MESSAGE(),@cmd)
		END CATCH

		IF @NetPath IS NOT NULL BEGIN
			SET @cmd = 'EXEC xp_cmdshell ''net use '+ @Disc+' /delete ''';
			IF @show = 0 EXEC (@cmd) ELSE PRINT (@cmd) ;
		END
			
		FETCH NEXT FROM db_cursor INTO @backupfile,@NetPath,@NetUser,@NetPass,@destdb,@Disc  
	      
	END   
 
	CLOSE db_cursor   
	DEALLOCATE db_cursor


END


