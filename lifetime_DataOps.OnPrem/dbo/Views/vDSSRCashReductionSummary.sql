
CREATE VIEW [dbo].[vDSSRCashReductionSummary]
AS
SELECT     DSSRCashReductionSummaryID, ClubID, ClubName, MembershipID,EventDate, EventDescription, Today_Flag, EventTranItemID, 
                      EventItemAmount, MMSTranID, MemberID, TranReasonDescription, JoinDate, CommEmplFirstName, PostDateTime, CommEmplLastName, 
                      ProductDescription, CommissionCount, TranItemID, ItemAmount, PrimaryFirstName, PrimaryLastName, TranType, CommEmployeeID
FROM         dbo.DSSRCashReductionSummary WITH (NOLOCK)
