﻿CREATE VIEW dbo.vValActivityAreaSkill AS 
SELECT ValActivityAreaSkillID,Description,SortOrder,ValActivityAreaID,ValActivityAreaSkillCategoryID,ExpirationMonths
FROM MMS.dbo.ValActivityAreaSkill WITH(NOLOCK)
