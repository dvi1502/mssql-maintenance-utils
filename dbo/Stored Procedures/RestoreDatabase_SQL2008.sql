

 

CREATE PROCEDURE [dbo].[RestoreDatabase_SQL2008]
      @BackupFile nvarchar(260),
      @NewDatabaseName sysname = NULL,
      @FileNumber int = 1,
      @DataFolder nvarchar(260) = NULL,
      @LogFolder nvarchar(260) = NULL,
      @ExecuteRestoreImmediately char(1) = 'N',
      @ChangePhysicalFileNames char(1) = 'Y',
      @ChangeLogicalNames char(1) = 'Y',
      @DatabaseOwner sysname = NULL,
      @AdditionalOptions nvarchar(500) = NULL

AS
 
/*

This procedure will generate and optionally execute a RESTORE DATABASE
script from the specified disk database backup file.

Parameters:

      @BackupFile: Required. Specifies fully-qualified path to the disk
            backup file. For remote (network) files, UNC path should
            be specified.  The SQL Server service account will need
            permissions to the file.

      @NewDatabaseName: Optional. Specifies the target database name
            for the restore.  If not specified, the database is
            restored using the original database name.

      @FileNumber: Optional. Specifies the file number of the desired
            backup set. This is needed only when when the backup file
            contains multiple backup sets. If not specified, a
            default of 1 is used.

      @DataFolder: Optional. Specifies the folder for all database data
            files. If not specified, data files are restored using the
            original file names and locations.

      @LogFolder: Optional. Specifies the folder for all database log
            files. If not specified, log files are restored to the
            original log file locations.

      @ExecuteRestoreImmediately: Optional. Specifies whether or not to
            execute the restore. When, 'Y' is specified, then restore is
            executed immediately.  When 'Y' is specified, the restore script
            is printed but not executed. If not specified, a default of 'N'
            is used.

      @ChangePhysicalFileNames: Optional. Indicates that physical file
            names are to be renamed during the restore to match the
            new database name. When 'Y' is specified, the leftmost
            part of the original file name matching the original
            database name is replaced with the new database name. The
            file name is not changed when 'N' is specified or if the
            leftmost part of the file name doesn't match the original
            database name. If not specified, a default of 'Y' is used.

      @ChangeLogicalNames: Optional. Indicates that logical file names
            are to be renamed following the restore to match the new
            database name. When 'Y' is specified, the leftmost part
            of the original file name matching the original database
            name is replaced with the new database name. The file name
            is not changed when 'N' is specified or if the leftmost
            part of the file name doesn't match the original database
            name. If not specified, a default of 'Y' is used.

      @DatabaseOwner: Optional. Specifies the new database owner
            (authorization) of the restored database.  If not specified, the
            database will be owned by the accunt used to restore the database.

      @AdditionalOptions:  Optional.  Specifies options to be added the the
            RESTORE statement WITH clause (e.g. STATS=5, REPLACE).  If not
            specified, only the FILE and MOVE are included.

Sample usages:
      --restore database with same name and file locations
      EXEC #RestoreDatabase_SQL2008
            @BackupFile = N'C:\Backups\Foo.bak',
            @AdditionalOptions=N'STATS=5, REPLACE';

      Results:
      --Backup source: ServerName=MYSERVER, DatabaseName=Foo, BackupFinishDate=2009-06-13 11:20:52.000

      RESTORE DATABASE [MyDatabase]
            FROM DISK=N'C:\Backups\Foo.bak'
            WITH
                  FILE=1, STATS=5, REPLACE

      --restore database with new name and change logical and physical names
      EXEC #RestoreDatabase_SQL2008
            @BackupFile = N'C:\Backups\Foo.bak',
            @NewDatabaseName = 'Foo2';

      Results:
      --Backup source: ServerName=MYSERVER, DatabaseName=Foo, BackupFinishDate=2009-06-13 11:20:52.000
      RESTORE DATABASE [Foo2]
            FROM DISK=N'C:\Backups\Foo.bak'
            WITH
                  FILE=1,
                        MOVE 'Foo' TO 'C:\DataFolder\Foo2.mdf',
                        MOVE 'Foo_log' TO 'D:\LogFolder\Foo2_log.LDF'
      ALTER DATABASE [Foo2]
                        MODIFY FILE (NAME='Foo', NEWNAME='Foo2');
      ALTER DATABASE [Foo2]
                        MODIFY FILE (NAME='Foo_log', NEWNAME='Foo2_log');

      --restore database to different file folders and change owner after restore:
      EXEC #RestoreDatabase_SQL2008
            @BackupFile = N'C:\Backups\Foo.bak',
            @DataFolder = N'E:\DataFiles',
            @LogFolder = N'F:\LogFiles',
            @DatabaseOwner = 'sa',
            @AdditionalOptions=N'STATS=5;

      Results:
      --Backup source: ServerName=MYSERVER, DatabaseName=Foo, BackupFinishDate=2009-06-13 11:20:52.000
      RESTORE DATABASE [Foo]
            FROM DISK=N'C:\Backups\Foo.bak'
            WITH
                  FILE=1,
                        MOVE 'Foo' TO 'E:\DataFiles\Foo.mdf',
                        MOVE 'Foo_log' TO 'F:\LogFiles\Foo_log.LDF'
      ALTER AUTHORIZATION ON DATABASE::[Foo] TO [sa]

*/

SET NOCOUNT ON;

DECLARE @LogicalName nvarchar(128),
      @PhysicalName nvarchar(260),
      @PhysicalFolderName nvarchar(260),
      @PhysicalFileName nvarchar(260),
      @NewPhysicalName nvarchar(260),
      @NewLogicalName nvarchar(128),
      @OldDatabaseName nvarchar(128),
      @RestoreStatement nvarchar(MAX),
      @Command nvarchar(MAX),
      @ReturnCode int,
      @FileType char(1),
      @ServerName nvarchar(128),
      @BackupFinishDate datetime,
      @Message nvarchar(4000),
      @ChangeLogicalNamesSql nvarchar(MAX),
      @AlterAuthorizationSql nvarchar(MAX),
      @Error int;
	   

DECLARE @BackupHeader TABLE (
      BackupName nvarchar(128) NULL,
      BackupDescription  nvarchar(255) NULL,
      BackupType smallint NULL,
      ExpirationDate datetime NULL,
      Compressed tinyint NULL,
      Position smallint NULL,
      DeviceType tinyint NULL,
      UserName nvarchar(128) NULL,
      ServerName nvarchar(128) NULL,
      DatabaseName nvarchar(128) NULL,
      DatabaseVersion int NULL,
      DatabaseCreationDate  datetime NULL,
      BackupSize numeric(20,0) NULL,
      FirstLSN numeric(25,0) NULL,
      LastLSN numeric(25,0) NULL,
      CheckpointLSN  numeric(25,0) NULL,
      DatabaseBackupLSN  numeric(25,0) NULL,
      BackupStartDate  datetime NULL,
      BackupFinishDate  datetime NULL,
      SortOrder smallint NULL,
      CodePage smallint NULL,
      UnicodeLocaleId int NULL,
      UnicodeComparisonStyle int NULL,
      CompatibilityLevel  tinyint NULL,
      SoftwareVendorId int NULL,
      SoftwareVersionMajor int NULL,
      SoftwareVersionMinor int NULL,
      SoftwareVersionBuild int NULL,
      MachineName nvarchar(128) NULL,
      Flags int NULL,
      BindingID uniqueidentifier NULL,
      RecoveryForkID uniqueidentifier NULL,
      Collation nvarchar(128) NULL,
      FamilyGUID uniqueidentifier NULL,
      HasBulkLoggedData bit NULL,
      IsSnapshot bit NULL,
      IsReadOnly bit NULL,
      IsSingleUser bit NULL,
      HasBackupChecksums bit NULL,
      IsDamaged bit NULL,
      BeginsLogChain bit NULL,
      HasIncompleteMetaData bit NULL,
      IsForceOffline bit NULL,
      IsCopyOnly bit NULL,
      FirstRecoveryForkID uniqueidentifier NULL,
      ForkPointLSN decimal(25, 0) NULL,
      RecoveryModel nvarchar(60) NULL,
      DifferentialBaseLSN decimal(25, 0) NULL,
      DifferentialBaseGUID uniqueidentifier NULL,
      BackupTypeDescription  nvarchar(60) NULL,
      BackupSetGUID uniqueidentifier NULL,
      CompressedBackupSize binary(8) NULL,
		Containment tinyint not NULL,
		KeyAlgorithm nvarchar(32),
		EncryptorThumbprint varbinary(20),
		EncryptorType nvarchar(32)
	);

 

DECLARE @FileList TABLE(
      LogicalName nvarchar(128) NOT NULL,
      PhysicalName nvarchar(260) NOT NULL,
      Type char(1) NOT NULL,
      FileGroupName nvarchar(120) NULL,
      Size numeric(20, 0) NOT NULL,
      MaxSize numeric(20, 0) NOT NULL,
      FileID bigint NULL,
      CreateLSN numeric(25,0) NULL,
      DropLSN numeric(25,0) NULL,
      UniqueID uniqueidentifier NULL,
      ReadOnlyLSN numeric(25,0) NULL ,
      ReadWriteLSN numeric(25,0) NULL,
      BackupSizeInBytes bigint NULL,
      SourceBlockSize int NULL,
      FileGroupID int NULL,
      LogGroupGUID uniqueidentifier NULL,
      DifferentialBaseLSN numeric(25,0)NULL,
      DifferentialBaseGUID uniqueidentifier NULL,
      IsReadOnly bit NULL,
      IsPresent bit NULL,
      TDEThumbprint varbinary(32) NULL,
		SnapshotURL	nvarchar(360) NULL
);

SET @Error = 0;

DECLARE @SingleUser nvarchar(max);
DECLARE @MultiUser nvarchar(max);

SET @SingleUser = 'ALTER DATABASE '+QUOTENAME(@NewDatabaseName)+' SET SINGLE_USER WITH ROLLBACK IMMEDIATE ';
SET @MultiUser  = 'ALTER DATABASE '+QUOTENAME(@NewDatabaseName)+' SET MULTI_USER ';


--add trailing backslash to folder names if not already specified
IF LEFT(REVERSE(@DataFolder), 1) <> '\' SET @DataFolder = @DataFolder + '\';
IF LEFT(REVERSE(@LogFolder), 1) <> '\' SET @LogFolder = @LogFolder + '\';

-- get backup header info and display
SET @RestoreStatement = N'RESTORE HEADERONLY
     FROM DISK=N''' + @BackupFile + ''' WITH FILE=' + CAST(@FileNumber as nvarchar(10));

INSERT INTO @BackupHeader 
      EXEC('RESTORE HEADERONLY FROM DISK=N''' + @BackupFile + ''' WITH FILE = 1');

SET @Error = @@ERROR;
IF @Error <> 0 GOTO Done;
IF NOT EXISTS(SELECT * FROM @BackupHeader) GOTO Done;
SELECT
      @OldDatabaseName = DatabaseName,
      @ServerName = ServerName,
      @BackupFinishDate = BackupFinishDate
FROM @BackupHeader;

IF @NewDatabaseName IS NULL SET @NewDatabaseName = @OldDatabaseName;

SET @Message = N'--Backup source: ServerName=%s, DatabaseName=%s, BackupFinishDate=' +
      CONVERT(nvarchar(23), @BackupFinishDate, 121);

RAISERROR(@Message, 0, 1, @ServerName, @OldDatabaseName) WITH NOWAIT;

 

-- get filelist info

SET @RestoreStatement = N'RESTORE FILELISTONLY
      FROM DISK=N''' + @BackupFile + ''' WITH FILE=' + CAST(@FileNumber as nvarchar(10))+CHAR(13)+CHAR(10);

INSERT INTO @FileList
      EXEC(@RestoreStatement);

SET @Error = @@ERROR;
IF @Error <> 0 GOTO Done;
IF NOT EXISTS(SELECT * FROM @FileList) GOTO Done;

-- generate RESTORE DATABASE statement and ALTER DATABASE statements
SET @ChangeLogicalNamesSql = '';
SET @RestoreStatement =
      N'RESTORE DATABASE ' +
      QUOTENAME(@NewDatabaseName) +
      N'
      FROM DISK=N''' +
      @BackupFile + '''' +
      N'
      WITH
            FILE=' +
      CAST(@FileNumber as nvarchar(10))+CHAR(13)+CHAR(10)

DECLARE FileList CURSOR LOCAL STATIC READ_ONLY FOR
      SELECT
            Type AS FileTyoe,
            LogicalName,
            --extract folder name from full path
            LEFT(PhysicalName,
                  LEN(LTRIM(RTRIM(PhysicalName))) -
                  CHARINDEX('\',
                  REVERSE(LTRIM(RTRIM(PhysicalName)))) + 1)
                  AS PhysicalFolderName,

            --extract file name from full path
            LTRIM(RTRIM(RIGHT(PhysicalName,
                  CHARINDEX('\',
                  REVERSE(PhysicalName)) - 1))) AS PhysicalFileName
FROM @FileList;

OPEN FileList;

WHILE 1 = 1 BEGIN
      FETCH NEXT FROM FileList INTO
            @FileType, @LogicalName, @PhysicalFolderName, @PhysicalFileName;

      IF @@FETCH_STATUS = -1 BREAK;

      -- build new physical name
      SET @NewPhysicalName =
            CASE @FileType
                  WHEN 'D' THEN
                        COALESCE(@DataFolder, @PhysicalFolderName) +
                        CASE
                              WHEN UPPER(@ChangePhysicalFileNames) IN ('Y', '1') AND
                                    LEFT(@PhysicalFileName, LEN(@OldDatabaseName)) = @OldDatabaseName
                              THEN
                                    @NewDatabaseName + RIGHT(@PhysicalFileName, LEN(@PhysicalFileName) - LEN(@OldDatabaseName))
                              ELSE
                                    @PhysicalFileName
                        END
                  WHEN 'L' THEN
                        COALESCE(@LogFolder, @PhysicalFolderName) +
                        CASE
                              WHEN UPPER(@ChangePhysicalFileNames) IN ('Y', '1') AND
                                    LEFT(@PhysicalFileName, LEN(@OldDatabaseName)) = @OldDatabaseName
                              THEN
                                    @NewDatabaseName + RIGHT(@PhysicalFileName, LEN(@PhysicalFileName) - LEN(@OldDatabaseName))
                              ELSE
                                    @PhysicalFileName
                        END
            END;

 

      -- build new logical name

      SET @NewLogicalName =
            CASE
                  WHEN UPPER(@ChangeLogicalNames) IN ('Y', '1') AND
                        LEFT(@LogicalName, LEN(@OldDatabaseName)) = @OldDatabaseName
                        THEN
                              @NewDatabaseName + RIGHT(@LogicalName, LEN(@LogicalName) - LEN(@OldDatabaseName))
                        ELSE
                              @LogicalName
            END;

           

      -- generate ALTER DATABASE...MODIFY FILE statement if logical file name is different
      IF @NewLogicalName <> @LogicalName
            SET @ChangeLogicalNamesSql = @ChangeLogicalNamesSql + N'ALTER DATABASE ' + QUOTENAME(@NewDatabaseName) + N'
                  MODIFY FILE (NAME=''' + @LogicalName + N''', NEWNAME=''' + @NewLogicalName + N''')'+CHAR(13)+CHAR(10);
 
      -- add MOVE option as needed if folder and/or file names are changed
      IF @PhysicalFolderName + @PhysicalFileName <> @NewPhysicalName
      BEGIN
            SET @RestoreStatement = @RestoreStatement +
                  N',
                  MOVE ''' +
                  @LogicalName +
                  N''' TO ''' +
                  @NewPhysicalName +
                  N''''+CHAR(13)+CHAR(10);
      END;

END;
CLOSE FileList;
DEALLOCATE FileList;

IF @AdditionalOptions IS NOT NULL
      SET @RestoreStatement =
            @RestoreStatement + N', ' + @AdditionalOptions

           
IF @DatabaseOwner IS NOT NULL
      SET @AlterAuthorizationSql = N'ALTER AUTHORIZATION ON DATABASE::' +
            QUOTENAME(@NewDatabaseName) + N' TO ' + QUOTENAME(@DatabaseOwner)
ELSE
      SET @AlterAuthorizationSql = N''
--execute RESTORE statement

IF UPPER(@ExecuteRestoreImmediately) IN ('Y', '1')
BEGIN
			 
      RAISERROR(N'Executing: %s', 0, 1, '') WITH NOWAIT
      EXEC (@SingleUser);
      SET @Error = @@ERROR;
      IF @Error <> 0 GOTO Done;

      RAISERROR(N'Executing: %s', 0, 1, @RestoreStatement) WITH NOWAIT
      EXEC (@RestoreStatement);
      SET @Error = @@ERROR;
      IF @Error <> 0 GOTO Done;

      --execute ALTER DATABASE statement(s)
      IF @ChangeLogicalNamesSql <> ''
      BEGIN
            RAISERROR(N'Executing: %s', 0, 1, @ChangeLogicalNamesSql) WITH NOWAIT
            EXEC (@ChangeLogicalNamesSql);
            SET @Error = @@ERROR;
            IF @Error <> 0 GOTO Done;
      END

      IF @AlterAuthorizationSql <> ''
      BEGIN
            RAISERROR(N'Executing: %s', 0, 1, @AlterAuthorizationSql) WITH NOWAIT
            EXEC (@AlterAuthorizationSql);
            SET @Error = @@ERROR;
            IF @Error <> 0 GOTO Done;
      END

      RAISERROR(N'Executing: %s', 0, 1, '') WITH NOWAIT
      EXEC (@MultiUser);
      SET @Error = @@ERROR;
      IF @Error <> 0 GOTO Done;

END

ELSE

BEGIN

      --RAISERROR(N'BEGIN TRY %s END TRY BEGIN CATCH INSERT INTO dbo.BackupError (db, msg, cmd) VALUES ('''',ERROR_MESSAGE(),''%s'') END CATCH', 0, 1, @SingleUser,@SingleUser) WITH NOWAIT
      --RAISERROR(N'BEGIN TRY %s END TRY BEGIN CATCH INSERT INTO dbo.BackupError (db, msg, cmd) VALUES ('''',ERROR_MESSAGE(),''%s'') END CATCH', 0, 1, @RestoreStatement,@RestoreStatement) WITH NOWAIT
      --IF @ChangeLogicalNamesSql <> ''
      --BEGIN
      --      RAISERROR(N'BEGIN TRY %s  END TRY BEGIN CATCH INSERT INTO dbo.BackupError (db, msg, cmd) VALUES ('''',ERROR_MESSAGE(),''%s'') END CATCH', 0, 1, @ChangeLogicalNamesSql,@ChangeLogicalNamesSql) WITH NOWAIT;
      --END
      --IF @AlterAuthorizationSql <> ''
      --BEGIN
      --      RAISERROR(N'BEGIN TRY %s END TRY BEGIN CATCH INSERT INTO dbo.BackupError (db, msg, cmd) VALUES ('''',ERROR_MESSAGE(),''%s'') END CATCH', 0, 1, @AlterAuthorizationSql,@AlterAuthorizationSql) WITH NOWAIT;
      --END
      --RAISERROR(N'BEGIN TRY %s END TRY BEGIN CATCH INSERT INTO dbo.BackupError (db, msg, cmd) VALUES ('''',ERROR_MESSAGE(),''%s'') END CATCH', 0, 1, @MultiUser,@MultiUser) WITH NOWAIT

      RAISERROR(N'%s', 0, 1, @SingleUser) WITH NOWAIT;
      RAISERROR(N'%s', 0, 1, @RestoreStatement) WITH NOWAIT;
      IF @ChangeLogicalNamesSql <> ''
      BEGIN
            RAISERROR(N'%s', 0, 1, @ChangeLogicalNamesSql) WITH NOWAIT;
      END
      IF @AlterAuthorizationSql <> ''
      BEGIN
            RAISERROR(N'%s', 0, 1, @AlterAuthorizationSql) WITH NOWAIT;
      END
      RAISERROR(N'%s', 0, 1, @MultiUser) WITH NOWAIT;

END;

 

Done:

 

RETURN @Error;

