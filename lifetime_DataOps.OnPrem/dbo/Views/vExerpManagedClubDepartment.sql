﻿CREATE VIEW dbo.vExerpManagedClubDepartment AS 
SELECT ExerpManagedClubDepartmentID,ClubID,DepartmentID,EffectiveFromDateTime,EffectiveThruDateTime,InsertedDateTime,UpdatedDateTime
FROM MMS_Archive.dbo.ExerpManagedClubDepartment WITH(NOLOCK)