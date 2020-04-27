


CREATE VIEW dbo.vContact AS SELECT ContactID,ValContactTypeID,MembershipID,FirstName,LastName,MiddleInt 
FROM MMS.dbo.Contact With (NOLOCK)


