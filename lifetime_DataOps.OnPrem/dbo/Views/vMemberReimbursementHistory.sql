

CREATE VIEW dbo.vMemberReimbursementHistory
AS
SELECT     MemberReimbursementHistoryID, MembershipID, MemberID, ReimbursementProgramID, UsageFirstOfMonth, EnrollmentDate, MonthlyDues, 
                      EstimatedReimbursementAmount, ActualReimbursementAmount, ClubID, MMSTranID, ReimbursementErrorCodeID, InsertedDateTime, 
                      UpdatedDateTime, ReimbursementQualifiedFlag, QualifiedClubUtilization
FROM         MMS.dbo.MemberReimbursementHistory  WITH (NoLock)


