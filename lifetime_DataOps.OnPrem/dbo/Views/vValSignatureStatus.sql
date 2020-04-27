CREATE VIEW dbo.vValSignatureStatus AS 
SELECT ValSignatureStatusID,Description,SortOrder
FROM MMS.dbo.ValSignatureStatus WITH(NOLOCK)
