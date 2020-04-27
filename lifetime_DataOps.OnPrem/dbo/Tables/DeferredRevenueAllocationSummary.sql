CREATE TABLE [dbo].[DeferredRevenueAllocationSummary] (
    [DeferredRevenueAllocationSummaryID]       INT             IDENTITY (1, 1) NOT NULL,
    [MMSClubID]                                INT             NULL,
    [RevenueAllocationProductGroupDescription] VARCHAR (50)    NULL,
    [ProductID]                                INT             NULL,
    [MMSPostMonth]                             CHAR (10)       NULL,
    [GLRevenueAccount]                         CHAR (5)        NULL,
    [GLRevenueSubAccount]                      CHAR (11)       NULL,
    [GLRevenueMonth]                           CHAR (10)       NULL,
    [RevenueMonthAllocation]                   DECIMAL (10, 2) NULL,
    [TransactionType]                          VARCHAR (25)    NULL,
    [ProductDepartmentID]                      INT             NULL,
    [InsertedDateTime]                         DATETIME        CONSTRAINT [DF_DeferredRevenueAllocationSummary_inserteddatetime] DEFAULT (getdate()) NULL,
    [Quantity]                                 INT             NULL,
    [RevenueMonthQuantityAllocation]           DECIMAL (12, 4) NULL,
    [RevenueMonthDiscountAllocation]           DECIMAL (10, 2) NULL,
    [RefundGLAccountNumber]                    VARCHAR (5)     NULL,
    [DiscountGLAccount]                        VARCHAR (5)     NULL,
    CONSTRAINT [PK_DeferredRevenueAllocationSummary] PRIMARY KEY CLUSTERED ([DeferredRevenueAllocationSummaryID] ASC)
);

