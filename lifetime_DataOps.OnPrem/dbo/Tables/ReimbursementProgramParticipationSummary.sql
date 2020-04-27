CREATE TABLE [dbo].[ReimbursementProgramParticipationSummary] (
    [ReimbursementProgramID]   INT          NULL,
    [ReimbursementProgramName] VARCHAR (50) NULL,
    [AccessMembershipCount]    INT          NULL,
    [InsertedDate]             DATETIME     NULL,
    [MonthYear]                VARCHAR (15) NULL,
    [YearMonth]                VARCHAR (6)  NULL
);


GO
CREATE NONCLUSTERED INDEX [IX_ReimbursementProgramID]
    ON [dbo].[ReimbursementProgramParticipationSummary]([ReimbursementProgramID] ASC) WITH (FILLFACTOR = 70);


GO
CREATE NONCLUSTERED INDEX [IX_ReimbursementProgramName]
    ON [dbo].[ReimbursementProgramParticipationSummary]([ReimbursementProgramName] ASC) WITH (FILLFACTOR = 70);


GO
CREATE NONCLUSTERED INDEX [IX_MonthYear]
    ON [dbo].[ReimbursementProgramParticipationSummary]([MonthYear] ASC) WITH (FILLFACTOR = 70);


GO
CREATE NONCLUSTERED INDEX [IX_YearMonth]
    ON [dbo].[ReimbursementProgramParticipationSummary]([YearMonth] ASC) WITH (FILLFACTOR = 70);

