﻿CREATE VIEW dbo.vMembershipOffering AS 
SELECT MembershipOfferingID,MembershipTypeID,CoupleMembershipTypeID,FamilyMembershipTypeID,Description,InsertedDateTime,UpdatedDateTime,FamilyPlusMembershipTypeID
FROM MMS.dbo.MembershipOffering WITH(NOLOCK)
