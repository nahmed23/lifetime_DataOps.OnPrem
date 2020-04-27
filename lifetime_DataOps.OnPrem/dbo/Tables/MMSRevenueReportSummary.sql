﻿CREATE TABLE [dbo].[MMSRevenueReportSummary] (
    [MMSRevenueReportSummaryID] BIGINT       IDENTITY (1, 1) NOT NULL,
    [PostingClubName]           VARCHAR (50) NULL,
    [ItemAmount]                MONEY        NULL,
    [DeptDescription]           VARCHAR (50) NULL,
    [ProductDescription]        VARCHAR (50) NULL,
    [MembershipClubname]        VARCHAR (50) NULL,
    [PostingClubid]             INT          NULL,
    [DrawerActivityID]          INT          NULL,
    [PostDateTime]              DATETIME     NULL,
    [TranDate]                  DATETIME     NULL,
    [TranTypeDescription]       VARCHAR (50) NULL,
    [ValTranTypeID]             INT          NULL,
    [MemberID]                  INT          NULL,
    [ItemSalesTax]              MONEY        NULL,
    [EmployeeID]                INT          NULL,
    [PostingRegionDescription]  VARCHAR (50) NULL,
    [MemberFirstname]           VARCHAR (50) NULL,
    [MemberLastname]            VARCHAR (50) NULL,
    [EmployeeFirstname]         VARCHAR (50) NULL,
    [EmployeeLastname]          VARCHAR (50) NULL,
    [ReasonCodeDescription]     VARCHAR (50) NULL,
    [TranItemID]                INT          NULL,
    [TranMemberJoinDate]        DATETIME     NULL,
    [MembershipID]              INT          NULL,
    [ProductID]                 INT          NULL,
    [TranClubid]                INT          NULL,
    [Quantity]                  INT          NULL,
    [InsertedDateTime]          DATETIME     CONSTRAINT [DF_MMSRevenueReportSummary_InsertedDateTime] DEFAULT (getdate()) NULL,
    [DepartmentID]              INT          DEFAULT (0) NOT NULL,
    [ItemDiscountAmount]        MONEY        NULL,
    [DiscountAmount1]           MONEY        NULL,
    [DiscountAmount2]           MONEY        NULL,
    [DiscountAmount3]           MONEY        NULL,
    [DiscountAmount4]           MONEY        NULL,
    [DiscountAmount5]           MONEY        NULL,
    [Discount1]                 VARCHAR (50) NULL,
    [Discount2]                 VARCHAR (50) NULL,
    [Discount3]                 VARCHAR (50) NULL,
    [Discount4]                 VARCHAR (50) NULL,
    [Discount5]                 VARCHAR (50) NULL,
    [LocalCurrencyCode]         VARCHAR (15) NULL,
    CONSTRAINT [PK_MMSRevenueReportSummary] PRIMARY KEY NONCLUSTERED ([MMSRevenueReportSummaryID] ASC) WITH (FILLFACTOR = 70)
);

