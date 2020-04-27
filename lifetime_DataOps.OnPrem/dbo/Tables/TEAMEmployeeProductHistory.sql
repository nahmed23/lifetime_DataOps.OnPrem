CREATE TABLE [dbo].[TEAMEmployeeProductHistory] (
    [MemberID]         INT      NOT NULL,
    [JoinDate]         DATETIME NULL,
    [InsertedDateTime] DATETIME CONSTRAINT [DF_TEAMEmployeeProductHistory_InsertedDateTime] DEFAULT (getdate()) NULL
);

