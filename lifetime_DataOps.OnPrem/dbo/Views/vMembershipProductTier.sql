﻿CREATE VIEW dbo.vMembershipProductTier AS 
SELECT MembershipProductTierID,MembershipID,ProductTierID,InsertedDateTime,UpdatedDateTime,LastUpdatedEmployeeID
FROM MMS.dbo.MembershipProductTier WITH(NOLOCK)
