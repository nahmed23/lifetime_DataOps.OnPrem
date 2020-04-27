

CREATE VIEW dbo.vPKMemberReimbursementStagingLog
AS
SELECT     PKMemberReimbursementStagingID, PKMemberStagingID, EnrollmentDate, TerminationDate, ReimbursementProgramID, 
                      ReimbursementProgramIdentifierFormatID, ValReimbursementTerminationReasonID
FROM         MMS.dbo.PKMemberReimbursementStagingLog


