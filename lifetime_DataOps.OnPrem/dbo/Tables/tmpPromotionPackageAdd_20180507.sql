﻿CREATE TABLE [dbo].[tmpPromotionPackageAdd_20180507] (
    [PromotionPackageAddID] INT            IDENTITY (1, 1) NOT NULL,
    [MemberID]              INT            NOT NULL,
    [ProductID]             INT            NULL,
    [ProductDescription]    VARCHAR (50)   NULL,
    [ExistingProductID]     INT            NULL,
    [Quantity]              INT            NOT NULL,
    [AddDelete]             VARCHAR (10)   NOT NULL,
    [PackageID]             INT            NULL,
    [MMSTranID]             INT            NULL,
    [TranItemID]            INT            NULL,
    [NotAddedReason]        VARCHAR (1000) NULL,
    [Processed]             INT            NULL,
    [InsertedDateTime]      DATETIME       NULL
);

