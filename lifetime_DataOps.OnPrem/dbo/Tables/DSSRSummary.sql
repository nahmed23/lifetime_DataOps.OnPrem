CREATE TABLE [dbo].[DSSRSummary] (
    [DSSRSummary]                 INT          IDENTITY (1, 1) NOT NULL,
    [MembershipID]                INT          NULL,
    [PostDateTime]                DATETIME     NULL,
    [MemberID]                    INT          NULL,
    [TranClubID]                  INT          NULL,
    [TranClubName]                VARCHAR (50) NULL,
    [ProductDescription]          VARCHAR (50) NULL,
    [MembershipTypeDescription]   VARCHAR (50) NULL,
    [MembershipSizeDescription]   VARCHAR (50) NULL,
    [PrimaryMemberFirstName]      VARCHAR (50) NULL,
    [MembershipClubID]            INT          NULL,
    [MembershipClubName]          VARCHAR (50) NULL,
    [CreatedDateTime]             DATETIME     NULL,
    [PrimaryMemberLastName]       VARCHAR (50) NULL,
    [AdvisorFirstName]            VARCHAR (50) NULL,
    [AdvisorLastName]             VARCHAR (50) NULL,
    [ItemAmount]                  MONEY        NULL,
    [ProductID]                   INT          NULL,
    [JoinDate]                    DATETIME     NULL,
    [CommissionCount]             INT          NULL,
    [CommEmployeeFirstName]       VARCHAR (50) NULL,
    [TranVoidedID]                INT          NULL,
    [CommEmployeeLastName]        VARCHAR (50) NULL,
    [CompanyID]                   INT          NULL,
    [Quantity]                    INT          NULL,
    [ExpirationDate]              DATETIME     NULL,
    [MMSTranID]                   INT          NULL,
    [TermReasonDescription]       VARCHAR (50) NULL,
    [CancellationRequestDate]     DATETIME     NULL,
    [InsertedDateTime]            DATETIME     CONSTRAINT [DF_DSSRSummary_ReportDate] DEFAULT (getdate()) NULL,
    [CommEmployeeID]              INT          NULL,
    [SaleDeptRoleFlag]            BIT          NULL,
    [AdvisorEmployeeID]           INT          NULL,
    [TranTypeDescription]         VARCHAR (50) NULL,
    [TranReasonDescription]       VARCHAR (50) NULL,
    [CorporateAccountRepInitials] VARCHAR (5)  NULL,
    [CorpAccountRepType]          VARCHAR (50) NULL,
    [CorporateCode]               VARCHAR (50) NULL,
    [Post_Today_Flag]             BIT          NULL,
    [Join_Today_Flag]             BIT          NULL,
    [Expire_Today_Flag]           BIT          NULL,
    [Email_OnFile_Flag]           BIT          NULL,
    CONSTRAINT [PK_MembershipClubName] PRIMARY KEY NONCLUSTERED ([DSSRSummary] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IX_TranClubID]
    ON [dbo].[DSSRSummary]([TranClubID] ASC);


GO
CREATE NONCLUSTERED INDEX [IX_PostDateTime]
    ON [dbo].[DSSRSummary]([PostDateTime] ASC);


GO
CREATE NONCLUSTERED INDEX [IX_ExpirationDate]
    ON [dbo].[DSSRSummary]([ExpirationDate] ASC);


GO
CREATE NONCLUSTERED INDEX [IX_JoinDate]
    ON [dbo].[DSSRSummary]([JoinDate] ASC);


GO
CREATE NONCLUSTERED INDEX [IX_MembershipTypeDescription]
    ON [dbo].[DSSRSummary]([MembershipTypeDescription] ASC);


GO
CREATE NONCLUSTERED INDEX [IX_ProductDescription]
    ON [dbo].[DSSRSummary]([ProductDescription] ASC);


GO
CREATE NONCLUSTERED INDEX [IX_MemebrshipID]
    ON [dbo].[DSSRSummary]([MembershipID] ASC);

