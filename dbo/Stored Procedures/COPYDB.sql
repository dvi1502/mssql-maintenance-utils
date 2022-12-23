CREATE PROCEDURE [dbo].[COPYDB] 
	@dbfrom varchar(100),
	@dbto varchar(100),
	@instdir varchar(1000) = 'D:\MSSQL\MSSQL13.WMS\MSSQL\'
AS
BEGIN

SET NOCOUNT ON; 

DECLARE @errorMessage nvarchar(4000), @errorSeverity int;
DECLARE @fileName nvarchar(1000), @namedata  nvarchar(1000), @namelog  nvarchar(1000),@ParmDefinition nvarchar(max), @CMD nvarchar(max);
DECLARE @msgTable TABLE  
    ( msg NVARCHAR(MAX) );  

	-- To allow advanced options to be changed.
	EXEC ('EXEC sp_configure ''show advanced options'', 1')
	
	-- To update the currently configured value for advanced options.
	EXEC ('RECONFIGURE')
	
	-- To enable the feature.
	EXEC ('EXEC sp_configure ''xp_cmdshell'', 1')
	
	-- To update the currently configured value for this feature.
	EXEC ('RECONFIGURE')

	BEGIN TRY
		SET @fileName = @instdir+'Backup\'+REPLACE(CONVERT(VARCHAR(36),NEWID()),'-','') + '_' + CONVERT(nvarchar,'20181204',20) + '.bak';
		SET @cmd = 'BACKUP DATABASE '+@dbfrom+' TO DISK = '''+@fileName+''' WITH COMPRESSION';
		print @CMD;
		insert into @msgTable(msg) values (@CMD);
		EXEC (@CMD);
	END TRY
	BEGIN CATCH
		SELECT @errorMessage = ERROR_MESSAGE(), @errorSeverity = ERROR_SEVERITY();
		insert into @msgTable(msg) values (@errorMessage);
		print @errorMessage;
	END CATCH


	BEGIN TRY
		SET @CMD = 'ALTER DATABASE '+@dbto+' SET SINGLE_USER WITH ROLLBACK IMMEDIATE';
		print @CMD;
		insert into @msgTable(msg) values (@CMD);
		EXEC (@CMD);
	END TRY
	BEGIN CATCH
		SELECT @errorMessage = ERROR_MESSAGE(), @errorSeverity = ERROR_SEVERITY();
		insert into @msgTable(msg) values (@errorMessage);
		print @errorMessage;
	END CATCH

	IF EXISTS(select name from sys.databases where name = @dbto) BEGIN
		BEGIN TRY
			SET @CMD = 'DROP DATABASE '+@dbto;
			print @CMD;
			insert into @msgTable(msg) values (@CMD);
			EXEC (@CMD);
		END TRY
		BEGIN CATCH
			SELECT @errorMessage = ERROR_MESSAGE(), @errorSeverity = ERROR_SEVERITY();
			insert into @msgTable(msg) values (@errorMessage);
			print @errorMessage;
		END CATCH
	END

	BEGIN TRY
		SET @CMD = 'CREATE DATABASE '+@dbto+ ' CONTAINMENT = NONE ON PRIMARY ( NAME = N'''+@dbto+''', FILENAME = N'''+@instdir+'Data\'+@dbto+'.mdf'' , SIZE = 8192KB , FILEGROWTH = 65536KB )
		LOG ON ( NAME = N'''+@dbto+'_log'', FILENAME = N'''+@instdir+'Data\'+@dbto+'_log.ldf'' , SIZE = 8192KB , FILEGROWTH = 65536KB )';
		print @CMD;
		insert into @msgTable(msg) values (@CMD);
		EXEC (@CMD);
	END TRY
	BEGIN CATCH
		SELECT @errorMessage = ERROR_MESSAGE(), @errorSeverity = ERROR_SEVERITY();
		insert into @msgTable(msg) values (@errorMessage);
		print @errorMessage;
	END CATCH

	BEGIN TRY
		SET @CMD = 'select @namedata = name from ['+@dbfrom+ '].sys.database_files where type_desc = ''ROWS''';
		SET @ParmDefinition = N' @namedata varchar(100) OUTPUT';  
		EXEC sp_executeSQL @CMD,@ParmDefinition, @namedata=@namedata OUTPUT;
		SET @CMD = 'select @namelog = name from ['+@dbfrom+ '].sys.database_files where type_desc = ''LOG''';
		SET @ParmDefinition = N' @namelog varchar(100) OUTPUT';
		insert into @msgTable(msg) values (@CMD);
		EXEC sp_executeSQL @CMD,@ParmDefinition, @namelog=@namelog OUTPUT;
	END TRY
	BEGIN CATCH
		SELECT @errorMessage = ERROR_MESSAGE(), @errorSeverity = ERROR_SEVERITY();
		insert into @msgTable(msg) values (@errorMessage);
		print @errorMessage;
	END CATCH


	BEGIN TRY
		SET @CMD = 'RESTORE DATABASE ['+@dbto+'] FROM  DISK = '''+@fileName+''' WITH RECOVERY,
		MOVE N'''+@namedata+''' TO N'''+@instdir+'Data\'+@dbto+'.mdf'',  
		MOVE N'''+@namelog+''' TO N'''+@instdir+'Data\'+@dbto+'_log.ldf'',  
		NOUNLOAD, REPLACE, STATS = 5';
		print @CMD;
		insert into @msgTable(msg) values (@CMD);
		EXEC (@CMD);
	END TRY
	BEGIN CATCH
		SELECT @errorMessage = ERROR_MESSAGE(), @errorSeverity = ERROR_SEVERITY();
		insert into @msgTable(msg) values (@errorMessage);
		print @errorMessage;
	END CATCH

	BEGIN TRY
		SET @CMD = 'ALTER DATABASE '+@dbto+' SET MULTI_USER ';
		print @CMD;
		insert into @msgTable(msg) values (@CMD);
		EXEC (@CMD);
	END TRY
	BEGIN CATCH
		SELECT @errorMessage = ERROR_MESSAGE(), @errorSeverity = ERROR_SEVERITY();
		insert into @msgTable(msg) values (@errorMessage);
		print @errorMessage;
	END CATCH

	SET @cmd = 'EXEC xp_cmdshell ''del '+@fileName+'''';
	print @CMD;
	EXEC(@cmd);

	SET NOCOUNT OFF; 
	select * from @msgTable;
	RETURN 1;
END
