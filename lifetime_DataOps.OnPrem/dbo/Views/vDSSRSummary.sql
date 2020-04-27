



CREATE VIEW dbo.vDSSRSummary
AS
SELECT     DSSRSummary, MembershipID, PostDateTime, MemberID, TranClubID, TranClubName, ProductDescription, MembershipTypeDescription, 
                      MembershipSizeDescription, PrimaryMemberFirstName, MembershipClubID, MembershipClubName, CreatedDateTime, PrimaryMemberLastName, 
                      AdvisorFirstName, AdvisorLastName, ItemAmount, ProductID, JoinDate, CommissionCount, CommEmployeeFirstName, TranVoidedID, 
                      CommEmployeeLastName, CompanyID, Quantity, ExpirationDate, MMSTranID, TermReasonDescription, CancellationRequestDate, InsertedDateTime,
                      CommEmployeeID, SaleDeptRoleFlag, AdvisorEmployeeID, TranTypeDescription, TranReasonDescription, CorporateAccountRepInitials,
                      CorpAccountRepType, CorporateCode, Post_Today_Flag, Join_Today_Flag, Expire_Today_Flag, Email_OnFile_Flag
FROM         dbo.DSSRSummary WITH (NoLock)

