﻿CREATE TABLE [dbo].[MMSRevenueGLPostingSummary_int_pk] (
    [MMSRevenueGLPostingSummaryID]                 INT             IDENTITY (1, 1) NOT NULL,
    [MMSRegion]                                    VARCHAR (50)    NULL,
    [ClubName]                                     VARCHAR (50)    NULL,
    [MMSClubCode]                                  VARCHAR (3)     NULL,
    [LocalCurrencyItemAmount]                      DECIMAL (16, 6) NULL,
    [USDItemAmount]                                DECIMAL (16, 6) NULL,
    [LocalCurrencyItemDiscountAmount]              DECIMAL (16, 6) NULL,
    [USDItemDiscountAmount]                        DECIMAL (16, 6) NULL,
    [LocalCurrencyGLPostingAmount]                 DECIMAL (16, 6) NULL,
    [USDGLPostingAmount]                           DECIMAL (16, 6) NULL,
    [DepartmentID]                                 INT             NULL,
    [DeptDescription]                              VARCHAR (50)    NULL,
    [ProductDescription]                           VARCHAR (50)    NULL,
    [MembershipClubName]                           VARCHAR (50)    NULL,
    [DrawerActivityID]                             INT             NULL,
    [PostDateTime]                                 DATETIME        NULL,
    [TranDate]                                     DATETIME        NULL,
    [ValTranTypeID]                                INT             NULL,
    [MemberID]                                     INT             NULL,
    [LocalCurrencyItemSalesTax]                    DECIMAL (16, 6) NULL,
    [USDItemSalesTax]                              DECIMAL (16, 6) NULL,
    [EmployeeID]                                   INT             NULL,
    [MemberFirstName]                              VARCHAR (50)    NULL,
    [MemberLastName]                               VARCHAR (50)    NULL,
    [TranItemId]                                   INT             NULL,
    [TranMemberJoinDate]                           DATETIME        NULL,
    [MembershipActivationDate]                     DATETIME        NULL,
    [MembershipID]                                 INT             NULL,
    [ValGLGroupID]                                 INT             NULL,
    [GLAccountNumber]                              VARCHAR (10)    NULL,
    [GLSubAccountNumber]                           VARCHAR (10)    NULL,
    [GLOverRideClubID]                             INT             NULL,
    [ProductID]                                    INT             NULL,
    [GLGroupIDDescription]                         VARCHAR (50)    NULL,
    [GLTaxID]                                      INT             NULL,
    [Posting_GLClubID]                             INT             NULL,
    [Posting_RegionDescription]                    VARCHAR (50)    NULL,
    [Posting_ClubName]                             VARCHAR (50)    NULL,
    [MMSTranClubID]                                INT             NULL,
    [Posting_MMSClubID]                            INT             NULL,
    [CurrencyCode]                                 VARCHAR (3)     NULL,
    [MonthlyAverageExchangeRate]                   DECIMAL (14, 4) NULL,
    [EmployeeFirstName]                            VARCHAR (50)    NULL,
    [EmployeeLastName]                             VARCHAR (50)    NULL,
    [TransactionDescrption]                        VARCHAR (50)    NULL,
    [TranTypeDescription]                          VARCHAR (50)    NULL,
    [Reconciliation_Adj_ValGroupID_Desc]           VARCHAR (8000)  NULL,
    [LocalCurrencyReconciliation_Sales]            DECIMAL (16, 6) NULL,
    [USDReconciliation_Sales]                      DECIMAL (16, 6) NULL,
    [LocalCurrencyReconciliation_Adjustment]       DECIMAL (16, 6) NULL,
    [USDReconciliation_Adjustment]                 DECIMAL (16, 6) NULL,
    [LocalCurrencyReconciliation_Refund]           DECIMAL (16, 6) NULL,
    [USDReconciliation_Refund]                     DECIMAL (16, 6) NULL,
    [LocalCurrencyReconciliation_DuesAssessCharge] DECIMAL (16, 6) NULL,
    [USDReconciliation_DuesAssessCharge]           DECIMAL (16, 6) NULL,
    [LocalCurrencyReconciliation_AllOtherCharges]  DECIMAL (16, 6) NULL,
    [USDReconciliation_AllOtherCharges]            DECIMAL (16, 6) NULL,
    [Reconciliation_ReportMonthYear]               VARCHAR (20)    NULL,
    [Reconciliation_Posting_Sub_Account]           VARCHAR (20)    NULL,
    [Reconciliation_ReportHeader_TranType]         VARCHAR (50)    NULL,
    [Reconciliation_ReportLineGrouping]            VARCHAR (8000)  NULL,
    [Reconciliation_Adj_GLAccountNumber]           VARCHAR (10)    NULL,
    [PostingInstruction]                           VARCHAR (102)   NULL,
    [ItemQuantity]                                 INT             NULL,
    [InsertedDateTime]                             DATETIME        DEFAULT (getdate()) NULL,
    [WorkdayAccount]                               VARCHAR (10)    NULL,
    [WorkdayCostCenter]                            VARCHAR (6)     NULL,
    [WorkdayOffering]                              VARCHAR (10)    NULL,
    [WorkdayRegion]                                VARCHAR (4)     NULL,
    [WorkdayOverRideRegion]                        VARCHAR (4)     NULL,
    [DeferredRevenueFlag]                          CHAR (1)        NULL,
    [Reconciliation_Adj_WorkdayAccount]            VARCHAR (10)    NULL,
    [Reconciliation_PostingWorkdayRegion]          VARCHAR (4)     NULL,
    [Reconciliation_PostingWorkdayCostCenter]      VARCHAR (6)     NULL,
    [Reconciliation_PostingWorkdayOffering]        VARCHAR (10)    NULL,
    [Reconciliation_WorkdayReportLineGrouping]     VARCHAR (222)   NULL,
    [RevenueCategory]                              VARCHAR (7)     NULL,
    [SpendCategory]                                VARCHAR (7)     NULL,
    [PayComponent]                                 VARCHAR (50)    NULL,
    CONSTRAINT [PK_MMSRevenueGLPostingSummary_int_pk] PRIMARY KEY NONCLUSTERED ([MMSRevenueGLPostingSummaryID] ASC) WITH (FILLFACTOR = 70)
);

