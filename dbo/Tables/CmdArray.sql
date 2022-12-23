CREATE TABLE [dbo].[CmdArray] (
    [_ID]         INT      IDENTITY (1, 1) NOT NULL,
    [_KitNumber]  SMALLINT NULL,
    [_Cmd]        TEXT     NULL,
    [_TotalExec]  INT      DEFAULT ((0)) NULL,
    [_Elapsed_ms] INT      DEFAULT ((0)) NULL,
    PRIMARY KEY CLUSTERED ([_ID] ASC)
);

