

CREATE VIEW dbo.vValMembershipTypeAttribute
AS
SELECT     ValMembershipTypeAttributeID, Description, SortOrder, InsertedDateTime, UpdatedDateTime
FROM         MMS.dbo.ValMembershipTypeAttribute WITH (NoLock)



