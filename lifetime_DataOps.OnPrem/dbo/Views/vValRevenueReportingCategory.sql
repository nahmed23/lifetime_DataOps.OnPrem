﻿CREATE VIEW dbo.vValRevenueReportingCategory AS 
SELECT ValRevenueReportingCategoryID,Description,SortOrder,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ValRevenueReportingCategory WITH(NOLOCK)
