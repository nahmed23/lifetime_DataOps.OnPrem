﻿CREATE VIEW dbo.vValRecurrentProductHoldMonth AS 
SELECT ValRecurrentProductHoldMonthID,Description,NumberOFMonths,SortOrder,InsertedDatetime,UpdatedDateTime
FROM MMS.dbo.ValRecurrentProductHoldMonth WITH(NOLOCK)
