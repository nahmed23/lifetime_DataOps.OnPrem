CREATE VIEW dbo.vValPTProductGroup AS 
SELECT ValPTProductGroupID,Description,SortOrder,ServiceFlag
FROM Report_MMS.dbo.ValPTProductGroup WITH(NOLOCK)
