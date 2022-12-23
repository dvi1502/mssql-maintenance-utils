CREATE TABLE [dbo].[backup_list] (
    [id]          INT            IDENTITY (1, 1) NOT NULL,
    [databaseid]  INT            NULL,
    [backupdate]  DATETIME       DEFAULT (getdate()) NOT NULL,
    [backupdrive] VARCHAR (2048) NOT NULL,
    [backupfile]  VARCHAR (2048) NOT NULL,
    PRIMARY KEY CLUSTERED ([id] ASC)
);

