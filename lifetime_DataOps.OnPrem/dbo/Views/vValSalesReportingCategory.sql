﻿CREATE VIEW dbo.vValSalesReportingCategory AS 
SELECT ValSalesReportingCategoryID,Description,SortOrder,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ValSalesReportingCategory WITH(NOLOCK)
