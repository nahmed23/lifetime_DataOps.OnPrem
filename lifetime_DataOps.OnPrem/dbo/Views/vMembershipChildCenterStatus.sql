﻿

CREATE VIEW dbo.vMembershipChildCenterStatus
AS
SELECT MembershipChildCenterStatusID,MembershipID,DisableChildCenterUsageFlag,EnableChildCenterUsageDate
FROM MMS.dbo.MembershipChildCenterStatus With (NOLOCK)

