﻿CREATE VIEW dbo.vValMembershipAttributeType AS 
SELECT ValMembershipAttributeTypeID,Description,SortOrder,InsertedDateTime,UpdatedDateTime,DisplayUIFlag
FROM MMS.dbo.ValMembershipAttributeType WITH(NOLOCK)
