
CREATE VIEW vReimbursementProgramParticipationSummary AS
SELECT ReimbursementProgramID, 
       ReimbursementProgramName, 
       AccessMembershipCount, 
       InsertedDate, 
       MonthYear, 
       YearMonth
  FROM ReimbursementProgramParticipationSummary

