﻿CREATE VIEW dbo.vGuestPrivilegeRule AS 
SELECT GuestPrivilegeRuleID,NumberOfGuests,ValPeriodTypeID,LowClubAccessLevel,HighClubAccessLevel,MembershipStartDate,MembershipEndDate
FROM MMS.dbo.GuestPrivilegeRule WITH(NOLOCK)
