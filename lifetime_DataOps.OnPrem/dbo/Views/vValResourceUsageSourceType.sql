﻿CREATE VIEW dbo.vValResourceUsageSourceType AS 
SELECT ValResourceUsageSourceTypeID,Description,SortOrder,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ValResourceUsageSourceType WITH(NOLOCK)
