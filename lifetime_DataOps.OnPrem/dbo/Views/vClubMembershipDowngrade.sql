﻿CREATE VIEW dbo.vClubMembershipDowngrade AS 
SELECT ClubMembershipDowngradeID,ClubID,MembershipDowngradeID,FromDateTime,ToDateTime,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ClubMembershipDowngrade WITH(NOLOCK)
