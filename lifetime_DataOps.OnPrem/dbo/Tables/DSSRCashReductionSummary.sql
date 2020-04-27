CREATE TABLE [dbo].[DSSRCashReductionSummary] (
    [DSSRCashReductionSummaryID] INT          IDENTITY (1, 1) NOT NULL,
    [ClubID]                     INT          NULL,
    [ClubName]                   VARCHAR (50) NULL,
    [MembershipID]               INT          NULL,
    [EventDate]                  DATETIME     NULL,
    [EventDescription]           VARCHAR (50) NULL,
    [Today_Flag]                 BIT          NULL,
    [EventTranItemID]            INT          NULL,
    [EventItemAmount]            MONEY        NULL,
    [MMSTranID]                  INT          NULL,
    [MemberID]                   INT          NULL,
    [TranReasonDescription]      VARCHAR (50) NULL,
    [JoinDate]                   DATETIME     NULL,
    [PostDateTime]               DATETIME     NULL,
    [CommEmplFirstName]          VARCHAR (50) NULL,
    [CommEmplLastName]           VARCHAR (50) NULL,
    [ProductDescription]         VARCHAR (50) NULL,
    [CommissionCount]            INT          NULL,
    [TranItemID]                 INT          NULL,
    [ItemAmount]                 MONEY        NULL,
    [PrimaryFirstName]           VARCHAR (50) NULL,
    [PrimaryLastName]            VARCHAR (50) NULL,
    [TranType]                   VARCHAR (50) NULL,
    [CommEmployeeID]             INT          NULL,
    [InsertedDateTime]           DATETIME     CONSTRAINT [DF_DSSRDowngradeCancellationIFAddOnTransSummary_InsertedDateTime] DEFAULT (getdate()) NULL,
    CONSTRAINT [PK_DSSRDowngradeCancellationIFAddOnTransSummary] PRIMARY KEY NONCLUSTERED ([DSSRCashReductionSummaryID] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IX_ClubID]
    ON [dbo].[DSSRCashReductionSummary]([ClubID] ASC);

