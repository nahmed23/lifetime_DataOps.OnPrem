CREATE VIEW dbo.vMIPMemberCategoryItem AS 
SELECT MIPMemberCategoryItemID,MemberID,MIPCategoryItemID,InsertedDateTime,UpdatedDateTime,ClubID,EmailFlag
FROM MMS.dbo.MIPMemberCategoryItem WITH(NOLOCK)
