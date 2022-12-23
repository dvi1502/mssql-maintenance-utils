-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[ADD_ALL_DB_IN_GROUP]
	@group_id int
AS
BEGIN
	IF (NOT EXISTS (SELECT * FROM [dbo].[serviced_groups] WHERE [id]= @group_id))
	BEGIN
		INSERT INTO [dbo].[serviced_groups]
				   ([id]
				   ,[isActual]
				   ,[Name]
				   ,[Disc]
				   ,[NetPath]
				   ,[NetUser]
				   ,[NetPass])
			 VALUES
				   (@group_id
				   ,0
				   ,'BAcKuP any DB group #ID'+CONVERT(varchar,@group_id)
				   ,'J:'
				   ,'\\192.xxxxx\BackUpVSProduct'
				   ,'BackUpSQL'
				   ,'xxxxx')
		
	END

	IF (EXISTS (SELECT * FROM [dbo].[serviced_groups] WHERE [id]= @group_id))
	BEGIN
		DECLARE @name varchar(100);
		DECLARE db_cursor CURSOR READ_ONLY FOR  
			SELECT name 
			FROM master.dbo.sysdatabases 
			WHERE name NOT IN ('master','model','msdb','tempdb')  -- exclude these databases
 
		OPEN db_cursor   
		FETCH NEXT FROM db_cursor INTO @name;
 
		WHILE @@FETCH_STATUS = 0 BEGIN   

			IF (NOT EXISTS(select * from [dbo].[serviced_databases] where [name] = @name and [GroupId]= @group_id)) BEGIN
				INSERT INTO [dbo].[serviced_databases]
						   ([GroupId]
						   ,[Name]
						   ,[PathMask]
						   ,[FileMask])
				 VALUES
					   (@group_id
					   ,@name
					   ,'\{DBNAME}'
					   ,'\{DBNAME}-{YYYY}{MM}{DD}-{ISDIF}.bkp')
			END
			
			FETCH NEXT FROM db_cursor INTO @name;   
		END   
 
		CLOSE db_cursor   
		DEALLOCATE db_cursor

	END;

	SELECT 'UPDATE [dbo].[serviced_groups] SET [isActual] = 1,[Name]='''+[Name]+''',[Disc] = '''+Disc+''',[NetPath] = '''+NetPath+''',[NetUser] = '''+NetUser+''',[NetPass] = '''+NetPass+''' WHERE [id] = ' +convert(varchar,@group_id) FROM [dbo].[serviced_groups] WHERE [id] = @group_id
	UNION ALL
	SELECT '--------------------------------------------------------'
	UNION ALL
	SELECT 'UPDATE [dbo].[serviced_databases]  SET [Name] = '''+[Name]+''',[PathMask] = '''+PathMask+''',[FileMask] = '''+FileMask+''' WHERE [GroupId] = ' + convert(varchar,@group_id) FROM [dbo].[serviced_databases] WHERE [GroupId] = @group_id

END
