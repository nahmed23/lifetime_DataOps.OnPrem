﻿CREATE VIEW dbo.vClubMerchantNumber AS 
SELECT ClubMerchantNumberID,ClubID,MerchantNumber,Description,ValBusinessAreaID,InsertedDateTime,UpdatedDateTime,MerchantLocationNumber,AutoReconcileFlag,ValCurrencyCodeID
FROM MMS.dbo.ClubMerchantNumber WITH(NOLOCK)
