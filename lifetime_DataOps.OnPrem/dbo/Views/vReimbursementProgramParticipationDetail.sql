
CREATE VIEW vReimbursementProgramParticipationDetail AS
SELECT ReimbursementProgramID, 
       ReimbursementProgramName, 
       MembershipID, 
       MemberCount, 
       AccessMembershipFlag, 
       DuesPrice, 
       SalesTaxPercentage, 
       MembershipExpirationDate, 
       ValTerminationReasonID, 
       ValPreSaleID, 
       ValMembershipStatusID, 
       MembershipProductDescription, 
       InsertedDate, 
       MonthYear, 
       YearMonth
  FROM ReimbursementProgramParticipationDetail

