
CREATE PROC [dbo].[procAlteryx_DelinquentMembershipBalanceSummary_Today] 

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @ReportDateTime DATETIME
SET @ReportDateTime = GetDate()

Select MembershipID,CommittedBalance,
       IsNull(CommittedBalanceProducts,0) AS CommittedBalanceProducts
INTO #AllDelinquentAndCreditBalanceMemberships
FROM vMembershipBalance
WHERE (CommittedBalance + IsNull(CommittedBalanceProducts,0)) <> 0


SELECT MembershipID,
       AttributeValue AS MembershipDuesDelinquency,
	   EffectiveFromDateTime,
	   EffectiveThruDateTime
  INTO #MembershipDelinquency
FROM vMembershipAttribute
 Where ValMembershipAttributeTypeID = 6
   AND EffectiveFromDateTime <= @ReportDateTime 
   AND IsNull(EffectiveThruDateTime,'12/21/2100') > @ReportDateTime


SELECT Membership.ClubID AS MMSClubID,
       Count(AllDelinquentMemberships.MembershipID) AS MembershipCount,
       SUM(AllDelinquentMemberships.CommittedBalance) AS DuesCommittedBalance,
	   SUM(AllDelinquentMemberships.CommittedBalanceProducts) AS ProductCommittedBalance,
		CASE WHEN Membership.ValMembershipStatusID = 1
		      THEN 'Terminated'
			  ELSE 'Non-Terminated'
			  END MembershipStatus,
		CASE WHEN AllDelinquentMemberships.CommittedBalance <= 0
		           AND  AllDelinquentMemberships.CommittedBalanceProducts <= 0  
			   THEN 'Credit Balance Outstanding'
			 WHEN AllDelinquentMemberships.CommittedBalance = 0
		           AND  AllDelinquentMemberships.CommittedBalanceProducts > 0  
			   THEN 'Product Balance Only Outstanding'
			 WHEN AllDelinquentMemberships.CommittedBalance > 0
		           AND  AllDelinquentMemberships.CommittedBalanceProducts = 0 
			   THEN 'Dues Balance Only Outstanding' 
			 ELSE 'Dues And Product Balance Outstanding'
			 END DelinquencyMix,
		MembershipDelinquency.MembershipDuesDelinquency,
		@ReportDateTime AS InsertedDateTime
FROM #AllDelinquentAndCreditBalanceMemberships AllDelinquentMemberships
  JOIN vMembership Membership
    ON AllDelinquentMemberships.MembershipID = Membership.MembershipID
  LEFT JOIN #MembershipDelinquency MembershipDelinquency
    ON Membership.MembershipID = MembershipDelinquency.MembershipID
GROUP BY Membership.ClubID,
         CASE WHEN Membership.ValMembershipStatusID = 1
		      THEN 'Terminated'
			  ELSE 'Non-Terminated'
			  END,
		CASE WHEN AllDelinquentMemberships.CommittedBalance <= 0
		           AND  AllDelinquentMemberships.CommittedBalanceProducts <= 0  
			   THEN 'Credit Balance Outstanding'
			 WHEN AllDelinquentMemberships.CommittedBalance = 0
		           AND  AllDelinquentMemberships.CommittedBalanceProducts > 0  
			   THEN 'Product Balance Only Outstanding'
			 WHEN AllDelinquentMemberships.CommittedBalance > 0
		           AND  AllDelinquentMemberships.CommittedBalanceProducts = 0 
			   THEN 'Dues Balance Only Outstanding' 
			 ELSE 'Dues And Product Balance Outstanding'
			 END,
		 MembershipDelinquency.MembershipDuesDelinquency
		 ORDER BY Membership.ClubID,
		          CASE WHEN Membership.ValMembershipStatusID = 1
		      THEN 'Terminated'
			  ELSE 'Non-Terminated'
			  END
	 



DROP TABLE #AllDelinquentAndCreditBalanceMemberships
DROP TABLE #MembershipDelinquency

END
