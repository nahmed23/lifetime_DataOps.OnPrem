CREATE TABLE [dbo].[DelinquentMembershipBalance_BeginningOfMonth] (
    [DelinquencyDate]               DATETIME        NULL,
    [MembershipID]                  INT             NULL,
    [TranProductCategory]           VARCHAR (50)    NULL,
    [MembershipStatus]              VARCHAR (50)    NULL,
    [AmountDue]                     DECIMAL (12, 2) NULL,
    [EffectiveDate]                 DATETIME        NULL,
    [ExpirationDate]                DATETIME        NULL,
    [DelinquentMembershipAttribute] VARCHAR (50)    NULL,
    [TerminationReasonID]           INT             NULL
);

