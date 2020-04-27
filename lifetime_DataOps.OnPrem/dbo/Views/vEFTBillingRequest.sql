﻿CREATE VIEW dbo.vEFTBillingRequest AS 
SELECT EFTBillingRequestID,FileName,ClubID,PersonID,ProductID,ProductPrice,Quantity,TotalAmount,PaymentRequestReference,CommissionEmployee,TransactionSource,MMSTranID,PackageID,ResponseCode,Message,InsertedDateTime,UpdatedDateTime,ExternalPackageID,OriginalExternalItemID,SubscriptionID,ExternalItemID,ExternalResponseCode
FROM MMS_Archive.dbo.EFTBillingRequest WITH(NOLOCK)
