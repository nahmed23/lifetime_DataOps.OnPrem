﻿CREATE VIEW dbo.vMembershipTypeClubPolicy AS 
SELECT MembershipTypeClubPolicyID,MembershipTypeID,ClubID,MoneyBackCancelPolicyDays
FROM MMS.dbo.MembershipTypeClubPolicy WITH(NOLOCK)
