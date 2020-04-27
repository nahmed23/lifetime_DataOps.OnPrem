

CREATE VIEW dbo.vPKMemberReimbursementStaging
AS
SELECT     PKMemberReimbursementStagingID, PKMemberStagingID, EnrollmentDate, TerminationDate, ReimbursementProgramID, 
                      ReimbursementProgramIdentifierFormatID, ValReimbursementTerminationReasonID
FROM         MMS.dbo.PKMemberReimbursementStaging


