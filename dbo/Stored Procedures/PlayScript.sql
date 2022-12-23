	CREATE PROCEDURE  dbo.PlayScript (
			@playlist_ smallint, 
			@test_ smallint
	)
	AS BEGIN                                        
	   SET NOCOUNT ON;
		DECLARE @cmd nvarchar(max), @id int;
	
		DECLARE @t1 DATETIME;
		DECLARE @t2 DATETIME;
	
		DECLARE @i INT;
		SELECT @i = COUNT(*) FROM dbo.CmdArray as ff WHERE [_KitNumber] = @playlist_;
		DECLARE @cnt INT = @i/100;
	
		DECLARE cur CURSOR FOR 
		SELECT [_Id],[_Cmd] FROM dbo.CmdArray as ff WHERE [_KitNumber] = @playlist_ ORDER BY [_ID] ASC
		OPEN cur;
		fetch next from cur into @id,@cmd;	
    
		WHILE @@FETCH_STATUS = 0 BEGIN
	
			SET @t1 = GETDATE();
			SET @t2 = GETDATE();
	
			PRINT @cmd;
	       IF (@test_= 2) BEGIN
	           EXEC(@cmd);
	       END
	       IF (@test_= 1) BEGIN
	           SET @cmd = 'BEGIN TRAN;'+CHAR(13)+CHAR(10)+ @cmd + CHAR(13)+CHAR(10)+'ROLLBACK TRAN;'+CHAR(13)+CHAR(10);
	           EXEC(@cmd);
	       END
	       IF (@test_= 0) BEGIN
	           SET @cmd = 'BEGIN TRAN;'+CHAR(13)+CHAR(10)+ @cmd + CHAR(13)+CHAR(10)+'COMMIT TRAN;'+CHAR(13)+CHAR(10);
	           EXEC(@cmd);
	       END
	       IF (@test_= -1) BEGIN
			    PRINT @i;
	       END
			SET @i = @i - 1;
	
			SET @t2 = GETDATE();
	
			PRINT 'Осталось '+CONVERT(nvarchar(10),@i) + ' из '+CONVERT(nvarchar(10),@cnt);
			UPDATE dbo.CmdArray SET _TotalExec = _TotalExec + 1, _Elapsed_ms = DATEDIFF(millisecond,@t1,@t2) WHERE _Id = @id;
	
			fetch next from cur into @id,@cmd;
		END;
	
		CLOSE cur;
		DEALLOCATE cur;
	END
