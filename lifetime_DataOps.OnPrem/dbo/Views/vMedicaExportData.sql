
CREATE VIEW dbo.vMedicaExportData AS 
SELECT MemberReimbursementHistoryID MedicaExportDataID,MembershipID,MemberID,
       ClubID,ReimbursementQualifiedFlag,EstimatedReimbursementAmount ReimbursementAmount,QualifiedClubUtilization TotalClubUsage,
       UsageFirstOfMonth,MMSTranID
FROM MMS.dbo.MemberReimbursementHistory
WHERE ReimbursementProgramID = 2

