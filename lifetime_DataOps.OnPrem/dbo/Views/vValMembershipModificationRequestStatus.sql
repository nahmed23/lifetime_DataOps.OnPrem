﻿CREATE VIEW dbo.vValMembershipModificationRequestStatus AS 
SELECT ValMembershipModificationRequestStatusID,Description,SortOrder,InsertedDatetime,UpdatedDateTime
FROM MMS.dbo.ValMembershipModificationRequestStatus WITH(NOLOCK)
