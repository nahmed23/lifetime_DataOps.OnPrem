﻿CREATE VIEW dbo.vMemberWithJuniors AS 
SELECT MemberWithJuniorsID,GuardianMemberID,JuniorMembershipID,JuniorMemberID,JuniorFirstName,JuniorLastName,InsertedDateTime,UpdatedDateTime,JuniorAge
FROM MMS.dbo.MemberWithJuniors WITH(NOLOCK)
