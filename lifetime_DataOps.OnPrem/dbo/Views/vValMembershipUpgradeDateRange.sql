﻿CREATE VIEW dbo.vValMembershipUpgradeDateRange AS 
SELECT ValMembershipUpgradeDateRangeID,Description,SortOrder,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ValMembershipUpgradeDateRange WITH(NOLOCK)
