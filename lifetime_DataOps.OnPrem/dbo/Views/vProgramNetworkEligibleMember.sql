﻿CREATE VIEW dbo.vProgramNetworkEligibleMember AS 
SELECT ProgramNetworkEligibleMemberID,ProgramNetworkTypeID,MemberID,TranItemID,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ProgramNetworkEligibleMember WITH(NOLOCK)