CREATE TABLE [dbo].[serviced_databases] (
    [id]                INT            IDENTITY (1, 1) NOT NULL,
    [GroupId]           INT            NOT NULL,
    [Name]              VARCHAR (2048) NULL,
    [PathMask]          VARCHAR (2048) NULL,
    [FileMask]          VARCHAR (2048) NULL,
    [EveryDaySaveFile]  INT            NULL,
    [EveryWeekSaveFile] INT            NULL,
    PRIMARY KEY CLUSTERED ([id] ASC)
);

