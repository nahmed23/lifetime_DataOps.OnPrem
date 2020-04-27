CREATE VIEW dbo.vValActivityAreaSkillCategory AS 
SELECT ValActivityAreaSkillCategoryID,Description,SortOrder
FROM MMS.dbo.ValActivityAreaSkillCategory WITH(NOLOCK)
