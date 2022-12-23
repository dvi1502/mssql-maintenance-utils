


CREATE PROCEDURE [dbo].[BULKBACKUPDB]  
	@Disc varchar(256) = 'J:',
	@NetPath varchar(256) = '\\192.xxxxx\BackUpVSProduct',
	@NetUser varchar(256) = 'BackUpSQL',
	@NetPass varchar(256) = 'xxxxx',
	@isDif bit = 0
AS
BEGIN
	
	DECLARE @cmd varchar(max);

	-- To allow advanced options to be changed.
	EXEC ('EXEC sp_configure ''show advanced options'', 1')
	
	-- To update the currently configured value for advanced options.
	EXEC ('RECONFIGURE')
	
	-- To enable the feature.
	EXEC ('EXEC sp_configure ''xp_cmdshell'', 1')
	
	-- To update the currently configured value for this feature.
	EXEC ('RECONFIGURE')

	-- Connecting NAS Drive
	SET @cmd ='EXEC xp_cmdshell ''net use ' + @Disc + ' ' + @NetPath + ' /USER:'+@NetUser+' '+@NetPass+' /PERSISTENT:NO''';
	EXEC (@cmd) ;
	PRINT (@cmd) ;

	DECLARE @name VARCHAR(50) -- database name  
	--DECLARE @path VARCHAR(256) -- path for backup files  
	DECLARE @fileName VARCHAR(256) -- filename for backup  
	DECLARE @fileDate VARCHAR(20) -- used for file name
 
	-- specify filename format
	SELECT @fileDate = CONVERT(VARCHAR(20),GETDATE(),112) +'_'+ CONVERT(VARCHAR(2), DATEPART(HOUR,GETDATE()));
 
	DECLARE db_cursor CURSOR READ_ONLY FOR  
		SELECT name 
		FROM master.dbo.sysdatabases 
	--	WHERE name NOT IN ('master','model','msdb','tempdb')  -- exclude these databases
		WHERE name IN ('ReportServer$SQL2008R2','ReportServer$SQL2008R2TempDB','utils_vs')  -- exclude these databases
 

	OPEN db_cursor   
	FETCH NEXT FROM db_cursor INTO @name   
 
	WHILE @@FETCH_STATUS = 0   
	BEGIN   
		SET @fileName = @Disc +'\';
		SET @fileName = REPLACE( @fileName,'\\','\');

	   IF @isDif = 1 BEGIN 
			SET @fileName = @fileName + @name + '_dif_' + @fileDate + '.BAK'  
			SET @cmd = 'BACKUP DATABASE '+@name+' TO DISK = '''+@fileName+''' WITH DIFFERENTIAL,COMPRESSION';
			print @cmd;
			EXEC (@cmd) ;
	   END ELSE BEGIN
			SET @fileName = @fileName + @name+'_full_' + @fileDate + '.BAK'  
			SET @cmd = 'BACKUP DATABASE '+@name+' TO DISK = '''+@fileName+''' WITH COMPRESSION';
			print @cmd;
			EXEC (@cmd) ;
	   END;
	
	   FETCH NEXT FROM db_cursor INTO @name   
	END   
 
	CLOSE db_cursor   
	DEALLOCATE db_cursor

	SET @cmd = 'EXEC xp_cmdshell ''net use '+ @Disc+' /delete ''';
	EXEC(@cmd);


END
