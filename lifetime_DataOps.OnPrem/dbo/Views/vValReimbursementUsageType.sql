﻿CREATE VIEW dbo.vValReimbursementUsageType AS 
SELECT ValReimbursementUsageTypeID,Description,SortOrder,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ValReimbursementUsageType WITH(NOLOCK)
