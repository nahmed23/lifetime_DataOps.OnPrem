

CREATE VIEW dbo.vMembershipTypeAttribute
AS
SELECT     MembershipTypeAttributeID, MembershipTypeID, ValMembershipTypeAttributeID, InsertedDateTime, UpdatedDateTime
FROM         MMS.dbo.MembershipTypeAttribute  WITH (NoLock)


