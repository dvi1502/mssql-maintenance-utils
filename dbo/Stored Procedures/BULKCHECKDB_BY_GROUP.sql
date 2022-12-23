CREATE PROCEDURE [dbo].[BULKCHECKDB_BY_GROUP]  
	@groupid int
AS
BEGIN

	DECLARE @dbname VARCHAR(50) -- database name  
	DECLARE @cmd VARCHAR(1024) -- database name  
 
	DECLARE db_cursor CURSOR READ_ONLY FOR  
		SELECT [name] FROM [dbo].[serviced_databases] WHERE [GroupId] = @groupid 

	OPEN db_cursor   
	FETCH NEXT FROM db_cursor INTO @dbname   
 
	WHILE @@FETCH_STATUS = 0   
	BEGIN   

		set @cmd = 'DBCC CHECKDB(N'''+@dbname+''') WITH NO_INFOMSGS';
		print @cmd;
		exec(@cmd);

		FETCH NEXT FROM db_cursor INTO @dbname   

	END   
 
	CLOSE db_cursor   
	DEALLOCATE db_cursor

END
