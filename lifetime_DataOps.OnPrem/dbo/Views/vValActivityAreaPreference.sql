CREATE VIEW dbo.vValActivityAreaPreference AS 
SELECT ValActivityAreaPreferenceID,Description,SortOrder,ValActivityAreaID
FROM MMS.dbo.ValActivityAreaPreference WITH(NOLOCK)
