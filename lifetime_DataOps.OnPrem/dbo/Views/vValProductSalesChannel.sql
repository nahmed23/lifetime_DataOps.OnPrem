﻿CREATE VIEW dbo.vValProductSalesChannel AS 
SELECT ValProductSalesChannelID,Description,SortOrder,InsertedDateTime,UpdatedDateTime,DisplayTerminalAdminUIFlag
FROM MMS.dbo.ValProductSalesChannel WITH(NOLOCK)
