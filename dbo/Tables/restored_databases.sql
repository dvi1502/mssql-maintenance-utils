CREATE TABLE [dbo].[restored_databases] (
    [id]         INT          IDENTITY (1, 1) NOT NULL,
    [databaseid] INT          NULL,
    [copydb]     VARCHAR (50) NULL,
    PRIMARY KEY CLUSTERED ([id] ASC)
);

