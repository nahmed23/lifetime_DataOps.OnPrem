﻿CREATE VIEW dbo.vProductSalesChannelClub AS 
SELECT ProductSalesChannelClubID,ProductSalesChannelID,ClubID,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ProductSalesChannelClub WITH(NOLOCK)
