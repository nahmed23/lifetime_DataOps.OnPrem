﻿CREATE VIEW dbo.vMembershipModificationFlexReason AS 
SELECT MembershipModificationFlexReasonID,MembershipModificationRequestID,ValFlexReasonID,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.MembershipModificationFlexReason WITH(NOLOCK)
