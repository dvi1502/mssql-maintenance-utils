CREATE TABLE [dbo].[BackupError] (
    [id]  INT            IDENTITY (1, 1) NOT NULL,
    [db]  [sysname]      NOT NULL,
    [dt]  DATETIME       DEFAULT (getdate()) NOT NULL,
    [msg] NVARCHAR (MAX) NULL,
    [cmd] NVARCHAR (MAX) NULL,
    PRIMARY KEY CLUSTERED ([id] ASC)
);

