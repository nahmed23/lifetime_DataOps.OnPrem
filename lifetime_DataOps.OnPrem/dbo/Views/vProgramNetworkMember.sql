﻿CREATE VIEW dbo.vProgramNetworkMember AS 
SELECT ProgramNetworkMemberID,ProgramNetworkID,ProgramNetworkEligibleMemberID,FromDateTime,ThruDateTime,LastUpdatedEmployeeID,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ProgramNetworkMember WITH(NOLOCK)
