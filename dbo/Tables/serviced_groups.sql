CREATE TABLE [dbo].[serviced_groups] (
    [id]       INT            NOT NULL,
    [isActual] SMALLINT       NULL,
    [Name]     VARCHAR (2048) NULL,
    [Disc]     VARCHAR (256)  NULL,
    [NetPath]  VARCHAR (256)  NULL,
    [NetUser]  VARCHAR (256)  NULL,
    [NetPass]  VARCHAR (256)  NULL,
    PRIMARY KEY CLUSTERED ([id] ASC)
);

