CREATE VIEW dbo.vPTProductGroup AS 
SELECT PTProductGroupID,ProductID,ValPTProductGroupID,InsertUser,UpdatedUser
FROM Report_MMS.dbo.PTProductGroup WITH(NOLOCK)
