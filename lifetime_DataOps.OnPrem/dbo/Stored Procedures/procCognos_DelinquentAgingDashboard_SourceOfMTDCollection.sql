
CREATE PROC [dbo].[procCognos_DelinquentAgingDashboard_SourceOfMTDCollection] 

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON


-------- Sample Execution
---- exec procCognos_DelinquentAgingDashboard_SourceOfMTDCollection  
--------


DECLARE @DelinquencyStartDate Datetime
DECLARE @DelinquencyFourDigitYearDashTwoDigitMonth Char(7)
DECLARE @QueryDatePlus1 DateTime
DECLARE @QueryDateTime DateTime
SET @QueryDateTime = Cast(GETDATE() AS Date) 
SET @DelinquencyStartDate = (Select DateAdd(Day,1,CalendarMonthStartingDate) from vReportDimDate WHERE CalendarDate = Cast(@QueryDateTime as Date) )
SET @DelinquencyFourDigitYearDashTwoDigitMonth = (SELECT FourDigitYearDashTwoDigitMonth from vReportDimDate WHERE CalendarDate = @DelinquencyStartDate )
SET @QueryDatePlus1  = (Select DateAdd(day,1,CalendarDate) from vReportDimDate WHERE CalendarDate = Cast(@QueryDateTime as Date) )




------  Get list of Memberships with delinquent balances at the beginning of the month

Select BOM.MembershipID,
       MS.ClubID,
       Sum(BOM.AmountDue) AS BalanceDueAtBOM
	INTO #DelinquentMemberships
 FROM DelinquentMembershipBalance_BeginningOfMonth  BOM
   JOIN vMembership MS
     ON BOM.MembershipID = MS.MembershipID
 Where BOM.EffectiveDate <= @QueryDateTime
  AND  BOM.ExpirationDate > @QueryDateTime
  GROUP BY BOM.MembershipID,MS.ClubID




---- To get payment information on payments on account MTD
		Select MT.MembershipID,
		       MS.BalanceDueAtBOM,
			   MS.ClubID AS MembershipHomeClubID, 
		       MT.TranAmount,
			   MT.PostDateTime,
			   CASE WHEN MT.ReasonCodeID = 34 AND MT.EmployeeID > 0 AND E.ClubID = 13
			        THEN 'Corporate Employee'
					WHEN MT.ReasonCodeID = 34 AND MT.EmployeeID > 0 AND E.ClubID <> 13
			        THEN 'Club Employee'
					WHEN MT.ReasonCodeID = 34 AND MT.EmployeeID = -6
					THEN 'Internet'
					WHEN MT.ReasonCodeID in(38,253) AND MT.EmployeeID = -2
					THEN 'Corporate Draft'
					ELSE 'Undefined'
					END CollectionSource
		INTO #PaymentsOnAccount
		From vMMSTran MT
		 JOIN #DelinquentMemberships MS
		   ON MT.MembershipID = MS.MembershipID
		 JOIN vEmployee E
		   ON MT.EmployeeID = E.EmployeeID
		Where MT.PostDateTime >= @DelinquencyStartDate
		  AND MT.PostDateTime < @QueryDatePlus1
		  AND MT.ValTranTypeID = 2     ------ Payment
		  AND MT.ReasonCodeID IN(34,38,253)   ----- Payment On Account, Successfull EFT Draft Dues and Successfull EFT Draft Products
          AND IsNull(MT.TranVoidedID,0)= 0
		  AND MS.BalanceDueAtBOM > 0
		ORDER BY MS.MembershipID,MT.PostDateTime



		SELECT MembershipID,BalanceDueAtBOM,MembershipHomeClubID,TranAmount,CollectionSource,
		  RANK() Over 
		    (Partition By MembershipID Order by PostDateTime ASC) AS PaymentRank

	    INTO #RankedPaymentsOnAccount
		FROM #PaymentsOnAccount
		 


 ---- Build unioned temp table
		 Select MembershipID,
		        MembershipHomeClubID,
		        BalanceDueAtBOM,
		        TranAmount  AS Rank1TranAmount,
				CollectionSource AS Rank1CollectionSource,
				0  AS Rank2TranAmount,
				NULL AS Rank2CollectionSource,
				0  AS Rank3TranAmount,
				NULL AS Rank3CollectionSource,
				0  AS Rank4PlusTranAmount,
				NULL AS Rank4PlusCollectionSource
		INTO #FlattenedData
		 FROM #RankedPaymentsOnAccount
		  WHERE PaymentRank = 1

		  UNION ALL

		 Select MembershipID,
		        MembershipHomeClubID,
				BalanceDueAtBOM,
				0  AS Rank1TranAmount,
				NULL AS Rank1CollectionSource,
				TranAmount  AS Rank2TranAmount,
				CollectionSource AS Rank2CollectionSource,
				0  AS Rank3TranAmount,
				NULL AS Rank3CollectionSource,
				0  AS Rank4PlusTranAmount,
				NULL AS Rank4PlusCollectionSource
		 FROM #RankedPaymentsOnAccount
		  WHERE PaymentRank = 2

		  UNION ALL

		 Select MembershipID,
		        MembershipHomeClubID,
		        BalanceDueAtBOM,
		        0  AS Rank1TranAmount,
				NULL AS Rank1CollectionSource,
				0  AS Rank2TranAmount,
				NULL AS Rank2CollectionSource,
				TranAmount  AS Rank3TranAmount,
				CollectionSource AS Rank3CollectionSource,
				0  AS Rank4PlusTranAmount,
				NULL AS Rank4PlusCollectionSource
		 FROM #RankedPaymentsOnAccount
		  WHERE PaymentRank = 3

		 UNION ALL

		 Select MembershipID,
		        MembershipHomeClubID,
		        BalanceDueAtBOM,
		        0  AS Rank1TranAmount,
				NULL AS Rank1CollectionSource,
				0  AS Rank2TranAmount,
				NULL AS Rank2CollectionSource,
				0  AS Rank3TranAmount,
				NULL AS Rank3CollectionSource,
				SUM(TranAmount)  AS Rank4PlusTranAmount,
				MIN(CollectionSource) AS Rank4PlusCollectionSource
		 FROM #RankedPaymentsOnAccount
		  WHERE PaymentRank >= 3
		  GROUP BY MembershipID,MembershipHomeClubID,BalanceDueAtBOM


	Select MembershipID,
	       MembershipHomeClubID,
	       MAX(BalanceDueAtBOM) AS BalanceDueAtBOM,
	       SUM(Rank1TranAmount) AS Rank1TranAmount,
		   MAX(Rank1CollectionSource) AS Rank1CollectionSource,
		   SUM(Rank2TranAmount) AS Rank2TranAmount,
		   MAX(Rank2CollectionSource) AS Rank2CollectionSource,
		   SUM(Rank3TranAmount) AS Rank3TranAmount,
		   MAX(Rank3CollectionSource) AS Rank3CollectionSource,
		   SUM(Rank4PlusTranAmount) AS Rank4TranAmount,
		   MAX(Rank4PlusCollectionSource) AS Rank4CollectionSource
	  INTO #MembershipCollectionOnAccountBySequenceMTD
	 FROM #FlattenedData
	  GROUP BY MembershipID, MembershipHomeClubID
		  

		  Select MembershipID,MembershipHomeClubID,BalanceDueAtBOM,
		         CASE WHEN (BalanceDueAtBOM + Rank1TranAmount) <= 0
				      THEN BalanceDueAtBOM
					  WHEN (BalanceDueAtBOM + Rank1TranAmount) > 0
					  THEN Rank1TranAmount*-1
					  END DelinquentCollection,
		         Rank1CollectionSource AS CollectionSource,
				 1 AS CollectionSequence
		 INTO #MembershipCollectionsBySequence
		  from #MembershipCollectionOnAccountBySequenceMTD
		  WHERE Rank1TranAmount <> 0

		   UNION All
		  
		  Select MembershipID,MembershipHomeClubID,BalanceDueAtBOM,
		         CASE WHEN (BalanceDueAtBOM + Rank1TranAmount + Rank2TranAmount) <= 0
				      THEN (BalanceDueAtBOM + Rank1TranAmount)
					  WHEN (BalanceDueAtBOM + Rank1TranAmount + Rank2TranAmount) > 0
					  THEN Rank2TranAmount*-1
					  END DelinquentCollection,
		         Rank2CollectionSource AS CollectionSource,
				 2 AS CollectionSequence
		  from #MembershipCollectionOnAccountBySequenceMTD
		  WHERE Rank2TranAmount <> 0
		   AND (BalanceDueAtBOM + Rank1TranAmount)>0

		   	   UNION All
		  
		  Select MembershipID,MembershipHomeClubID,BalanceDueAtBOM,
		         CASE WHEN (BalanceDueAtBOM + Rank1TranAmount + Rank2TranAmount + Rank3TranAmount) <= 0
				      THEN (BalanceDueAtBOM + Rank1TranAmount + Rank2TranAmount)
					  WHEN (BalanceDueAtBOM + Rank1TranAmount + Rank2TranAmount + Rank3TranAmount) > 0
					  THEN Rank3TranAmount*-1
					  END DelinquentCollection,
		         Rank3CollectionSource AS CollectionSource,
				 3 AS CollectionSequence
		  from #MembershipCollectionOnAccountBySequenceMTD
		  WHERE Rank3TranAmount <> 0
		   AND (BalanceDueAtBOM + Rank1TranAmount + Rank2TranAmount)>0

		   		UNION All
		  
		  Select MembershipID,MembershipHomeClubID,BalanceDueAtBOM,
		         CASE WHEN (BalanceDueAtBOM + Rank1TranAmount + Rank2TranAmount + Rank3TranAmount + Rank4TranAmount) <= 0
				      THEN (BalanceDueAtBOM + Rank1TranAmount + Rank2TranAmount + Rank3TranAmount)
					  WHEN (BalanceDueAtBOM + Rank1TranAmount + Rank2TranAmount + Rank3TranAmount + Rank4TranAmount) > 0
					  THEN Rank4TranAmount*-1
					  END DelinquentCollection,
		         Rank4CollectionSource AS CollectionSource,
				 4 AS CollectionSequence
		  from #MembershipCollectionOnAccountBySequenceMTD
		  WHERE Rank4TranAmount <> 0
		   AND (BalanceDueAtBOM + Rank1TranAmount + Rank2TranAmount + Rank3TranAmount)>0



	SELECT MembershipHomeClubID,
	       CollectionSource,
		   SUM(DelinquentCollection) AS DelinquentCollection,
		   @QueryDateTime AS ReportDateTime
		FROM #MembershipCollectionsBySequence
		GROUP By MembershipHomeClubID,
	       CollectionSource

		 DROP TABLE #PaymentsOnAccount
		 DROP TABLE #DelinquentMemberships
		 DROP TABLE #RankedPaymentsOnAccount
		 DROP TABLE #FlattenedData
		 DROP TABLE #MembershipCollectionOnAccountBySequenceMTD
		 DROP TABLE #MembershipCollectionsBySequence

END
