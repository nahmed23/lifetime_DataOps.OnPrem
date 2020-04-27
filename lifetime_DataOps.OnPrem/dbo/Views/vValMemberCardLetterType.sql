CREATE VIEW dbo.vValMemberCardLetterType AS 
SELECT ValMemberCardLetterTypeID,Description,SortOrder
FROM MMS.dbo.ValMemberCardLetterType WITH(NOLOCK)
