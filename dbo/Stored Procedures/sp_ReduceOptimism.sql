-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE sp_ReduceOptimism (
	@dbname varchar(30))
AS
BEGIN
	
	DECLARE @cmd nvarchar(max)

	SET @cmd = 'USE [master]
		ALTER DATABASE ['+@dbname+'] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
		ALTER DATABASE ['+@dbname+'] SET ALLOW_SNAPSHOT_ISOLATION OFF;
		ALTER DATABASE ['+@dbname+'] SET READ_COMMITTED_SNAPSHOT OFF;
		ALTER DATABASE ['+@dbname+'] SET MULTI_USER;';
	--PRINT @cmd

	EXEC(@cmd); 

	SELECT [name],snapshot_isolation_state_desc,is_read_committed_snapshot_on 
	FROM sys.databases

END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ReduceOptimism] TO [DAF277]
    AS [dbo];

