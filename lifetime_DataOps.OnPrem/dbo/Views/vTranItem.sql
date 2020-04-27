﻿CREATE VIEW dbo.vTranItem AS 
SELECT TranItemID,MMSTranID,ProductID,Quantity,ItemSalesTax,ItemAmount,InsertedDateTime,SoldNotServicedFlag,UpdatedDateTime,ItemDiscountAmount,ClubID,BundleProductID,ExternalItemID,ItemLTBucksAmount,TransactionSource,ItemLTBucksSalesTax,ItemLTBucksApplied
FROM MMS_Archive.dbo.TranItem WITH(NOLOCK)