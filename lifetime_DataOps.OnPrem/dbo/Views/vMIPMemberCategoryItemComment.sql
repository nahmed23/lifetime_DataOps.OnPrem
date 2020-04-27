
CREATE VIEW dbo.vMIPMemberCategoryItemComment AS 
SELECT MIPMemberCategoryItemCommentID,MIPMemberCategoryItemID,Comment
FROM MMS.dbo.MIPMemberCategoryItemComment WITH (NoLock)

