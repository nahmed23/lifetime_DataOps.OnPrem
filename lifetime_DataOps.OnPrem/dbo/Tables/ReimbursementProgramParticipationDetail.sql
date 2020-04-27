CREATE TABLE [dbo].[ReimbursementProgramParticipationDetail] (
    [ReimbursementProgramID]       INT            NULL,
    [ReimbursementProgramName]     VARCHAR (50)   NULL,
    [MembershipID]                 INT            NULL,
    [MemberCount]                  INT            NULL,
    [AccessMembershipFlag]         BIT            NULL,
    [DuesPrice]                    MONEY          NULL,
    [SalesTaxPercentage]           DECIMAL (4, 2) NULL,
    [MembershipExpirationDate]     DATETIME       NULL,
    [ValTerminationReasonID]       INT            NULL,
    [ValPreSaleID]                 INT            NULL,
    [ValMembershipStatusID]        INT            NULL,
    [MembershipProductDescription] VARCHAR (50)   NULL,
    [InsertedDate]                 DATETIME       NULL,
    [MonthYear]                    VARCHAR (15)   NULL,
    [YearMonth]                    VARCHAR (6)    NULL
);


GO
CREATE NONCLUSTERED INDEX [IX_ReimbursementProgramID]
    ON [dbo].[ReimbursementProgramParticipationDetail]([ReimbursementProgramID] ASC) WITH (FILLFACTOR = 70);


GO
CREATE NONCLUSTERED INDEX [IX_ReimbursementProgramName]
    ON [dbo].[ReimbursementProgramParticipationDetail]([ReimbursementProgramName] ASC) WITH (FILLFACTOR = 70);


GO
CREATE NONCLUSTERED INDEX [IX_MembershipID]
    ON [dbo].[ReimbursementProgramParticipationDetail]([MembershipID] ASC) WITH (FILLFACTOR = 70);


GO
CREATE NONCLUSTERED INDEX [IX_MonthYear]
    ON [dbo].[ReimbursementProgramParticipationDetail]([MonthYear] ASC) WITH (FILLFACTOR = 70);


GO
CREATE NONCLUSTERED INDEX [IX_YearMonth]
    ON [dbo].[ReimbursementProgramParticipationDetail]([YearMonth] ASC) WITH (FILLFACTOR = 70);

