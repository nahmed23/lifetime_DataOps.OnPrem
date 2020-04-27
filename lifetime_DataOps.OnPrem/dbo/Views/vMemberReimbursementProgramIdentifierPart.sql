
CREATE VIEW dbo.vMemberReimbursementProgramIdentifierPart
AS
SELECT     MemberReimbursementProgramIdentifierPartID, MemberReimbursementID, ReimbursementProgramIdentifierFormatPartID, PartValue, 
                      InsertedDateTime, UpdatedDateTime
FROM         MMS.dbo.MemberReimbursementProgramIdentifierPart

