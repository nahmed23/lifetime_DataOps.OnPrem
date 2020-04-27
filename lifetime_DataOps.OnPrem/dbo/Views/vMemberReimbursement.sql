

CREATE VIEW dbo.vMemberReimbursement
AS
SELECT     MemberReimbursementID, EnrollmentDate, TerminationDate, ReimbursementProgramID, MemberID, ValReimbursementTerminationReasonID, 
                      InsertedDateTime, UpdatedDateTime, ReimbursementProgramIdentifierFormatID
FROM         MMS.dbo.MemberReimbursement  WITH (NoLock)


