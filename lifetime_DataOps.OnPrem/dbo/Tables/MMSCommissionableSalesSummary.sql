CREATE TABLE [dbo].[MMSCommissionableSalesSummary] (
    [MMSCommissionableSalesSummaryID] INT          IDENTITY (1, 1) NOT NULL,
    [ClubID]                          INT          NULL,
    [ClubName]                        VARCHAR (50) NULL,
    [SalesPersonFirstName]            VARCHAR (50) NULL,
    [SalesPersonLastName]             VARCHAR (50) NULL,
    [SalesEmployeeID]                 INT          NULL,
    [ReceiptNumber]                   VARCHAR (50) NULL,
    [MemberID]                        INT          NULL,
    [MemberFirstName]                 VARCHAR (50) NULL,
    [MemberLastName]                  VARCHAR (50) NULL,
    [CorporateCode]                   VARCHAR (50) NULL,
    [MembershipTypeID]                INT          NULL,
    [MembershipTypeDescription]       VARCHAR (50) NULL,
    [ItemAmount]                      MONEY        NULL,
    [Quantity]                        INT          NULL,
    [CommissionCount]                 INT          NULL,
    [PostDateTime]                    DATETIME     NULL,
    [UTCPostDateTime]                 DATETIME     NULL,
    [TranItemID]                      INT          NULL,
    [ValRegionID]                     INT          NULL,
    [RegionDescription]               VARCHAR (50) NULL,
    [DepartmentID]                    INT          NULL,
    [DeptDescription]                 VARCHAR (50) NULL,
    [ProductID]                       INT          NULL,
    [ProductDescription]              VARCHAR (50) NULL,
    [InsertedDateTime]                DATETIME     CONSTRAINT [DF_MMSCommissionableSalesSummary_InsertedDateTime] DEFAULT (getdate()) NULL,
    [AdvisorID]                       INT          NULL,
    [AdvisorFirstName]                VARCHAR (50) NULL,
    [AdvisorLastName]                 VARCHAR (50) NULL,
    [ItemDiscountAmount]              MONEY        NULL,
    CONSTRAINT [PK_MMSCommissionableSalesSummary] PRIMARY KEY NONCLUSTERED ([MMSCommissionableSalesSummaryID] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IX_ClubName]
    ON [dbo].[MMSCommissionableSalesSummary]([ClubName] ASC);


GO
CREATE NONCLUSTERED INDEX [IX_PostDateTime]
    ON [dbo].[MMSCommissionableSalesSummary]([PostDateTime] ASC);


GO
CREATE NONCLUSTERED INDEX [IX_TranItemID]
    ON [dbo].[MMSCommissionableSalesSummary]([TranItemID] ASC);

