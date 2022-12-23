USE [msdb]
GO

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Full bakup', 
		@enabled=1, 
		@notify_level_eventlog=2, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'KXLBASA-XX\DVI', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

/****** Object:  Step [Групповое полное резервное копирование ГРУППА 1]    Script Date: 07.11.2020 14:07:18 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Групповое полное резервное копирование ГРУППА 1', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @RC int
DECLARE @groupid int
DECLARE @isDif bit
select @groupid =1, @isDif = 0

EXECUTE @RC = [utils_vs].[dbo].[BULKBACKUPDB_BY_GROUP] 
   @groupid, @isDif 
', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Групповое полное резервное копирование ГРУППА 4]    Script Date: 07.11.2020 14:07:18 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Групповое полное резервное копирование ГРУППА 4', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @RC int
DECLARE @groupid int
DECLARE @isDif bit
select @groupid =4, @isDif = 0

EXECUTE @RC = [utils_vs].[dbo].[BULKBACKUPDB_BY_GROUP] 
   @groupid, @isDif ', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Очистка процедурного кеша]    Script Date: 07.11.2020 14:07:18 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Очистка процедурного кеша', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'-- Очистка процедурного кеша   
DBCC FREEPROCCACHE   
', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Реорганизация индексов выборочно]    Script Date: 07.11.2020 14:07:18 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Реорганизация индексов выборочно', 
		@step_id=4, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @RC int
DECLARE @groupid int
DECLARE @dbname nvarchar(max)
DECLARE @IsOnline bit;
DECLARE @Show bit;
DECLARE @Fragmentation int = 100;
SELECT  @groupid = 1, @IsOnline=0, @Fragmentation =100, @Show =0;

DECLARE db_cursor CURSOR READ_ONLY FOR  
	SELECT [name]  FROM [utils_vs].[dbo].[serviced_databases] WHERE [GroupId] = @groupid 

OPEN db_cursor   
FETCH NEXT FROM db_cursor INTO  @dbname 
 
WHILE @@FETCH_STATUS = 0 BEGIN   

	EXECUTE @RC = [utils_vs].[dbo].[ALTER_INDEX_FOR_DB]   @dbname ,@IsOnline ,@Fragmentation ,@Show;
		  
	FETCH NEXT FROM db_cursor INTO @dbname;
	      
END   
 
CLOSE db_cursor   
DEALLOCATE db_cursor', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Реорганизация статистики]    Script Date: 07.11.2020 14:07:18 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Реорганизация статистики', 
		@step_id=5, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @RC int
DECLARE @groupid int
DECLARE @dbname nvarchar(max)
DECLARE @IsOnline bit;
DECLARE @Show bit;
DECLARE @Fragmentation int = 100;
SELECT  @groupid = 1, @IsOnline=0, @Fragmentation =100, @Show =0;

DECLARE db_cursor CURSOR READ_ONLY FOR  
	SELECT [name]  FROM [utils_vs].[dbo].[serviced_databases] WHERE [GroupId] = @groupid 

OPEN db_cursor   
FETCH NEXT FROM db_cursor INTO  @dbname 
 
WHILE @@FETCH_STATUS = 0 BEGIN   

	EXECUTE @RC = [utils_vs].[dbo].[UPDATE_STATISTICS_FOR_DB]  @dbname,@Show;

	FETCH NEXT FROM db_cursor INTO @dbname;
	      
END   
 
CLOSE db_cursor   
DEALLOCATE db_cursor

', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Полное резервное копирование СУТОЧНОЕ', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20201107, 
		@active_end_date=99991231, 
		@active_start_time=1000, 
		@active_end_time=235959, 
		@schedule_uid=N'c9a0bd65-4b0d-453f-826e-468cb50aae8e'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION

GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

